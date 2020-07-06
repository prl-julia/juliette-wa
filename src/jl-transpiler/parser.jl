
##########
# Parser #
##########

# parser: Wraps the transpiled julia expression in a global evaluation expression
parser(julia_expr :: Expr) :: WAAST = WAGlobalEval(juliatoWA(julia_expr, Env()))

# juliatoWA: transpiles from the Julia-AST (Expr) to the World-Age-AST (WAAST)
juliatoWA(number  :: Number, env :: Env) :: WAAST = WANumber(number)
juliatoWA(boolean :: Bool,   env :: Env) :: WAAST = WABoolean(boolean)
juliatoWA(string  :: String, env :: Env) :: WAAST =  WAString(string)
juliatoWA(quote_expr :: QuoteNode, env :: Env) :: WAAST = juliatoWA(quote_expr.value, addseparator(env))
juliatoWA(symbol :: Symbol, env :: Env) :: WAAST =
    symbol == NOTHING_SYM ?
        WANothing() :
        transpile_variable_ref(symbol, env)

function juliatoWA(julia_expr :: Expr, env :: Env) :: WAAST
    # mapping from head symbols to parsing functions
    parseMapping = Dict(
        BLOCK_SYM           => transpileblock,
        INTERPOLATION_SYM   => transpile_variable_ref,
        CALL_SYM            => transpilecall,
        FUNC_SYM            => transpile_methoddef,
        ASSIGNMENT_SYM      => transpile_methoddef,
        IF_SYM              => transpile_ifthenelse,
        ELSEIF_SYM          => transpile_ifthenelse,
        MACRO_SYM           => transpile_macro
    )
    if haskey(parseMapping, julia_expr.head)
        parseMapping[julia_expr.head](julia_expr, env)
    elseif julia_expr.head == QUOTE_SYM
        juliatoWA(julia_expr.args[1], addseparator(env))
    elseif julia_expr.head == RETURN_SYM
        # only need to evaluate the body of the return statement
        juliatoWA(julia_expr.args[1], env)
    elseif isa_primop(julia_expr.head)
        juliatoWA(Expr(CALL_SYM, julia_expr.head, julia_expr.args...), env)
    else
        throw(WAMissingImplementation("$(julia_expr)"))
    end
end

##################
# Parser Helpers #
##################

# transpileblock: converts the given expression that is assumed to be a julia
# block into a world age sequence (or nested sequences if more than 2)
function transpileblock(block :: Expr, env :: Env) :: WAAST
    # Remove any line number nodes from the block
    blockexpr = filter((arg) -> typeof(arg) != LineNumberNode, block.args)
    exprcount = size(blockexpr)[1]
    if exprcount == 0
        # Treat a block of length 1 the same as the nothing expression
        return juliatoWA(NOTHING_SYM, env)
    elseif exprcount == 1
        # Treat a block of length 1 the same as the expression by itself
        return juliatoWA(blockexpr[1], env)
    else
        return createsequence_acc(blockexpr, env)
    end
end

# createsequence_acc: converts the given block expression to a nesting of world age
# sequences of all the expressions from the given index to the end of the block.
# Assumption is the block length has >= 2 and there are no LineNumberNode in the block
function createsequence_acc(blockexpr :: Array{Any,1}, env :: Env, index=1 :: Int64) :: WAAST
    transpiled_expr = juliatoWA(blockexpr[index], env)
    if index == size(blockexpr)[1]
        # If it is the final expression in the block, stop recurring
        return transpiled_expr
    else
        # If it is not the final expression create another sequence and recur
        return WASequence(transpiled_expr, createsequence_acc(blockexpr, env, index + 1))
    end
end

# transpile_variable_ref: converts the interpolated or noninterpolcated variable
# into its respective world age representation as a variable or method value
transpile_variable_ref(var :: Union{Expr,Symbol}, env :: Env) :: WAAST =
    transpile_variable_ref(var, env, 0)
transpile_variable_ref(interp_expr :: Expr, env :: Env, interpolation_count :: Int64) :: WAAST =
    transpile_variable_ref(interp_expr.args[1], env, interpolation_count + 1)
