#**********************************************************************
# Prasing-based static analysis of eval/invokelatest
#**********************************************************************
# 
# TODO
# 
#**********************************************************************

using ImmutableList

const EVAL_ARG_DESCRIPTIONS = [
        :value, :symbol, :block, :curly,
        :export, :using,
        :const, :(=),
        :function, :call,
        :nothing, :other, :error
    ]

struct EvalCallInfo
    astHead :: Symbol
end

EvalCallsSummary = List{EvalCallInfo}

const SYM_EVAL   = :eval
const SYM_EVALM  = Symbol("@eval")
const SYM_CORE   = :Core
const SYM_DOT    = :.
const QUOTE_EVAL = :(:eval)
const SYM_CALL   = :call
const SYM_CALLM  = :macrocall

# eval
isEvalName(e :: Symbol) = e == SYM_EVAL
# Core.eval
isEvalName(e :: Expr) =
    e.head == SYM_DOT && e.args[1] == SYM_CORE && e.args[2] == QUOTE_EVAL
# everything else is not
isEvalName(@nospecialize e) = false

# @eval
isEvalMacroName(e :: Symbol) = e == SYM_EVALM
# everything else is not
isEvalMacroName(@nospecialize e) = false

isEvalCall(e :: Expr) =
    # eval/Core.eval
    e.head == SYM_CALL && isEvalName(e.args[1]) ||
    # @eval
    e.head == SYM_CALLM && isEvalMacroName(e.args[1])

# Note. It does not go into quote, e.g. inner eval in
#       eval(:(eval(...))) is ignored
countEval(e :: Expr) :: UInt =
    isEvalCall(e) ?
        1 : #(@show e ; 1) :
        sum(map(countEval, e.args))
countEval(e) :: UInt = 0

isCall(e :: Expr) = e.head == :call
isCall(e :: Any)  = false

# Maps [arg] (argument of eval) to a symbol describing its kind
# (one of EVAL_ARG_DESCRIPTIONS)
argDescrUnsafe(arg :: Nothing) = :nothing
argDescrUnsafe(arg :: QuoteNode) = evalArgDescription(arg.value)
argDescrUnsafe(arg :: Symbol) = :symbol
argDescrUnsafe(arg :: Expr) =
    if arg.head == :quote
        argDescrUnsafe(arg.args[1])
    # it's either function or assignment
    elseif arg.head == :(=)
        isCall(arg.args[1]) ? :function : :(=)
    elseif in(arg.head, EVAL_ARG_DESCRIPTIONS)
        arg.head
    else
        :other
    end
# if it's something like Int, consider it a value
argDescrUnsafe(arg :: Any) = :value

argDescr(arg :: Any) = try argDescrUnsafe(arg) catch ; :error end

# Collects information about eval call [e]
# assuming [e] IS an eval call
getEvalInfo(e :: Expr) :: EvalCallInfo = 
    EvalCallInfo(length(e.args) > 1 ? argDescr(e.args[end]) : :nothing)

#=
gatherEvalInfo(e :: Expr) :: EvalCallsSummary =
    isEvalCall(e) ?
        1 : #(@show e ; 1) :
        sum(map(countEval, e.args))
=#