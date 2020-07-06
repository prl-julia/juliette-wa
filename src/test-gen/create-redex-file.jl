include("utils.jl")

const JULIA_ERR_MAP = Dict{Symbol,String}(
        [(:MethodError, "err-no-method"), (:UndefVarError, "var-err"),
        (:TypeError, "type-err"),(:AssertionError, "assert-err")]
    )

# create_redex_file: creates a redex file that tests in the julia expression
# run as a juilette program
function create_redex_file(dirpath :: String)
    prettified_juliette_expr = transpile_and_prettify("$(dirpath)/source.jl")
    fd = open("$(dirpath)/expected.jl")
    juliatest = read(fd, String)
    close(fd)
    expected_value = get_expectedvalue(juliatest)
    fd = open("$(dirpath)/redex.rkt", "w+")
    write(fd, REDEX_FILE_TEMPLATE(dirpath, prettified_juliette_expr, expected_value))
    close(fd)
end

# get_expectedvalue: parses the given test expression for the expected output
# of the source program and converts the output to a juiliette value
function get_expectedvalue(juliatest :: String) :: String
    juliatest_ast = Meta.parse(juliatest[findlast("@testset",juliatest)[1]:end])
    testexpr = juliatest_ast.args[4].args[2]
    if testexpr.args[1] == Meta.parse("@test").args[1]
        julia_expectedval = testexpr.args[3].args[2]
        julia_actualval = testexpr.args[3].args[3]
        return juliaval_to_julietteval(julia_expectedval, julia_actualval)
    else
        juliaerr = testexpr.args[3]
        julietteerr = get(JULIA_ERR_MAP, juliaerr, nothing)
        return julietteerr != nothing ? julietteerr : throw(InvalidStateException("Unsppported err$(juliaerr)", :err));
    end
end

# juliaval_to_julietteval: returns the juliette value in string form corresponding
# to the given julia value
juliaval_to_julietteval(julia_expectedval, julia_actualval) = string(julia_expectedval)
juliaval_to_julietteval(julia_expectedval :: String, julia_actualval) = "\"$(julia_expectedval)\""
juliaval_to_julietteval(julia_expectedval :: String, julia_actualval :: Expr) =
    julia_actualval.head == :call && isa_methodval(julia_actualval.args[1]) ?
        "(mval \"$(julia_expectedval)\")" :
        "\"$(julia_expectedval)\""

# isa_methodval: returns true id the given identifier matches the method val identifier
isa_methodval(identifier) = false
isa_methodval(identifier :: Symbol) = identifier == :get_methodvalue


# REDEX_FILE_TEMPLATE: creates a redex test file
function REDEX_FILE_TEMPLATE(testname :: String, juliette_expr :: String, expected_value :: String)
"$(REDEX_PROLOG)

(displayln \"Test for $(testname):\")

(define p
    $(juliette_expr))

(test-equal (term (run-to-r ,p)) (term $(expected_value)))

(test-results)"
end
