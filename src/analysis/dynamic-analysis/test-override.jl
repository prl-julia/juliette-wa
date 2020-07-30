using Pkg

function Pkg.Operations.gen_test_code(testfile::String;
# function gen_test_code(testfile::String;
        coverage=false,
        julia_args::Cmd=``,
        test_args::Cmd=``)
    code = """
        push!(LOAD_PATH, "@")
        push!(LOAD_PATH, "@v#.#")
        push!(LOAD_PATH, "@stdlib")
        include("\$(ENV["DYNAMIC_ANALYSIS_DIR"])/func-override.jl")
        $(Base.load_path_setup_code(false))
        cd($(repr(dirname(testfile))))
        append!(empty!(ARGS), $(repr(test_args.exec)))
        include($(repr(testfile)))
        """
    return ```
        $(Base.julia_cmd())
        --code-coverage=$(coverage ? "user" : "none")
        --color=$(Base.have_color === nothing ? "auto" : Base.have_color ? "yes" : "no")
        --compiled-modules=$(Bool(Base.JLOptions().use_compiled_modules) ? "yes" : "no")
        --check-bounds=yes
        --depwarn=$(Base.JLOptions().depwarn == 2 ? "error" : "yes")
        --inline=$(Bool(Base.JLOptions().can_inline) ? "yes" : "no")
        --startup-file=$(Base.JLOptions().startupfile == 1 ? "yes" : "no")
        --track-allocation=$(("none", "user", "all")[Base.JLOptions().malloc_log + 1])
        $(julia_args)
        --eval $(code)
    ```
end

# ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
# ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = "testpkg"
# const TEST_DIR_PREFIX = "C:/Users/gelin/Documents/computer-science/research/julia/juliette-wa/src/analysis/eval-programs/"
# run(gen_test_code(string(TEST_DIR_PREFIX, "test02.jl")))
