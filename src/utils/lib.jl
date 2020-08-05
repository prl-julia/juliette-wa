#**********************************************************************
# Utilities
#**********************************************************************

const UTILS_DEFINED = true

#--------------------------------------------------
# Imports
#--------------------------------------------------

using Pkg
using Distributed # for cloning

###################################################
# Scripting
###################################################

# String → Nothing
# Prints error message and terminates execution
function exitErrWithMsg(msg :: String)
    #println(stderr, "ERROR: $(msg)")
    @error(msg)
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

#--------------------------------------------------
# Cloning git repositories
#--------------------------------------------------

@everywhere const GIT_EXT = ".git"

# clone only one branch (master by default)
@everywhere const GIT_CLONE_COMMAND = `git clone --single-branch`

# String, String → Int
# Clones git repository [gitrepo] into [dest] if the folder does not yet exist.
# If [overwrite] is set to [true], overwrites the existing folder.
# Returns 1 if cloned successfully, and 0 otherwise
@everywhere function gitclone(
    gitrepo :: String, dest :: String, overwrite :: Bool = false
) :: Int
    GIT_EXT_LEN = length(GIT_EXT)
    # transforms https://github.com/<path>/<name>.git into <name>
    dpath = joinpath(dest, basename(gitrepo)[begin:end-GIT_EXT_LEN])
    # if the repo directory needs to be overwritten, remove it
    overwrite && isdir(dpath) &&
        rm(dpath; recursive=true)
    # if the repo directory does not exist, clone it
    if isdir(dpath)
        1 # if nothing to clone, return 1 to denote success
    else
        try
            runclone() = run(`$(GIT_CLONE_COMMAND) $(gitrepo)`)
            # clone to the proper destinatation
            cd(runclone, dest) ; 1 # cloned successfully
        catch e
            @error e ; 0 # cloning failed
        end
    end
end

# String → Bool
# Checks is [link] looks like git repository link
isGitRepo(link :: String) = !isempty(link) && endswith(link, GIT_EXT)

# String, String → Int, Int
# Clones git repositories listed in [src] file into [dest] directory.
# If [overwrite] is set to [true], overwrites existing folders.
# Assumption: [src] file must list one git address per line.
# Returns pair (# successful clones, # gitrepo links)
function gitcloneAll(src :: String, dest :: String, overwrite :: Bool = false)
    destPath = joinpath(pwd(), dest)
    isdir(dest) || mkdir(dest) # create destinatation if necessary
    repoLinks = filter(isGitRepo, readlines(src))
    # choose sequential or distributed map based on the number of procs
    mapfunc = nprocs() > 1 ? pmap : map
    clonedCnt = sum(mapfunc(
        link -> gitclone(link, destPath, overwrite),
        repoLinks
    ))
    (clonedCnt, length(repoLinks))
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

# String → AST
# Parses [text] as Julia code
parseJuliaCode(text :: String) =
    Meta.parse(join(["quote", text, "end"], ";"))

# String → AST
# Parses file [filePath] as Julia code
parseJuliaFile(filePath :: String) =
    parseJuliaCode(read(filePath, String))

###################################################
# Misc
###################################################

function incrementDict!(dict :: Dict{K, UInt}, key :: K) where K
    haskey(dict, key) ? dict[key] += 1 : dict[key] = 1
    dict
end

# Creates frequency dictionary from a vector
function mkOccurDict(data :: Vector{K}) :: Dict{K, UInt} where K
    foldl(
        incrementDict!, data; 
        init=Dict{K, UInt}()
    )
end