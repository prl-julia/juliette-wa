using Pkg

# Overrides the function that is called before the running of package tests
function Pkg.Operations.gen_test_code(testfile::String;
        coverage=false,
        julia_args::Cmd=``,
        test_args::Cmd=``)
    code = """
        push!(LOAD_PATH, "@")
        push!(LOAD_PATH, "@v#.#")
        push!(LOAD_PATH, "@stdlib")
        include("\$(ENV["DYNAMIC_ANALYSIS_DIR"])/function-override.jl")
        include("\$(ENV["DYNAMIC_ANALYSIS_DIR"])/overrideinfo-to-json.jl")
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
