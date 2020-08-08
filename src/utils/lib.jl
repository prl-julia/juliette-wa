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
    Meta.parse(join(["quote", text, "end"], "\n"))

# String → AST
# Parses file [filePath] as Julia code
parseJuliaFile(filePath :: String) =
    parseJuliaCode(read(filePath, String))

###################################################
# Structural Equality Definition
###################################################

# for redefining equality
import Base.==

# Checks e1 and e2 for structural equality (using metaprogramming)
# i.e. compares all the fields of e1 and e2
# Assumption: e1 and e2 have the same type
@generated function structEqual(e1, e2)
    # if there are no fields, we can simply return true
    if fieldcount(e1) == 0
        return :(true)
    end
    mkEq    = fldName -> :(e1.$fldName == e2.$fldName)
    # generate individual equality checks
    eqExprs = map(mkEq, fieldnames(e1))
    # construct &&-expression for chaining all checks
    mkAnd  = (expr, acc) -> Expr(:&&, expr, acc)
    # no need in initial accumulator because eqExprs is not empty
    foldr(mkAnd, eqExprs)
end

# Checks e1 and e2 of arbitrary types for structural equality
genericStructEqual(e1, e2) =
    # if types are different, expressions are not equal
    typeof(e1) != typeof(e2) ?
    false :
    # othewise we need to perform a structural check
    structEqual(e1, e2)

###################################################
# Misc
###################################################

# Dict{K, N}, K → Dict{K, N} where N <: Integer
# Increments value of [dict[key]]
# (or initializes it with 1 if [key] is not in [dict])
function incrementDict!(dict :: Dict{K, N}, key :: K) where {K, N<:Integer}
    haskey(dict, key) ? dict[key] += one(N) : dict[key] = one(N)
    dict
end

# Vector{K} → Dict{K, UInt}
# Creates frequency dictionary from vector [data]
function mkOccurDict(data :: Vector{K}) :: Dict{K, UInt} where K
    foldl(
        incrementDict!, data; 
        init=Dict{K, UInt}())
end

# ormap: retruns true is there exits an item in the iterator for which the
# predicate is true. Note the predicate has a signature of T->Bool if the iterator
# contains items of type T
ormap(predicate, iterator) :: Bool =
    foldr(
        (bool, hastrue) -> bool || hastrue, map(predicate, iterator);
        init=false)
