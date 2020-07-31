#**********************************************************************
# Utilities
#**********************************************************************

###################################################
# Scripting
###################################################

# String → Nothing
# Prints error message and terminates execution
function exitErrWithMsg(msg :: String)
    println(stderr, "ERROR: $(msg)")
    exit(1)
end

# String → Nothing
# Prints warning message
function warnMsg(msg :: String)
    println(stderr, "WARNING: $(msg)")
end

# String → Nothing
# Prints info message
function infoMsg(msg :: String)
    println(stdout, "INFO: $(msg)")
end

###################################################
# IO
###################################################

# String, String → Nothing
# Clones git repositories listed in [source] file into [destination] directory
# Assumption: [source] file must list one git address per line
function gitclone(source :: String, destination :: String)
    BASE_DIR = pwd()
    repoLinks = readlines(source)
    cloned = 0
    cloneEachRepo() = map(
        (link) -> isempty(link) ? 
            nothing : 
            isdir(joinpath(BASE_DIR, destination, 
                               basename(link)[begin:end-length(".git")])) ||
                try 
                    run(`git clone $(link)`)
                    cloned += 1 
                catch e
                end, 
        repoLinks
    )
    isdir(destination) || mkdir(destination)
    cd(cloneEachRepo, destination)
    (cloned, length(repoLinks))
end

###################################################
# Parsing Julia Files
###################################################

# https://discourse.julialang.org/t/parsing-a-julia-file/32622
#=
parsefile(file) = parse(join(["quote", readstring(file), "end"], ";"))

parsecode(code::String)::Vector =
    # https://discourse.julialang.org/t/parsing-a-julia-file/32622
    filter(x->!(x isa LineNumberNode),
           Meta.parse(join(["quote", code, "end"], ";")).args[1].args)
=#
parseJuliaFile(filePath :: String) =
    Meta.parse(join(["quote", read(filePath, String), "end"], ";"))
