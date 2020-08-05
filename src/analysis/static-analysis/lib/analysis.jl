#**********************************************************************
# Lightweight static analysis of eval/invokelatest
#**********************************************************************
# 
# 1) Reads files in [src] directory and counts the number of occurences
#    of "eval(", "@eval(", "@eval ", and "invokelatest("
#
# 2) For calls to eval, uses Julia parser to collect information about
#    AST heads of expressions passed to eval.
# 
#**********************************************************************

#--------------------------------------------------
# Imports
#--------------------------------------------------

# Just in case, we don't want to include code repeatedly
Core.isdefined(Main, :UTILS_DEFINED) ||
    include("../../../utils/lib.jl")

import Base.show

###################################################
# Data
###################################################

#--------------------------------------------------
# Constants
#--------------------------------------------------

# Text-based analysis
#------------------------------

# regex-patterns for calls to eval/invokelatest
#   (\W means non-word character and ^ means beginning of input --
#    to exclude cases such as "my_eval(")
CALL_PATTERN(name :: String) = Regex("(\\W|^)$(name)\\(") # r"(\W|^)eval\("
const PATTERN_EVAL = CALL_PATTERN("eval")
const PATTERN_INVOKELATEST = CALL_PATTERN("invokelatest")
const PATTERN_EVAL_MACRO = r"@eval( |\()"

# AST-based analysis
#------------------------------

# Symbol representation of AST heads that we count
# Note. [:other] includes, e.g., [&&] operator used in [Genie] package
const EVAL_ARG_DESCRIPTIONS = [
        :value, :symbol, :block, :curly, :let, :., :ref,
        :struct, :module,
        :export, :import, :using,
        :const, :(=),
        :function, :macro, :call, :macrocall,
        :($),
        :nothing, :other, :error
    ]

# Useful symbols for parsing
const SYM_EVAL   = :eval
const SYM_EVALM  = Symbol("@eval")
const SYM_CORE   = :Core
const SYM_DOT    = :.
const QUOTE_EVAL = :(:eval)
const SYM_CALL   = :call
const SYM_MCALL  = :macrocall

#--------------------------------------------------
# Data Types
#--------------------------------------------------

# Eval argument statistics
#------------------------------

# Information about eval argument
#struct EvalCallInfo
#    astHead :: Symbol
#end
EvalCallInfo = Symbol

EvalCallsSummary = Vector{EvalCallInfo}

# Frequency of eval arguments
EvalArgStat = Dict{EvalCallInfo, UInt}

# Overall statistics
#------------------------------

# Eval/invokelatest usage statistics
struct Stat
    eval         :: UInt # number of calls to eval
    invokelatest :: UInt # number of calls to invokelatest
    evalArgStat  :: EvalArgStat # stat of AST heads of evaled expressions
end
Stat() = Stat(0, 0, EvalArgStat())
Stat(ev :: Int, il :: Int) = Stat(ev, il, EvalArgStat())

# Files statistics (fileName => statistics)
FilesStat = Dict{String, Stat}

# Single package statistics
mutable struct PackageStat
    pkgName          :: String
    hasSrc           :: Bool
    totalFiles       :: UInt # number of source files
    failedFiles      :: UInt # number of files that failed to process
    interestingFiles :: UInt # number of files with eval/invokelatest
    filesStat        :: FilesStat # fileName => statistics
    pkgStat          :: Stat # package summary statistics
end
# default constructor
PackageStat(pkgName :: String, hasSrc :: Bool) = 
    PackageStat(pkgName, hasSrc, 0, 0, 0, FilesStat(), Stat())

#--------------------------------------------------
# Show
#--------------------------------------------------

#Base.show(io :: IO, evalInfo :: EvalCallInfo) = print(io, evalInfo.astHead)

string10(x :: UInt) = string(x, base=10)

Base.show(io :: IO, un :: UInt) = print(io, string10(un))

Base.show(io :: IO, stat :: Stat) = print(io,
    "{ev: $(stat.eval), il: $(stat.invokelatest)}\n" *
    "[evalArgs: $(stat.evalArgStat)]")

function Base.show(io :: IO, stat :: FilesStat)
    for info in stat
        println(io, "* $(info[1]) => $(info[2])")
    end
end

#--------------------------------------------------
# Stat Arithmetic
#--------------------------------------------------

Base.:+(x :: EvalArgStat, y :: EvalArgStat) = merge(+, x, y)

Base.zero(::Type{Stat}) = Stat()

