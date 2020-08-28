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
include("eval-parsing.jl")

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

#--------------------------------------------------
# Data Types
#--------------------------------------------------

# Eval argument statistics
#------------------------------

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

# Summary of a set of packages
mutable struct PackagesTotalStat
    totalStat   :: Stat
    evalStat    :: EvalArgStat
    derivedStat :: Dict{String, Int}
    trackedPkgs :: Dict{String, Vector{String}}
end
PackagesTotalStat(ds :: Dict{String, Int}, tps :: Dict{String, Vector{String}}) =
    PackagesTotalStat(Stat(), EvalArgStat(), ds, tps)

#--------------------------------------------------
# Show
#--------------------------------------------------

#Base.show(io :: IO, evalInfo :: EvalCallInfo) = print(io, evalInfo.astHead)

string10(x :: UInt) = string(x, base=10)

Base.show(io :: IO, un :: UInt) = print(io, string10(un))

Base.show(io :: IO, evStat :: EvalArgStat) = print(io, 
    "(" * 
    join(map(kv -> "$(kv[1]) => $(kv[2])",
         sort(collect(pairs(evStat)); by=kv->kv[2], rev=true)), ", ") *
    ")")

Base.show(io :: IO, stat :: Stat) = print(io,
    "{ev: $(stat.eval), il: $(stat.invokelatest)}\n" *
    "  [evalArgs: $(stat.evalArgStat)]")

Base.show(io :: IO, stat :: FilesStat) = begin
    for info in stat
        println(io, "* $(info[1]) => $(info[2])")
    end
end

#--------------------------------------------------
# Stat Arithmetic
#--------------------------------------------------

Base.:+(x :: EvalArgStat, y :: EvalArgStat) = merge(+, x, y)

Base.zero(::Type{Stat}) = Stat()

Base.sum(stat :: Stat) :: UInt = stat.eval + stat.invokelatest

Base.:+(x :: Stat, y :: Stat) =
    Stat(x.eval + y.eval, x.invokelatest + y.invokelatest,
         x.evalArgStat + y.evalArgStat)

function incrementPkgsEvalStat!(
    totPkgsEvalStat :: EvalArgStat, evalStat :: EvalArgStat
) :: EvalArgStat
    for kv in evalStat
        if kv[2] > 0
            incrementDict!(totPkgsEvalStat, kv[1])
        end
    end
    totPkgsEvalStat
end

function addStats!(
    pts :: PackagesTotalStat, totalStat :: Stat, evalStat :: EvalArgStat
)
    pts.totalStat += totalStat;
    incrementPkgsEvalStat!(pts.evalStat, evalStat)
    pts
end

###################################################
# Algorithms
###################################################

#--------------------------------------------------
# Eval Arguments Statistics
#--------------------------------------------------

# AST → UInt
# Counts the number of calls to eval in [e]
# Note. It does not go into quote, e.g. inner eval in
#       [eval(:(eval(...)))] is ignored
countEval(e :: Expr) :: UInt =
    isEvalCall(e) ?
        1 : #(@show e ; 1) :
        sum(map(countEval, e.args))
countEval(@nospecialize e) :: UInt = 0

# AST → [Symbol] (Note that Symbol ~ EvalCallInfo at the moment)
# Collects information about eval call [e]
# assuming [e] IS an eval call (eval can be callen with no arguments)
getEvalInfo(e :: Expr, context=EvalArgContext()) :: Vector{EvalCallInfo} = 
    length(e.args) > 1 ?
        argDescr(e.args[end], context) : 
        [EvalCallInfo(:nothing, context)]

