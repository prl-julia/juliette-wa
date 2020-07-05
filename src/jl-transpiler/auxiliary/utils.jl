
##################################
# Structural Equality Definition #
##################################

# for redefining equality
import Base.==

# Checks e1 and e2 for structural equality (using metaprogramming)
# i.e. compares all the fields of e1 and e2
# Assumption: e1 and e2 have the same type
@generated function structEqual(e1, e2)
    # if there are no fields, we can simply return true
    if fieldcount(e1) == 0
        return :(true)
    end
    mkEq    = fldName -> :(e1.$fldName == e2.$fldName)
    # generate individual equality checks
    eqExprs = map(mkEq, fieldnames(e1))
    # construct &&-expression for chaining all checks
    mkAnd  = (expr, acc) -> Expr(:&&, expr, acc)
    # no need in initial accumulator because eqExprs is not empty
    foldr(mkAnd, eqExprs)
end

# Checks e1 and e2 of arbitrary types for structural equality
genericStructEqual(e1, e2) =
    # if types are different, expressions are not equal
    typeof(e1) != typeof(e2) ?
    false :
    # othewise we need to perform a structural check
    structEqual(e1, e2)

# ormap: retruns true is there exits an item in the iterator for which the
# predicate is true. Note the predicate has a signature of T->Bool if the iterator
# contains items of type T
ormap(predicate, iterator) :: Bool =
    foldr((bool, hastrue) -> bool || hastrue, map(predicate, iterator); init=false)
