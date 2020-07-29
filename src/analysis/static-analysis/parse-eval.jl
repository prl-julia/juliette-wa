#**********************************************************************
# Prasing-based static analysis of eval/invokelatest
#**********************************************************************
# 
# TODO
# 
#**********************************************************************

using Test

struct EvalCallInfo
    isEval :: Bool
    expr   :: Any
end

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
