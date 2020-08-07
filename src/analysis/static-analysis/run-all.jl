#!/usr/bin/env julia

#**********************************************************************
# Script for running lightweight static analysis of
# eval/invokelatest usage for N most starred packages
#**********************************************************************
#
# Usage:
#
#   $ [julia] run-all.jl N [*]
#
#**********************************************************************

#--------------------------------------------------
# Imports
#--------------------------------------------------

using ArgParse

include("../../utils/lib.jl")
include("lib/pkgs-generation.jl")
include("lib/analysis.jl")

###################################################
# Constants and Parameters
###################################################

const SEP = "##############################"

const pkgsInfoFile = "data/julia-pkgs-info.json"

#--------------------------------------------------
# Command line arguments
#--------------------------------------------------

# → Dict (arguments)
function parse_command_line_args()
    argsStr = ArgParseSettings()
    @add_arg_table! argsStr begin
        "--reload", "-r"
            help = "flag specifying if packages information must be reloaded"
            action = :store_true
        "--generate", "-g"
            help = "flag specifying if packages list must be regenerated"
            action = :store_true
        "--noclone", "-n"
            help = "flag specifying if cloning should be skipped"
            action = :store_true
        "--overwrite", "-w"
            help = "flag specifying if repositories must be overwritten"
            action = :store_true
        "pkgnum"
            help = "number of packages of interest"
            arg_type = Int
            required = true
    end
    parse_args(argsStr)
end

# All script parameters
const PARAMS = parse_command_line_args()

const pkgsNum = PARAMS["pkgnum"]

const pkgsListFile = "data/pkgs-list/top-$(pkgsNum).txt"
const pkgsDir      = "data/pkgs/$(pkgsNum)"
const reportFile   = "data/reports/$(pkgsNum).txt"

###################################################
# Processing
###################################################

# create folders if necessary
for d in ["data", "data/pkgs-list", "data/pkgs", "data/reports"]
    isdir(d) || mkdir(d)
end

# load packages
if !isfile(pkgsListFile) || PARAMS["reload"] || PARAMS["generate"]
    println("Packages list generation\n$(SEP)")
    generatePackagesList(pkgsInfoFile, PARAMS["reload"], pkgsNum, pkgsListFile)
    println()
end

@info "Processing packages from $(pkgsListFile)"
println()

# clone if necessary
if !PARAMS["noclone"]
    println("Cloning\n$(SEP)")
    (cloned, total) = gitcloneAll(pkgsListFile, pkgsDir, PARAMS["overwrite"])
    @info "Successfully processed $(cloned)/$(total) git repos"
    println()
end

# run analysis
println("Analysis\n$(SEP)")
open(reportFile, "w") do io
    analyzePackages(pkgsDir, io)
    @info "Analysis completed; results are in $(pkgsDir)"
end