# AST → EvalCallsVec
# Collects information about arguments of all eval calls in [e]
gatherEvalInfo(e :: Expr, context=EvalArgContext()) :: EvalCallsVec =
    if isFunDef(e)
        # function definition should have exactly 2 arguments
        # gather info about function body
        result = length(e.args) > 1 ? 
            gatherEvalInfo(e.args[2], EvalArgContext(true, context.inQuote)) :
            EvalCallInfo[]
        # if our function is [function eval] or [eval(...) =],
        # we want to record that we saw an eval definition
        if isCall(e.args[1]) && isEvalName(e.args[1].args[1])
            push!(result, EvalCallInfo(:EvalDef, context))
        end
        result
    elseif isEvalCall(e)
        # @eval treats its arguments as an AST already,
        # i.e. [@eval f()] is the same as [eval(:(f()))], which we want
        # to distinguish from eval(f())
        getEvalInfo(e, EvalArgContext(context.inFunDef, isMacroCall(e)))
    else
        foldl(
            vcat,
            map(arg -> gatherEvalInfo(arg, context), e.args);
            init=EvalCallInfo[]
        )
    end
gatherEvalInfo(@nospecialize(e), context=EvalArgContext()) :: EvalCallsVec =
    EvalCallInfo[]

#--------------------------------------------------
# Single File Statistics
#--------------------------------------------------

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
# We use [filePath] for error reporting
function computeStat(text :: String, filePath :: String) :: Stat
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
            if isa(e, Base.Meta.ParseError)
                @warn filePath e
            else
                @error filePath e
            end
            Stat(ev, il, EvalArgStat(EvalCallInfo(:EvPrsERR) => ev))
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
        stat = computeStat(read(filePath, String), filePath)
        #@info filePath stat
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
function processPkg(pkgPath :: String, pkgName :: String) :: PackageStat
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

# String → Vector{PackageStat}, Vector{PackageStat}
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

###################################################
# Main
###################################################

#--------------------------------------------------
# Aux output
#--------------------------------------------------

function outputPkgsProcessingSummary(io :: IO,
    goodPkgsCnt, badPkgs :: Vector
)
    badPkgsCnt = length(badPkgs)
    totalCnt = goodPkgsCnt + badPkgsCnt
    println(io, "# processed package folders: $(totalCnt)")
    println(io, "# failed (no [src]): $(badPkgsCnt)/$(totalCnt)")
    badPkgsCnt == 0 ||
        for pkgInfo in badPkgs
            println(io, pkgInfo.pkgName)
        end
    println(io, "# successfully processed folders: $(goodPkgsCnt)\n")
    println(io, "==============================\n")
end

#--------------------------------------------------
# Computing derived metrics
#--------------------------------------------------

getAstHeads(stat :: Stat) :: Vector{Symbol} =
    map(x -> x.astHead, collect(keys(stat.evalArgStat)))

maybeInFunDefFunction(stat :: Stat) =
    !isempty(intersect(
        getAstHeads(stat),
        [SYM_FUNC, :macro, SYM_MCALL, SYM_LAM, :variable, :expr, :parse, :($),
         :gencall, :include, :useimport, :toplevel]
    ))

maybeInFunCallFunction(stat :: Stat) =
    !isempty(intersect(
        getAstHeads(stat),
        [SYM_CALL, :variable, :($), :expr, :parse, :gencall]
    )) ||
    stat.invokelatest > 0

likelyInFunCallFunction(stat :: Stat) =
    in(SYM_CALL, getAstHeads(stat)) ||
    stat.invokelatest > 0

likelyInFunCallFunctionButNotDef(stat :: Stat) =
    likelyInFunCallFunction(stat) && !maybeInFunDefFunction(stat)

maybeInFunDefFunButNotCall(stat :: Stat) =
    maybeInFunDefFunction(stat) && !likelyInFunCallFunction(stat)

allEvalsAreTopLevel(stat :: Stat) =
    all(evalInfo -> !evalInfo.context.inFunDef, keys(stat.evalArgStat))

allEvalsAreTopLevelAndNoIL(stat :: Stat) =
    all(evalInfo -> !evalInfo.context.inFunDef, keys(stat.evalArgStat)) &&
    stat.invokelatest == 0

const BORING_EVAL_ARGS = [
        :export, :const, :(=), :global, :local, :struct, :EvalDef,
        SYM_NFUNC_M, SYM_S_PRINT, 
    ]

