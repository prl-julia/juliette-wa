include("utils.jl")

# juliatojuliette: converts the julia file provided as a command line arg to a
# juliette file
function juliatojuliette()
    show_methodtable = findlast(x -> x == "-m", ARGS) != nothing
    is_opt = findlast(x -> x == "-o", ARGS) != nothing
    filename = ARGS[1]
    prettified_juliette = transpile_and_prettify("$(filename).jl")
    output = JULIETTE_TEMPLATE(prettified_juliette, show_methodtable, is_opt)
    fd = open("$(filename).rkt", "w+")
    write(fd, output)
    close(fd)
end

# JULIETTE_TEMPLATE: creates a juliette file
function JULIETTE_TEMPLATE(prettified_juliette :: String, show_methodtable :: Bool, is_opt :: Bool) :: String
method_name = show_methodtable ? "run" : "run-to-r"
method_name = is_opt ? string(method_name, "-opt") : method_name
"$(REDEX_PROLOG())

(define p
    $(prettified_juliette)
)

(write (term ($(method_name) ,p)))"
end

juliatojuliette()
