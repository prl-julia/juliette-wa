include("../src/test-gen/create-redex-file.jl")

const LITMUS_WA_DIR = "litmus-wa"
const LITMUS_OPT_DIR = "litmus-optimizations"
const OPTIMIZATION_ID = "optimizations"

# runtest: all the tests indicated by the command line args are executed
function runtest()
    if size(ARGS)[1] == 0
        tests = vcat(gettests(false), gettests(true))
    elseif ARGS[1] == "-select" || ARGS[1] == "-s"
        tests = map(testdir -> (testdir, occursin(OPTIMIZATION_ID, testdir)), ARGS[2:end])
    elseif ARGS[1] == "litmus-opt" || ARGS[1] == "-opt"
        tests = gettests(true)
    elseif ARGS[1] == "litmus-wa" || ARGS[1] == "-wa"
        tests = gettests(false)
    else
        println("Invalid format")
        exit(1)
    end
    map(execute, tests)
end

function gettests(is_opt :: Bool) :: Vector{Tuple{String, Bool}}
    dir_name = is_opt ? LITMUS_OPT_DIR : LITMUS_WA_DIR
    test_names = readdir(dir_name)
    map(test_name -> ("$(dir_name)/$(test_name)", is_opt), test_names)
end

# execute: for the given test, its julia source code is checked that it interprets
# to the expected output, a juliette program corresponding to the source program
# is created, and this juliette program is also tested on the expected output
function execute((testdir, is_opt) :: Tuple{String, Bool})
    println("####### RUNNING TEST $(testdir) #######")
    println("Testing julia code...")
    cd(testdir)
    output = read(pipeline(`julia expected.jl`), String)
    println("Creating juliette code...")
    cd("../../")
    create_redex_file(testdir, is_opt)
    println("Redex file created")
    println("Testing juliette code...")
    cd(testdir)
    output = read(pipeline(`racket redex.rkt`), String)
    cd("../../")
end

runtest()
