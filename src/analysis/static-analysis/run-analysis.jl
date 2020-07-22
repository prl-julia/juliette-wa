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

println("# Ok folders: $(goodPkgsCount)\n")
interestingPkgsCount = 0
for pkgInfo in goodPkgs
    if (pkgInfo.interestingFiles > 0)
        println("$(pkgInfo.pkgName): $(pkgInfo.pkgStat)")
        println("# interesting files: $(pkgInfo.interestingFiles)/$(pkgInfo.totalFiles)")
        global interestingPkgsCount += 1
        println(pkgInfo.filesStat)
    end
    #println()
end
println("Interesting packages: $(interestingPkgsCount)/$(goodPkgsCount)")