Base.:+(x :: Stat, y :: Stat) =
    Stat(x.eval + y.eval, x.invokelatest + y.invokelatest,
         x.evalArgStat + y.evalArgStat)

###################################################
# Algorithms
###################################################

#--------------------------------------------------
# Eval Arguments Statistics
#--------------------------------------------------

# Parsing eval
#------------------------------

# AST → Bool
# Checks if [e] represents standard name of [eval]
isEvalName(e :: Symbol) = e == SYM_EVAL # eval
isEvalName(e :: Expr) =                 # Core.eval
    e.head == SYM_DOT && e.args[1] == SYM_CORE && e.args[2] == QUOTE_EVAL
isEvalName(@nospecialize e) = false     # everything else is not

# AST → Bool
# Checks if [e] represents standard name of [@eval]
isEvalMacroName(e :: Symbol) = e == SYM_EVALM   # @eval
isEvalMacroName(@nospecialize e) = false        # everything else is not

# AST → Bool
# Checks if [e] represents a call
isCall(e :: Expr) = e.head == :call
isCall(@nospecialize e) = false

# AST → Bool
# Checks if [e] represents a call to eval (either normal or macro)
isEvalCall(e :: Expr) =
    # eval/Core.eval
    e.head == SYM_CALL && isEvalName(e.args[1]) ||
    # @eval
    e.head == SYM_MCALL && isEvalMacroName(e.args[1])
isEvalCall(@nospecialize e) = false

# Collecting eval statistics
#------------------------------

# AST → UInt
# Counts the number of calls to eval in [e]
# Note. It does not go into quote, e.g. inner eval in
#       [eval(:(eval(...)))] is ignored
countEval(e :: Expr) :: UInt =
    isEvalCall(e) ?
        1 : #(@show e ; 1) :
        sum(map(countEval, e.args))
countEval(@nospecialize e) :: UInt = 0

# AST → [Symbol]
# Maps [arg] (argument of eval) to symbol(s) describing its kind
# (one of EVAL_ARG_DESCRIPTIONS).
# Usually the result will be just one symbol, but if it's a block,
# we want to count all subcompponents.
argDescrUnsafe(arg :: Nothing) = [:nothing]
argDescrUnsafe(arg :: QuoteNode) = argDescrUnsafe(arg.value)
argDescrUnsafe(arg :: Symbol) = [:symbol]
argDescrUnsafe(arg :: Expr) =
    if arg.head == :quote
        argDescrUnsafe(arg.args[1])
    # [=] means either function or assignment
    elseif arg.head == :(=)
        isCall(arg.args[1]) ? [:function] : [:(=)]
    # anonymous function
    elseif arg.head == :(->)
        [:function]
    # sometimes block has just one thing in it
    elseif arg.head == :block
        args = filter(e -> !isa(e, LineNumberNode), arg.args)
        len = length(args)
        len == 0 ? [:nothing] : len == 1 ? argDescrUnsafe(args[1]) : 
            foldl(vcat, map(argDescrUnsafe, args))
    elseif in(arg.head, EVAL_ARG_DESCRIPTIONS)
        [arg.head]
    else
        [:other]
    end
# if it's something like Int, consider it a value
argDescrUnsafe(@nospecialize arg) = [:value]

# AST → [Symbol]
# Maps [arg] (argument of eval) to symbol(s) describing its kind
# (one of EVAL_ARG_DESCRIPTIONS).
argDescr(arg :: Any) = try argDescrUnsafe(arg) catch ; [:error] end

# AST → [Symbol] (Note that Symbol ~ EvalCallInfo at the moment)
# Collects information about eval call [e]
# assuming [e] IS an eval call (eval can be callen with no arguments)
getEvalInfo(e :: Expr) :: Vector{EvalCallInfo} = 
    length(e.args) > 1 ? argDescr(e.args[end]) : [:nothing]

# AST → EvalCallsSummary
# Collects information about arguments of all eval calls in [e]
gatherEvalInfo(e :: Expr) :: EvalCallsSummary =
    isEvalCall(e) ?
        getEvalInfo(e) :
        foldl(vcat, map(gatherEvalInfo, e.args); init=EvalCallInfo[])
gatherEvalInfo(@nospecialize e) :: EvalCallsSummary = EvalCallInfo[]

#--------------------------------------------------
# Single File Statistics
#--------------------------------------------------

Base.sum(stat :: Stat) :: UInt = stat.eval + stat.invokelatest