evalIsBoring(evalInfo :: EvalCallInfo) :: Bool = 
    !evalInfo.context.inFunDef ||
    in(evalInfo.astHead, BORING_EVAL_ARGS)
allEvalsAreBoringAndNoIL(stat :: Stat) =
    all(evalIsBoring, keys(stat.evalArgStat)) &&
    stat.invokelatest == 0

singleTopLevelEvalAndNoIL(stat :: Stat) =
    stat.eval == 1 && !first(keys(stat.evalArgStat)).context.inFunDef &&
    stat.invokelatest == 0

likelyImpactWorldAge(stat :: Stat) = begin
    # if totally boring, then not interesting
    if allEvalsAreBoringAndNoIL(stat)
        return false
    end
    # leave only inFun elements that are not boring
    inFunArgs = filter(
        evalInfo -> evalInfo.context.inFunDef && 
            !in(evalInfo.astHead, BORING_EVAL_ARGS), 
        keys(stat.evalArgStat)
    )
    # if most things are top-level and boring,
    # and there is just one non-boring thing, it might be misclassified
    !(length(inFunArgs) == 0 ||
      length(inFunArgs) == 1 && length(stat.evalArgStat) > 3)
end

hasEval(stat :: Stat) = stat.eval > 0
hasOnlyEval(stat :: Stat) = stat.eval > 0 && stat.invokelatest == 0
hasOnlyIL(stat :: Stat) = stat.invokelatest > 0 && stat.eval == 0
hasBothEvalIL(stat :: Stat) = stat.eval > 0 && stat.invokelatest > 0

const derivedConditions = Dict(
    #"allEvalTop"        => allEvalsAreTopLevel,
    "allEvalTopNoIL"    => allEvalsAreTopLevelAndNoIL,
    "allEvalBoringNoIL" => allEvalsAreBoringAndNoIL,
    "1TopEvalNoIL"      => singleTopLevelEvalAndNoIL,
    "fundef?"           => maybeInFunDefFunction,
    "onlyfundef?"       => maybeInFunDefFunButNotCall,
    "funcall?"          => maybeInFunCallFunction,
    "onlyfuncall!"      => likelyInFunCallFunctionButNotDef,
    "il"                => stat -> stat.invokelatest > 0,
    "likelyBypassWA"    => likelyInFunCallFunction,
    "likelyImpactWA"    => likelyImpactWorldAge,
    "likelyBoth"        => stat -> likelyInFunCallFunction(stat) && likelyImpactWorldAge(stat),
    "hasOnlyEval"       => hasOnlyEval,
    "hasOnlyIL"         => hasOnlyIL,
    "hasBothEvalIL"     => hasBothEvalIL,
    "hasEval"           => hasEval
)

function computeDerivedMetrics(
    pkgInfos :: Vector{PackageStat}, io :: IO
) :: PackagesTotalStat
    pkgsStat :: PackagesTotalStat = PackagesTotalStat(
        Dict{String, Int}(map(param -> param=>0, [
            "non_vacuous", "allEvalTop",
            "allEvalBoringNoIL", "allEvalTopNoIL", "1TopEvalNoIL",
            "fundef?", "onlyfundef?",
            "funcall?", "onlyfuncall!", "il",
            "likelyImpactWA", "likelyBypassWA", "likelyBoth",
            "hasOnlyEval", "hasOnlyIL", "hasBothEvalIL", "hasEval"
            ])),
        Dict{String, Vector{String}}(map(param -> param=>String[], [
            "likelyBypassWA", "likelyImpactWA", "likelyBoth"]))
    )
    for pkgInfo in pkgInfos
        # we don't output information about packages without eval/invokelatest
        pkgInfo.interestingFiles > 0 || continue
        println(io, "$(pkgInfo.pkgName): $(pkgInfo.pkgStat)")
        println(io, "# non vacuous files: $(pkgInfo.interestingFiles)/$(pkgInfo.totalFiles)")
        println(io, pkgInfo.filesStat)
        # compute summary stats
        pkgsStat.derivedStat["non_vacuous"] += 1
        addStats!(pkgsStat, pkgInfo.pkgStat, pkgInfo.pkgStat.evalArgStat)
        # ask more specific questions
        for propCond in derivedConditions
            if propCond[2](pkgInfo.pkgStat)
                pkgsStat.derivedStat[propCond[1]] += 1
                if haskey(pkgsStat.trackedPkgs, propCond[1])
                    push!(pkgsStat.trackedPkgs[propCond[1]], pkgInfo.pkgName)
                end
            end
        end
    end
    pkgsStat
