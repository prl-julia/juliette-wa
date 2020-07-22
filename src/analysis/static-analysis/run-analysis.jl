#!/usr/bin/env julia

#**********************************************************************
# Script for running lightweight static analysis of
# eval/invokelatest usage in the given directory
#**********************************************************************
# 
# Usage:
#
#   $ [julia] run-analysis.jl
#
# 
# 
#**********************************************************************

include("lib.jl")

result = processPkgsDir(ARGS[1]) 
pkgsCount = length(result)
println(pkgsCount)
println()
#println(result)

interestingPkgsCount = 0
for pkgInfo in result
    if (pkgInfo[2].interestingFiles > 0)
        println("$(pkgInfo[1]): $(pkgInfo[2].interestingFiles)/$(pkgInfo[2].totalFiles)")
        global interestingPkgsCount += 1
        println(pkgInfo[2].filesStat)
    end
    #println()
end

println("Interesting packages: $(interestingPkgsCount)/$(pkgsCount)")