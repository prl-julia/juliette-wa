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

#--------------------------------------------------
# Imports
#--------------------------------------------------

using ArgParse

include("lib/analysis.jl")

#--------------------------------------------------
# Command line arguments
#--------------------------------------------------

# → Dict (arguments)
function parse_command_line_args()
    argsStr = ArgParseSettings()
    @add_arg_table! argsStr begin
        "--out", "-o"
            help = "file for printing results"
            arg_type = String
            default = ""
        "pkgsdir"
            help = "folder with packages of interest"
            arg_type = String
            required = true
    end
    parse_args(argsStr)
end

# All script parameters
const PARAMS = parse_command_line_args()
const pkgsDir = PARAMS["pkgsdir"]

#--------------------------------------------------
# Main
#--------------------------------------------------

if !isdir(pkgsDir)
    exitErrWithMsg("argument $(pkgsDir) must be a folder")
end

if PARAMS["out"] != ""
    open(PARAMS["out"], "w") do io
        analyzePackages(pkgsDir, io)
    end
else
    analyzePackages(pkgsDir, stdout)
end
