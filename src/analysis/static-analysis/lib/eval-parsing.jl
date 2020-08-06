#**********************************************************************
# Utilities for parsing eval and counting its arguments
#**********************************************************************

###################################################
# Data
###################################################

#--------------------------------------------------
# Constants
#--------------------------------------------------

# Useful symbols for parsing
const SYM_EVAL    = :eval
const SYM_EVALM   = Symbol("@eval")
const SYM_OPTLE   = Symbol("@optlevel")
const SYM_DEPREC  = Symbol("@deprecate")
const SYM_DOC     = Symbol("@doc")
const SYM_SPRINT  = Symbol("@sprintf")
const SYM_PRINT   = Symbol("@printf")
const SYM_DOT     = :.
const SYM_PIPE    = :(|>)
const QUOTE_EVAL  = :(:eval)
const QUOTE_PARSE = :(:parse)
const QUOTE_OPTLE = QuoteNode(Symbol("@optlevel"))
const SYM_CALL    = :call
const SYM_MCALL   = :macrocall

const FUN_DEF_MACROS = map(Symbol, 
    ["@delegate", "@delegate_return_parent",
    "@define_unary", "@define_binary",
    "@define_broadcast", "@define_broadcast_unary",
    "@define_binary_dual_op", "@op",
    "@register"])

# Symbol representation of AST heads that we count
# Note. [:other] includes, e.g., [&&] operator used in [Genie] package
# [:ref] is index access
const EVAL_ARG_DESCRIPTIONS = [
        :value, :symbol, :block, :curly, :let, :., :ref, :if,
        :struct, :module,
        :export, :import, :using,
        :const, :(=), :local,
        :function, :macro, :call, :macrocall, :(->), SYM_PIPE,
        :($), Symbol("@doc"),
        :nothing, :other, :error
    ]

#--------------------------------------------------
# Data Types
#--------------------------------------------------

# Eval argument statistics
#------------------------------

# Information about eval argument
#struct EvalCallInfo
#    astHead :: Symbol
#end
EvalCallInfo = Symbol

# List of eval infos
EvalCallsVec = Vector{EvalCallInfo}

###################################################
# Algorithms
###################################################

#--------------------------------------------------
# Eval Arguments Statistics
#--------------------------------------------------

# Parsing helpers
#------------------------------

# AST → Bool
# Checks if [e] represents standard name of [eval]
isEvalName(e :: Symbol)     = e == SYM_EVAL # eval
isEvalName(e :: Expr)       =               # Core.eval
    e.head == SYM_DOT && e.args[1] == :Core && e.args[2] == QUOTE_EVAL
isEvalName(@nospecialize e) = false         # everything else is not

# AST → Bool
# Checks if [e] represents standard name of [@eval]
isEvalMacroName(e :: Symbol)     = e == SYM_EVALM   # @eval
isEvalMacroName(@nospecialize e) = false            # everything else is not

# AST → Bool
# Checks if [e] represents standard name of [Meta.parse]
isParseName(e :: Expr)       =           # Meta.parse
    e.head == SYM_DOT && e.args[1] == :Meta && e.args[2] == QUOTE_PARSE
isParseName(@nospecialize e) = false     # everything else is not

# AST → Bool
# Checks if [e] represents standard name of [include]
isIncludeName(e :: Symbol)     = e == :include
isIncludeName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents standard name of [@optlevel]
isOptLevelMacroName(e :: Symbol)     = e == SYM_OPTLE
isOptLevelMacroName(e :: Expr)       =
    e.head == SYM_DOT && in(QUOTE_OPTLE, e.args)
