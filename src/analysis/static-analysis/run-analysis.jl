#!/usr/bin/env julia

#**********************************************************************
# Script for running lightweight static analysis of
# eval/invokelatest usage in the given directory
#**********************************************************************
# 
# Usage:
#
#   $ [julia] run-analysis.jl <pkgsdir>
#
# Folder [pkgsdir] should contain downloaded packages.
# 
#**********************************************************************

include("../../utils/lib.jl")
include("lib.jl")

if length(ARGS) == 0
    exitErrWithMsg("1 argument is expected -- packages folder")
end

const pkgsDir = ARGS[1]
if !isdir(pkgsDir)
    exitErrWithMsg("argument $(pkgsDir) must be a folder")
end

const SEP = "******************************\n"

(badPkgs, goodPkgs) = processPkgsDir(pkgsDir)
goodPkgsCount = length(goodPkgs)

println("# folders: $(length(badPkgs) + goodPkgsCount)")
println(SEP)

println("# failed folders (without src): $(length(badPkgs))")
for pkgInfo in badPkgs
    println(pkgInfo.pkgName)
end
println(SEP)

superInteresting(stat :: Stat) =
    length(intersect(
        keys(stat.evalArgStat),
        [:function, :macro, :call, :macrocall, :block, :module,])
    ) > 0
maybeDefineFunction(stat :: Stat) =
    length(intersect(
        keys(stat.evalArgStat),
        [:function, :macro, :block,])
    ) > 0
maybeCallFunction(stat :: Stat) =
    length(intersect(
        keys(stat.evalArgStat),
        [:call, :macrocall, :block,])
    ) > 0

println("# Ok folders: $(goodPkgsCount)\n")

interestingPkgsCount = 0
superInterestingPkgsCount = 0
totalStat = Stat()
evalFunAndIL = 0
superInterestingPkgs = String[]

for pkgInfo in goodPkgs
    if (pkgInfo.interestingFiles > 0)
        println("$(pkgInfo.pkgName): $(pkgInfo.pkgStat)")
        println("# interesting files: $(pkgInfo.interestingFiles)/$(pkgInfo.totalFiles)")
        global interestingPkgsCount += 1
        println(pkgInfo.filesStat)
        global totalStat += pkgInfo.pkgStat
        if superInteresting(pkgInfo.pkgStat)
            global superInterestingPkgsCount += 1
            if maybeDefineFunction(pkgInfo.pkgStat) &&
               (maybeCallFunction(pkgInfo.pkgStat) || pkgInfo.pkgStat.invokelatest > 0)
                global evalFunAndIL += 1
                push!(superInterestingPkgs, pkgInfo.pkgName)
            end
        end
        #=
        if pkgInfo.pkgStat.invokelatest > 0 &&
                maybeDefineFunction(pkgInfo.pkgStat)
                #in(:function, keys(pkgInfo.pkgStat.evalArgStat))
            global evalFunAndIL += 1
        end
        =#
    end
    #println()
end
println("Interesting packages: $(interestingPkgsCount)/$(goodPkgsCount)")
println("Super Interesting packages: $(superInterestingPkgsCount)/$(goodPkgsCount)")
println()
println("Eval func and invokelatest: $(evalFunAndIL)")
println(superInterestingPkgs)
println()
println("Total Stat:")
for info in totalStat.evalArgStat
    println("* $(info[1]) => $(info[2])")
end