# Checks if statistics is not useless, i.e. there is at least one call
# to eval or invokelatest
nonVacuous(stat :: Stat) :: Bool = sum(stat) > 0
    #stat.invokelatest > 0

# Some measure of interest (we consider [stat] the most interesting
# if there are both eval and invokelatest calls)
interestFactor(stat :: Stat) :: UInt = let
    Z = zero(UInt)
    hasEval   = stat.eval > Z
    hasInvoke = stat.invokelatest > Z
    val = sum(stat)
    xor(hasEval, hasInvoke) ?
        val :
        (hasEval || hasInvoke ? 1000+val : Z)
end

# Computes eval/invokelatest statistics for source code [text]
function computeStat(text :: String) :: Stat
    ev = count(PATTERN_EVAL, text) + count(PATTERN_EVAL_MACRO, text)
    il = count(PATTERN_INVOKELATEST, text)
    # get more details about eval if possible
    if ev > 0
        try
            evalInfos = gatherEvalInfo(parseJuliaCode(text))
            evArgStat = mkOccurDict(evalInfos)
            # parsing gives more precise results
            Stat(sum(values(evArgStat)), il, evArgStat)
        catch e
            @error e
            Stat(ev, il)
        end
    else
        Stat(ev, il)
    end
end

#--------------------------------------------------
# Single Package Statistics
#--------------------------------------------------

# String → Bool
isJuliaFile(fname :: String) :: Bool = endswith(fname, ".jl")

# String, PackageStat, String → Nothing
# Reads [filePath] located in [pkgPath]
#   and updates [pkgStat] accordingly with eval/invokelatest stats
function processFile(pkgPath::String, pkgStat::PackageStat, filePath::String)
    try
        stat = computeStat(read(filePath, String))
        if nonVacuous(stat)
            pkgStat.interestingFiles += 1
            # cut pkgPath from file name for readability
            pkgStat.filesStat[filePath[length(pkgPath)+1:end]] = stat
        end
    catch e
        println(stderr, e)
        pkgStat.failedFiles += 1
    end
end

# String, String → PackageStat
# Walks [src] directory of package [pkgName] located at [pkgPath]
# and collects eval/invokelatest statistics
function processPkg(pkgPath :: String, pkgName :: String)
    # we assume that correct Julia packages have [src] folder
    srcPath = joinpath(pkgPath, "src")
    # init statistics
    pkgStat = PackageStat(pkgName, isdir(srcPath))
    pkgStat.hasSrc || return pkgStat # exit if no [src]
    # recursively walk all files in [src]
    for (root, _, files) in walkdir(srcPath)
        # we are only interested in Julia files
        files = filter(isJuliaFile, files)
        pkgStat.totalFiles += length(files)
        for file in files
            filePath = joinpath(root, file)
            processFile(pkgPath, pkgStat, filePath)
        end
    end
    # package summary statistics
    if pkgStat.interestingFiles > 0
        pkgStat.pkgStat = foldl(+, values(pkgStat.filesStat))
    end
    pkgStat
end

#--------------------------------------------------
# Packages
#--------------------------------------------------

isGoodPackage(pkgStat :: PackageStat) :: Bool = pkgStat.hasSrc

getInterestFactor(pkgStat :: PackageStat) :: UInt =
    interestFactor(pkgStat.pkgStat)

# String → (Vector{PackageStat}, Vector{PackageStat})
# Processes every folder in [path] as a package folder
# and computes its statistics for it.
# Returns failed packages and stats for successfully processed packages
function processPkgsDir(path :: String)
    paths = map(name -> (joinpath(path, name), name), readdir(path))
    dirs  = filter(d -> isdir(d[1]), paths)
    pkgsStats = map(d -> processPkg(d[1], d[2]), dirs)
    goodPkgs  = filter(isGoodPackage,  pkgsStats)
    badPkgs   = filter(!isGoodPackage, pkgsStats)
    # sort packages information from most interesting to less interesting
    (badPkgs, sort(goodPkgs, by=getInterestFactor, rev=true))
end


#--------------------------------------------------
# Aux
#--------------------------------------------------

# Creates frequency dictionary from a vector
function mkOccurDict(data :: Vector{T}) :: Dict{T, UInt} where T
    foldl(
        (dict, elem) -> 
            (haskey(dict, elem) ? dict[elem] += 1 : dict[elem] = 1; dict),
        data; init=Dict{T, UInt}()
    )
end
