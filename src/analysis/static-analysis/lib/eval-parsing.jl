#**********************************************************************
# Utilities for parsing eval and counting its arguments
#**********************************************************************

import Base.==
import Base.show

###################################################
# Data
###################################################

#--------------------------------------------------
# Constants
#--------------------------------------------------

# Useful symbols for parsing
const SYM_EVAL    = :eval
const SYM_EVALM   = Symbol("@eval")
const QUOTE_EVAL  = :(:eval)
const QUOTE_PARSE = :(:parse)

const SYM_OPTLE   = Symbol("@optlevel")
const QUOTE_OPTLE = QuoteNode(Symbol("@optlevel"))
const SYM_FORML   = Symbol("@formula")
const QUOTE_FORML = QuoteNode(Symbol("@formula"))

const SYM_SPRINT  = Symbol("@sprintf")
const QUOTE_SPRINT= QuoteNode(Symbol("@sprintf"))
const SYM_PRINT   = Symbol("@printf")
const QUOTE_PRINT = QuoteNode(Symbol("@printf"))

# identifies that the macro is not relevant for world age
const SYM_NFUNC_M = Symbol("@!WAmacro") 
const SYM_S_PRINT = Symbol("@(s)printf")

const SYM_FUNC    = :function
const QUOTE_FUNC  = QuoteNode(:function)
const SYM_LAM     = :(->)
const SYM_DOT     = :.
const SYM_PIPE    = :(|>)
const SYM_CALL    = :call
const SYM_MCALL   = :macrocall
const QUOTE_ASGN  = QuoteNode(:(=))
const QUOTE_CONST = QuoteNode(:const)
const QUOTE_GLOB  = QuoteNode(:global)
const QUOTE_LOC   = QuoteNode(:local)
const QUOTE_MOD   = QuoteNode(:module)
const QUOTE_USING = QuoteNode(:using)
const QUOTE_IMP   = QuoteNode(:import)
const QUOTE_EXP   = QuoteNode(:export)
const QUOTE_TOPL  = QuoteNode(:toplevel)

const VAR_REF_SYMBOLS = map(Symbol, [
    ".", "ref"
])

# Common macros
const COMMON_MACROS = [Symbol("@doc"), Symbol("@deprecate")]

# Macros known to define functions
const FUN_DEF_MACROS = map(Symbol, [
    "@delegate", "@delegate_return_parent",
    "@define_unary", "@define_binary",
    "@define_broadcast", "@define_broadcast_unary",
    "@define_binary_dual_op", "@op",
    "@register", "@inline", "@noinline",
    "@pydef"
])
# Macros known to do import
const IMPORT_MACROS = map(Symbol, [
    "@tryimport"
])

# Quotes that are often used with Expr
const EXPR_QUOTES = [
    QUOTE_FUNC, QUOTE_ASGN, QUOTE_GLOB, QUOTE_LOC, QUOTE_CONST, 
    QUOTE_MOD, QUOTE_TOPL, QUOTE_USING, QUOTE_IMP, QUOTE_EXP,
]

# Symbol representation of AST heads that we count
# Note. [:other] includes, e.g., [&&] operator used in [Genie] package.
#       [:ref] is index access
const EVAL_ARG_DESCRIPTIONS = [
        :value, :block, :curly, :let, :if, :for,
        :struct, :module,
        :export, :import, :using,
        :const, :(=), :local,
        SYM_FUNC, :macro, SYM_CALL, SYM_MCALL, SYM_LAM, SYM_PIPE,
        :($),
        :nothing, :other, :error
    ]

#--------------------------------------------------
# Data Types
#--------------------------------------------------

# Eval argument statistics
#------------------------------

# Information about eval argument
struct EvalCallInfo
    astHead  :: Symbol
    inFunDef :: Bool
end
EvalCallInfo(astHead :: Symbol) = EvalCallInfo(astHead, false)
#EvalCallInfo = Symbol

# List of eval infos
EvalCallsVec = Vector{EvalCallInfo}

==(evalInfo1 :: EvalCallInfo, evalInfo2 :: EvalCallInfo) =
    evalInfo1.astHead  == evalInfo2.astHead &&
    evalInfo1.inFunDef == evalInfo2.inFunDef

Base.show(io :: IO, evalInfo :: EvalCallInfo) = print(io,
    "$(evalInfo.astHead) $(showEvalLevel(evalInfo.inFunDef))")

showEvalLevel(inFunDef :: Bool) = "[" * (inFunDef ? "fun" : "top") * "]"

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
isEvalName(e :: Symbol) = e == SYM_EVAL # eval
isEvalName(e :: Expr)   =               # Core.eval
    e.head == SYM_DOT && e.args[1] == :Core && e.args[2] == QUOTE_EVAL
isEvalName(@nospecialize e) = false     # everything else is not eval

# AST → Bool
# Checks if [e] represents standard name of [@eval]
isEvalMacroName(e :: Symbol)     = e == SYM_EVALM   # @eval
isEvalMacroName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents standard name of [Meta.parse]
isParseName(e :: Expr) =                # Meta.parse
    e.head == SYM_DOT && e.args[1] == :Meta && e.args[2] == QUOTE_PARSE