function transpile_variable_ref(source_varname :: Symbol, env :: Env, interpolation_count :: Int64) :: WAAST
    target_varname = get_target_varname(env, source_varname, interpolation_count)
    target_varname = target_varname != nothing ? target_varname : source_varname
    WAVariable(target_varname)
end

# transpilecall: converts the julia_expr that is assumed to be a call node to its
# corresponding world-age representation
function transpilecall(call :: Expr, env :: Env) :: WAAST
    callee = call.args[1]
    params = call.args[2:end]
    if callee == EVAL_SYM
        # The call expression is a call to eval(...)
        @assert(size(params)[1] == 1, "eval arity exception")
        return WAGlobalEval(juliatoWA(params[1], env))
    elseif isa_invokelatest(callee)
        # The call expression is a call to Base.invokelatest(...)
        return WAGlobalEval(juliatoWA(Expr(CALL_SYM, params...), env))
    else
        transpiled_callee = juliatoWA(callee, env)
        transpiled_params = map((param) -> juliatoWA(param, env), params)
        # transpile the callee and the arguments to create a WACall or primop
        return isa_primop(callee) ?
            WAPrimopCall(callee, transpiled_params) :
            WACall(transpiled_callee, transpiled_params)
    end
end

# isa_invokelatest: returns true if the given expr is a dot access on the Base
# object to get the invoke latest method, false otherwise
function isa_invokelatest(julia_expr :: Expr) :: Bool
    return julia_expr.head == DOT_SYM && size(julia_expr.args)[1] == 2 &&
    julia_expr.args[1] == BASE_SYM && typeof(julia_expr.args[2]) == QuoteNode &&
    julia_expr.args[2].value == INVOKE_LATEST_SYM
end
isa_invokelatest(julia_expr) :: Bool = false

# transpile_methoddef: converts the julia_expr that is assumed to be a method
# definition into a world age method definition
function transpile_methoddef(julia_expr :: Expr, env :: Env) :: WAAST
    methodname = julia_expr.args[1].args[1]
    parameters = map(julia_expr.args[1].args[2:end]) do param
        source_varname, WAtype = get_paraminfo(param, env)
        # get/create target param name from the source param name and add to variable mapping
        target_varname, env = addlocalvar(env, source_varname)
        return (target_varname, WAtype)
    end
    body = juliatoWA(julia_expr.args[2], env)
    return WAMethodDef(methodname, parameters, body)
end

# transpile_macro: converts the julia_expr that is assumed to be an assert macro
# call into a world age method definition
function transpile_macro(julia_expr :: Expr, env :: Env) :: WAAST
    # Remove any line number nodes from the macro
    macroArgs = filter((arg) -> typeof(arg) != LineNumberNode, julia_expr.args)
    if macroArgs[1] == ASSERT_SYM
        return juliatoWA(Expr(CALL_SYM, ASSERT_SYM, macroArgs[2]), env)
    end
end

# get_paraminfo: gets the name and type of an expression that is assumed to be a parameter
get_paraminfo(param :: Symbol, env :: Env) :: Tuple{Symbol,WAType} =
    (param, WAAnyType())
get_paraminfo(param :: Expr,   env :: Env) :: Tuple{Symbol,WAType} =
    (param.args[1], gettype(param.args[2], env))

# gettype: gets type of an expression that is assumed to be a parameter
function gettype(type :: Symbol, env :: Env) :: WAType
    watype = get(SYMBOL_TYPE_MAP, type, nothing)
    watype != nothing ? watype : throw(WAMissingImplementation("$(type)"))
end
function gettype(type :: Expr, env :: Env) :: WAType
    type.head == EMPTY_UNION_SYM ?
        WABottomType() :
        MethodType(type.args[2])
end

function transpile_ifthenelse(ifthenelse :: Expr, env :: Env) :: WAAST
    conditional = juliatoWA(ifthenelse.args[1], env)
    iftrue = juliatoWA(ifthenelse.args[2], env)
    iffalse = size(ifthenelse.args)[1] == 3 ?
        juliatoWA(ifthenelse.args[3], env) : WANothing()
    return WAIfThenElse(conditional, iftrue, iffalse)
end
