#!/usr/bin/env julia

#**********************************************************************
# Script for running lightweight static analysis of
# eval/invokelatest usage for N packages
#**********************************************************************
# 
# Usage:
#
#   $ [julia] run-all.jl N [*]
# 
#**********************************************************************

include("../../utils/lib.jl")

if length(ARGS) == 0
    exitErrWithMsg("1 argument is expected -- number of packages")
end

pkgsNum = 0
try
    global pkgsNum = parse(Int, ARGS[1])
catch
    exitErrWithMsg("argument $(ARGS[1]) must be a number")
end

const SEP = "##############################"

const pkgsListFile = "data/pkgs-list/top-$(pkgsNum).txt"
const pkgsDir      = "data/pkgs/$(pkgsNum)"
const reportFile   = "data/reports/$(pkgsNum).txt"

if !isfile(pkgsListFile) || length(ARGS) > 1
    println("Packages list generation\n$(SEP)")
    run(`julia gen-pkgs-list.jl $(pkgsNum) -o $(pkgsListFile)`)
end
println("\nCloning\n$(SEP)")
run(` ../../utils/clone.jl -s $(pkgsListFile) -d $(pkgsDir)`)
println("\nAnalysis\n$(SEP)")
run(pipeline(`julia run-analysis.jl $(pkgsDir)`, stdout=reportFile))