isParseName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents standard name of [include]
isIncludeName(e :: Symbol)     = e == :include
isIncludeName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents standard name of [@optlevel]
isOptLevelMacroName(e :: Symbol) = e == SYM_OPTLE
isOptLevelMacroName(e :: Expr)   =
    e.head == SYM_DOT && in(QUOTE_OPTLE, e.args)
isOptLevelMacroName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents standard name of [@formula]
isFormulaMacroName(e :: Symbol) = e == SYM_FORML
isFormulaMacroName(e :: Expr)   =
    e.head == SYM_DOT && in(QUOTE_FORML, e.args)
isFormulaMacroName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents standard name of [@(s)printf]
isPrintfMacroName(e :: Symbol) = e == SYM_PRINT || e == SYM_SPRINT
isPrintfMacroName(e :: Expr)   =
    e.head == SYM_DOT && (in(QUOTE_PRINT, e.args) || in(QUOTE_SPRINT, e.args))
isPrintfMacroName(@nospecialize e) = false

# AST, Symbol -> Bool
# Checks if [e] has head [head]
hasASTHead(e :: Expr, head :: Symbol)        = e.head == head
hasASTHead(@nospecialize(e), head :: Symbol) = false

# AST → Bool
# Checks if [e] represents a where-expression
isWhere(e) = hasASTHead(e, :where)

# AST → Bool
# Checks if [e] represents a block
isBlock(e) = hasASTHead(e, :block)

# AST → Bool
# Checks if [e] represents a call
isCall(e) = hasASTHead(e, SYM_CALL)

# AST → Bool
# Checks if [e] represents a function definition
isFunDef(e :: Expr) =
    # explicit function definition
    e.head == SYM_FUNC || e.head == SYM_LAM ||
    # short form f(...) = ...
    e.head == :(=) && (isCall(e.args[1]) || isWhere(e.args[1]) || 
        hasASTHead(e.args[1], :(::)))