isOptLevelMacroName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a where-expression
isWhere(e :: Expr)       = e.head == :where
isWhere(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a function definition
isFunDef(e :: Expr) = e.head == :function || e.head == :(->) ||
    e.head == :(=) && isCall(e.args[1]) || isWhere(e.args[1])
isFunDef(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a block
isBlock(e :: Expr)       = e.head == :block
isBlock(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a call
isCall(e :: Expr)       = e.head == :call
isCall(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a call to eval (either normal or macro)
isEvalCall(e :: Expr) =
    # eval/Core.eval
    e.head == SYM_CALL && isEvalName(e.args[1]) ||
    # @eval
    e.head == SYM_MCALL && isEvalMacroName(e.args[1])
isEvalCall(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a call to Meta.parse
isParseCall(e :: Expr)       = e.head == SYM_CALL && isParseName(e.args[1])
isParseCall(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a call to include
isIncludeCall(e :: Expr)       = e.head == SYM_CALL && isIncludeName(e.args[1])
isIncludeCall(@nospecialize e) = false

# Parsing eval
#------------------------------

# AST → EvalCallsVec
# Maps [arg] (argument of eval) to symbol(s) describing its kind
# (one of EVAL_ARG_DESCRIPTIONS).
# Usually the result will be just one symbol, but if it's a block,
# we want to count all subcompponents.
argDescrUnsafe(arg :: Nothing) = [:nothing]
argDescrUnsafe(arg :: QuoteNode) = argDescrUnsafe(arg.value)
argDescrUnsafe(arg :: Symbol) = [:symbol]
argDescrUnsafe(arg :: Expr) =
    if arg.head == :quote
        argDescrUnsafe(arg.args[1])
    # let's count anonymous functions
    elseif arg.head == :(->)
    #    [:function]
        [:(->)]
    # captures the case where [=] means function definition
    elseif isFunDef(arg)
        [:function]
    # sometimes function definition is annotated with a macro,
    # or macro @delegate actually defines a function
    elseif arg.head == :macrocall
        args = filter(e -> !isa(e, LineNumberNode), arg.args)
        #@info args[1]
        if in(args[1], FUN_DEF_MACROS)
            [:function]
        elseif any(isOptLevelMacroName, args)
            [SYM_OPTLE]
        elseif in(args[1], [SYM_DOC, SYM_DEPREC, SYM_PRINT, SYM_SPRINT])
            [args[1]]
        elseif length(args) == 2
            isFunDef(args[2]) ? 
                [:function] :
                isBlock(args[2]) ? argDescrUnsafe(args[2]) : [:macrocall]
        elseif count(isFunDef, args) > 0
            [:function]
        else
            #@warn arg
            [:macrocall]
        end
    # sometimes block has just one thing in it,
    # otherwise, process every element inside
    elseif arg.head == :block
        args = filter(e -> !isa(e, LineNumberNode), arg.args)
        len = length(args)
        len == 0 ? [:nothing] : len == 1 ? argDescrUnsafe(args[1]) : 
            foldl(vcat, map(argDescrUnsafe, args))
    # eval(:(inlcude(...)))
    elseif isIncludeCall(arg)
        [:include]
    # eval(Meta.parse(...)) we want to treat specially
    elseif isParseCall(arg)
        [:parse]
    # as well as eval(.. |> Meta.parse)
    elseif arg.head == SYM_CALL
        #@info arg in(SYM_PIPE, arg.args) any(isParseName, arg.args)
        if in(SYM_PIPE, arg.args)
            any(isParseName, arg.args) ? [:parse] : [SYM_PIPE]
        elseif in(:Symbol, arg.args)
            [:symbol]
        elseif in(:Expr, arg.args)
            [:expr]
        else
            [SYM_CALL]
        end
    elseif in(arg.head, EVAL_ARG_DESCRIPTIONS)
        [arg.head]
    else
        [:other]
    end
# if it's something like Int, consider it a value
argDescrUnsafe(@nospecialize arg) = [:value]

# AST → EvalCallsVec
# Maps [arg] (argument of eval) to symbol(s) describing its kind
# (one of EVAL_ARG_DESCRIPTIONS).
argDescr(arg :: Any) :: EvalCallsVec =
    try 
        argDescrUnsafe(arg) 
    catch e
        @error e
        [:error]
    end
