# Determines if the given expression has the given ast head and a body of at least 1 subexpression
isAstWithBody(e :: Expr, head :: Symbol) = e.head == head && size(e.args)[1] > 0
isAstWithBody(e, head :: Symbol) = false

# Determines if the given expression is an abreviated function definition
# eg: f() = 1
isAbreviatedFunc(e :: Expr) =
    isAstWithBody(e, :(=)) &&
        (isAstWithBody(e.args[1], :call) ||
            (isAstWithBody(e.args[1], :(::)) &&
                isAstWithBody(e.args[1].args[1], :call)))

# Determines if the given expression is an abreviated function definition
# eg: f = () -> 1
isLambdaBinding(e :: Expr) =
    isAstWithBody(e, :(=)) &&
        (size(e.args)[1] > 1 &&
            isAstWithBody(e.args[2], :(->)))

# Determines if the given expression is an lambda function
# eg: () -> 1
isLambdaFunc(e) = isAstWithBody(e, :(->))

# Determines if the given expression is a irregularly defined function
isIrregularFunction(e) = isAbreviatedFunc(e) || isLambdaBinding(e) || isLambdaFunc(e)

# Gets the function name and module of the given function definition
function getFuncNameAndModule(e :: Expr, m :: Module)
    maybeCallExpr = e.args[1]
    if isAstWithBody(maybeCallExpr, :call)
        funcDef = maybeCallExpr.args[1]
        if isa(funcDef, Symbol)
            return (m, funcDef)
        elseif isAstWithBody(funcDef, :(.)) && isa(funcDef.args[2], QuoteNode) &&
                isa(funcDef.args[1], Module)
            return (funcDef.args[1], funcDef.args[2].value)
        elseif isAstWithBody(funcDef, :(.)) && isa(funcDef.args[2], QuoteNode) &&
                isa(funcDef.args[1], Symbol)
            return (eval(funcDef.args[1]), funcDef.args[2].value)
        end
    elseif isa(e, Expr) && (size(e.args)[1] > 0)
        return getFuncNameAndModule(maybeCallExpr, m)
    end
    throw(DomainError(e))
end