end

#--------------------------------------------------
# Running analysis on packages
#--------------------------------------------------
using JLD
# Runs analysis on all packages from [pkgsDir]
function analyzePackages(pkgsDir :: String, io :: IO)
    isdir(pkgsDir) ||
        exitErrWithMsg("$(pkgsDir) must be a folder")
    # processing summary
    (badPkgs, goodPkgs) = processPkgsDir(pkgsDir)
    goodPkgsCnt = length(goodPkgs)
    outputPkgsProcessingSummary(io, goodPkgsCnt, badPkgs)
    # analyze all packages and summarize stats
    pkgsStat :: PackagesTotalStat = computeDerivedMetrics(goodPkgs, io)
    save("analysis-results.jld", "pkgs", goodPkgs, "summary", pkgsStat)
    derivedStat = pkgsStat.derivedStat
    # output derived stats
    println(io, "==============================\n")
    println(io,
        "Non vacuous packages: $(derivedStat["non_vacuous"])/$(goodPkgsCnt)")
    println(io, "* all evals are top-level and no invokelatest: $(derivedStat["allEvalTopNoIL"])/$(goodPkgsCnt)")
    println(io, "* all evals are boring and no invokelatest: $(derivedStat["allEvalBoringNoIL"])/$(goodPkgsCnt)")
    #println(io, "* all evals are top-level: $(derivedStat["allEvalTop"])/$(goodPkgsCnt)")
    println(io, "* single top-level eval and no invokelatest: $(derivedStat["1TopEvalNoIL"])/$(goodPkgsCnt)")
    println(io, "* maybe function defs in fun: $(derivedStat["fundef?"])/$(goodPkgsCnt)")
    println(io, "* maybe function defs in fun but not likely calls: $(derivedStat["onlyfundef?"])/$(goodPkgsCnt)")
    println(io, "* likely function calls in fun but not defs: $(derivedStat["onlyfuncall!"])/$(goodPkgsCnt)")
    println(io, "* maybe function calls in fun: $(derivedStat["funcall?"])/$(goodPkgsCnt)")
    println(io, "* invokelatest: $(derivedStat["il"])/$(goodPkgsCnt)")
    println(io, "* !!! likely function calls in fun (bypass world age?): $(derivedStat["likelyBypassWA"])/$(goodPkgsCnt)")
    println(io, "* !!! likely impact world age: $(derivedStat["likelyImpactWA"])/$(goodPkgsCnt)")
    println(io, "* !!! likely both: $(derivedStat["likelyBoth"])/$(goodPkgsCnt)")
    println(io, "hasEval: $(derivedStat["hasEval"])/$(goodPkgsCnt)")
    println(io, "hasOnlyEval: $(derivedStat["hasOnlyEval"])/$(goodPkgsCnt)")
    println(io, "hasBothEvalIL: $(derivedStat["hasBothEvalIL"])/$(goodPkgsCnt)")
    println(io, "hasOnlyIL: $(derivedStat["hasOnlyIL"])/$(goodPkgsCnt)")
    println(io)
    println(io, "Total Stat:")
    for info in sort(collect(pkgsStat.totalStat.evalArgStat);
                     by=kv->kv[2], rev=true)
        println(io,
            "* $(rpad(info[1].astHead, 10)) $(rpad(showEvalLevel(info[1].context), 11))" *
            " => $(lpad(info[2], 4))" *
            " in $(lpad(pkgsStat.evalStat[info[1]], 3)) pkgs")
    end
    println(io)
    println(io, join(pairs(pkgsStat.trackedPkgs), "\n\n"))
    println(io)
end


