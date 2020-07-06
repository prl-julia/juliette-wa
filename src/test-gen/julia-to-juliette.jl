include("utils.jl")

# juliatojuliette: converts the julia file provided as a command line arg to a
# juliette file
function juliatojuliette()
    filename, show_methodtable = ARGS[1] == "-m" ? (ARGS[2], true) : (ARGS[1], false)
    prettified_juliette = transpile_and_prettify("$(filename).jl")
    output = JULIETTE_TEMPLATE(prettified_juliette, show_methodtable)
    fd = open("$(filename).rkt", "w+")
    write(fd, output)
    close(fd)
end

# JULIETTE_TEMPLATE: creates a juliette file
function JULIETTE_TEMPLATE(prettified_juliette :: String, show_methodtable :: Bool) :: String
"$(REDEX_PROLOG)

(define p
    $(prettified_juliette)
)

(write (term ($(show_methodtable ? "run" : "run-to-r") ,p)))"
end

juliatojuliette()
