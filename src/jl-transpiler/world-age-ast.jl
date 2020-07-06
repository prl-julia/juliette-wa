
#################
# World-Age-AST #
#################

# Represents a type in the world-age language
abstract type WAType end
# Represents a number type
struct WANumberType <: WAType end
# Represents a int64 type
struct WAIntType <: WAType end
# Represents a float64 type
struct WAFloatType <: WAType end
# Represents a boolean type
struct WABoolType <: WAType end
# Represents a string type
struct WAStringType <: WAType end
# Represents a bottom type
struct WABottomType <: WAType end
# Represents a nothing type
struct WANothingType <: WAType end
# Represents an any type
struct WAAnyType <: WAType end
# Represents a type for a method
struct MethodType <: WAType
    methodname :: Symbol
end

# Represents the abstract syntax tree of the world age language
abstract type WAAST end
# Represents a number
struct WANumber <: WAAST
    value :: Number
end
# Represents a string
struct WAString <: WAAST
    value :: AbstractString
end
# Represents a boolean
struct WABoolean <: WAAST
    value :: Bool
end
# Represents a variable
struct WAVariable <: WAAST
    name :: Symbol
end
# Represents a unit/skip
struct WANothing <: WAAST end
# Represents a variable that represents a method value
struct WAMethodVal <: WAAST
    value :: Symbol
end
# Represents an expression that is evaluated in the global context
struct WAGlobalEval <: WAAST
    body :: WAAST
end
# Represents an expression that is a evaluated in order first, then second
struct WASequence <: WAAST
    first :: WAAST
    second :: WAAST
end
# Represents a method definition
struct WAMethodDef <: WAAST
    name :: Symbol
    parameters :: Vector{Tuple{Symbol,WAType}}
    body :: WAAST
end
# Represents a method call
struct WACall <: WAAST
    callee :: WAAST
    args   :: Vector{WAAST}
end
# Represents a call to a primop
struct WAPrimopCall <: WAAST
    callee :: Symbol
    args   :: Vector{WAAST}
    WAPrimopCall(callee, args) =
    callee == :(-) && size(args)[1] == 1 ?
        new(MULT_SYM, [WANumber(-1), args[1]]) : new(callee, args)
end
# Represents an if then else statement
struct WAIfThenElse <: WAAST
    conditional :: WAAST
    iftrue :: WAAST
    iffalse :: WAAST
end

#############
# Constants #
#############

# Following are the symbols in the julia ast that discriminate expressions
const BLOCK_SYM = :block
const CALL_SYM = :call
const ASSIGNMENT_SYM = :(=)
const RETURN_SYM = :return
const FUNC_SYM = :function
const NOTHING_SYM = :nothing
const EVAL_SYM = :eval
const IF_SYM = :if
const ELSEIF_SYM = :elseif
const DOT_SYM = :(.)
const BASE_SYM = :Base
const INVOKE_LATEST_SYM = :invokelatest
const ADD_SYM = :(+)
const SUBSTRACT_SYM = :(-)
const MULT_SYM = :(*)
const DIVIDE_SYM = :(/)
const NOT_SYM = :(!)
const AND_SYM = :(&&)
const OR_SYM = :(||)
const EQUAL_SYM = :(==)
const LT_SYM = :(<)
const GT_SYM = :(>)
const LTE_SYM = :(<=)
const GTE_SYM = :(>=)
const QUOTE_SYM = :quote
const PRINT_SYM = :print
const ASSERT_SYM = Symbol("@assert")
const PRIMOPS = [ADD_SYM, SUBSTRACT_SYM, MULT_SYM, DIVIDE_SYM, ASSERT_SYM,
                    PRINT_SYM, NOT_SYM, AND_SYM, OR_SYM, EQUAL_SYM, LT_SYM,
                    GT_SYM, LTE_SYM, GTE_SYM]
const INTERPOLATION_SYM = :$
const MACRO_SYM = :macrocall

# Following are the symbols in the julia ast that discriminate types
const EMPTY_UNION_SYM = :curly
const BOOL_SYM = :Bool
const NUMBER_SYM = :Number
const INT_SYM = :Int64
const FLOAT_SYM = :Float64
const STRING_SYM = :String
const NOTHING_TYPE_SYM = :Nothing
const ANY_SYM = :Any
const SYMBOL_TYPE_MAP = Dict([
            (NUMBER_SYM, WANumberType()), (INT_SYM, WAIntType()),
            (FLOAT_SYM, WAFloatType()), (BOOL_SYM, WABoolType()),
            (STRING_SYM, WAStringType()), (NOTHING_TYPE_SYM, WANothingType()),
            (ANY_SYM, WAAnyType())])

##########
# Errors #
##########

# Represents the set of errors that can occur when translating from julia
# to the redex defined world age language
abstract type WAError <: Exception end

# Represents an unsupported julia expression in translation
struct WAMissingImplementation <: WAError
    message :: AbstractString
end
