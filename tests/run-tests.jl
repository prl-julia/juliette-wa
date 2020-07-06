include("../src/test-gen/create-redex-file.jl")

const LITMUS_WA_DIR = "litmus-wa"

# runtest: all the tests indicated by the command line args are executed
function runtest()
    if size(ARGS)[1] == 0
        tests = readdir("$(LITMUS_WA_DIR)")
    elseif ARGS[1] == "-run" || ARGS[1] == "-r"
        tests = ARGS[2:end]
    elseif ARGS[1] == "-ignore" || ARGS[1] == "-i"
        tests = filter(
                (test) -> findlast(isequal(test), ARGS[2:end]) == nothing,
                readdir("test-files")
            )
    else
        println("Invalid format")
        exit(1)
    end
    map(execute, tests)
end

# execute: for the given test, its julia source code is checked that it interprets
# to the expected output, a juliette program corresponding to the source program
# is created, and this juliette program is also tested on the expected output
function execute(test :: String)
    testdir = "$(LITMUS_WA_DIR)/$(test)"
    println("####### RUNNING TEST $(test) #######")
    println("Testing julia code...")
    cd(testdir)
    output = read(pipeline(`julia expected.jl`), String)
    println("Creating juliette code...")
    cd("../../")
    create_redex_file(testdir)
    println("Redex file created")
    println("Testing juliette code...")
    cd(testdir)
    output = read(pipeline(`racket redex.rkt`), String)
    cd("../../")
end

runtest()
