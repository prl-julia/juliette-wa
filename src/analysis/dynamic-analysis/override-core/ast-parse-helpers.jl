# AST, Symbol → Bool
# Determines if the given expression has the given ast head
# and a body of at least 1 subexpression
isAstWithBody(e :: Expr,        head :: Symbol) =
    e.head == head && length(e.args) > 0
isAstWithBody(@nospecialize(e), head :: Symbol) = false

# AST → Bool
# Determines if the given expression is an abreviated function definition
# eg: f() = 1
isAbreviatedFunc(e :: Expr) =
    isAstWithBody(e, :(=)) &&
    (
        isAstWithBody(e.args[1], :call) ||
        # f(...) :: ty = ...
        (isAstWithBody(e.args[1], :(::)) &&
            isAstWithBody(e.args[1].args[1], :call)) ||
        # f(...) where T = ...
        isAstWithBody(e.args[1], :where)
    )

# AST → Bool
# Determines if the given expression is a lambda function
# eg: () -> 1
isLambdaFunc(e) = isAstWithBody(e, :(->))

# AST → Bool
# Determines if the given expression is an assignment of lambda
# eg: f = () -> 1
isLambdaBinding(e :: Expr) =
    isAstWithBody(e, :(=)) &&
    (length(e.args) > 1 && isAstWithBody(e.args[2], :(->)))

# AST → Bool
# Determines if the given expression is an irregularly defined function
isIrregularFunction(e) =
    isAbreviatedFunc(e) || isLambdaBinding(e) || isLambdaFunc(e)

# AST, Module → Module, Symbol
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
        throw(DomainError(e))
    else
        return getFuncNameAndModule(maybeCallExpr, m)
    end
end

# Extracts all expressions from a block, returns the expression if not a block
extractExprs(e) =
    if isAstWithBody(e, :block)
        foldr(
            (expr, exprs) -> vcat(extractExprs(expr), exprs),
            filter(e -> !isa(e, LineNumberNode), e.args);
            init=[]
        )
    else
        [e]
    end