isFunDef(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents an assignment of lambda
isLambdaAsgn(e :: Expr) =
    e.head == :(=) && length(e.args) > 1 && hasASTHead(e.args[2], SYM_LAM)
isLambdaAsgn(@nospecialize e) = false

# AST → Bool
# Checks if [e] looks like eval def with parameters rather than a call to eval.
# Real eval should at least have no more than 2 arguments
#   (plus eval name, which gives us 3)
# and not contain [::] (this would mean function definition)
maybeEvalDef(e :: Expr) = e.head == SYM_CALL && (length(e.args) > 3 ||
    any(a -> isa(a, Expr) && a.head == :(::), e.args))
maybeEvalDef(@nospecialize e) = false

# AST → Bool
# Checks if call [e] looks like a call to eval
callHasEvalName(e :: Expr) = begin
    args = filter(e -> !isa(e, LineNumberNode), e.args)
    length(args) > 0 &&
        (e.head == SYM_CALL  && isEvalName(args[1]) ||      # eval/Core.eval
         e.head == SYM_MCALL && isEvalMacroName(args[1]))   # @eval
end
callHasEvalName(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a call to eval (either normal or macro)
isEvalCall(e :: Expr) = callHasEvalName(e) && !maybeEvalDef(e)
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

# AST, Bool → EvalCallsVec
# Assuming that [arg] is a macrocall, classifies [arg]'s AST kind
classifyMacroCall(arg :: Expr, inFunDef::Bool) = begin
    args = filter(e -> !isa(e, LineNumberNode), arg.args)
    #@info args[1]
    # multiple macros are known to define functions
    if in(args[1], FUN_DEF_MACROS)
        [EvalCallInfo(SYM_FUNC, inFunDef)]
    elseif in(args[1], IMPORT_MACROS)
        [EvalCallInfo(:import, inFunDef)]
    # @...optlevel
    elseif any(isOptLevelMacroName, args)
        [EvalCallInfo(SYM_NFUNC_M, inFunDef)] #[EvalCallInfo(SYM_OPTLE, inFunDef)]
    # @...formula
    elseif any(isFormulaMacroName, args)
        [EvalCallInfo(SYM_NFUNC_M, inFunDef)] #[EvalCallInfo(SYM_FORML, inFunDef)]
    # @printf, @sprintf, @Printf.sprintf, @Printf.printf
    elseif any(isPrintfMacroName, args)
        [EvalCallInfo(SYM_S_PRINT, inFunDef)]
    # keep track of some common macros
    elseif in(args[1], COMMON_MACROS)
        [EvalCallInfo(args[1], inFunDef)]
    # some macros are often used with a function definition or a block
    # if it's a function, most likely the macro simply does some additional
    # things to the definition;
    # if it's block, macro often applies to the inner elements
    elseif length(args) == 2
        isFunDef(args[2]) ?
            [EvalCallInfo(SYM_FUNC, inFunDef)] :
            isBlock(args[2]) ?
                argDescrUnsafe(args[2], inFunDef) :
                [EvalCallInfo(SYM_MCALL, inFunDef)]
    # there can be additional parameters to a function-defining macro,
    # but if there is a function definition among arguments, the macro
    # often does introduce the function
    elseif count(isFunDef, args) > 0
        [EvalCallInfo(SYM_FUNC, inFunDef)]
    else
        #@warn arg
        [EvalCallInfo(SYM_MCALL, inFunDef)]
    end
end

# AST, Bool → EvalCallsVec
# Assuming that [arg] is a function call, classifies [arg]'s AST kind
classifyFunctonCall(arg :: Expr, inFunDef::Bool) = begin
    # eval(:(include(...)))
    if isIncludeCall(arg)
        [EvalCallInfo(:include, inFunDef)]
    # eval(Meta.parse(...))
    elseif isParseCall(arg)
        [EvalCallInfo(:parse, inFunDef)]
    # eval( ... |> Meta.parse)
    elseif in(SYM_PIPE, arg.args)
        [EvalCallInfo(any(isParseName, arg.args) ? :parse : SYM_PIPE, inFunDef)]
    # eval(Symbol(...)) usually means a reference to a variable/function
    elseif in(:Symbol, arg.args)
        [EvalCallInfo(:variable, inFunDef)]
    # eval(Expr(...)) is also a way to build an expression; it might be easy
    # to classify based on the first argument, but often requires manual check
    elseif in(:Expr, arg.args)
        arg.args[1] == :Expr ?
            in(arg.args[2], EXPR_QUOTES) ?
                [EvalCallInfo(arg.args[2].value, inFunDef)] :
                [EvalCallInfo(:expr, inFunDef)] :
            [EvalCallInfo(:expr, inFunDef)]
    else
        [EvalCallInfo(SYM_CALL, inFunDef)]
    end
end

# AST, Bool → EvalCallsVec
# Maps [arg] (argument of eval) to the description of its AST kind
# (one of EVAL_ARG_DESCRIPTIONS).
# Usually the result will be just one symbol, but if it's a block,
# we want to count all subcompponents.
# Argument [inFunDef] distinguishes top-level from in-function calls.
argDescrUnsafe(arg :: QuoteNode, inFunDef::Bool) =
    argDescrUnsafe(arg.value, inFunDef)
# symbols are classified as variables references
argDescrUnsafe(arg :: Symbol,    inFunDef::Bool) =
    [EvalCallInfo(:variable, inFunDef)]
argDescrUnsafe(arg :: Expr,      inFunDef::Bool) =
    if arg.head == :quote
        argDescrUnsafe(arg.args[1], inFunDef)
    # let's count anonymous functions separately
    elseif (arg.head == SYM_LAM) || isLambdaAsgn(arg)
        [EvalCallInfo(SYM_LAM, inFunDef)]
    # captures the case where [=] means function definition
    elseif isFunDef(arg)
        [EvalCallInfo(SYM_FUNC, inFunDef)]
    # index access and dot-notation mean reference to a "variable"
    elseif in(arg.head, VAR_REF_SYMBOLS)
        [EvalCallInfo(:variable, inFunDef)]
    # sometimes function definition is annotated with a macro,
    # and there are macros (e.g. @delegate) that define functions
    elseif arg.head == SYM_MCALL
        classifyMacroCall(arg, inFunDef)
    # sometimes block has just one thing in it,
    # otherwise, process every element inside
    elseif arg.head == :block
        args = filter(e -> !isa(e, LineNumberNode), arg.args)
        len = length(args)
        len == 0 ? # we don't see any such case in the data, but just in case
            [EvalCallInfo(:nothing, inFunDef)] : 
            len == 1 ? 
                argDescrUnsafe(args[1], inFunDef) : 
                foldl(vcat, map(e -> argDescrUnsafe(e, inFunDef), args))
    # eval of a function call might be interesting, e.g. call to parse/include
    elseif arg.head == SYM_CALL
        classifyFunctonCall(arg, inFunDef)
    # using, import are similar
    elseif in(arg.head, [:using, :import])
        [EvalCallInfo(:useimport, inFunDef)]
    elseif in(arg.head, EVAL_ARG_DESCRIPTIONS)
        [EvalCallInfo(arg.head, inFunDef)]
    else
        [EvalCallInfo(:other, inFunDef)]
    end
argDescrUnsafe(arg :: Nothing,     inFunDef::Bool) =
    [EvalCallInfo(:nothing, inFunDef)]
# if it's something like Int, consider it a value
argDescrUnsafe(@nospecialize(arg), inFunDef::Bool) = 
    [EvalCallInfo(:value, inFunDef)]

# AST → EvalCallsVec
# Maps [arg] (argument of eval) to symbol(s) describing its kind
# (one of EVAL_ARG_DESCRIPTIONS).
argDescr(arg :: Any, inFunDef::Bool=false) :: EvalCallsVec =
    try 
        argDescrUnsafe(arg, inFunDef) 
    catch e
        @error e
        [EvalCallInfo(:error, inFunDef)]
    end
