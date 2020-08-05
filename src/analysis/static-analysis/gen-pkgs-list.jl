#!/usr/bin/env julia

#**********************************************************************
# Script for generating a list of most starred Julia packages
# with the exception of Julia itself
#**********************************************************************
# 
# Usage:
#
#   $ [julia] gen-pkgs-list.jl [-n] [-p <json-file>] [-r] [-o <txt-file>] [-s]
#                              N
#
# Outputs information about N most starred Julia packages.
# By default, outputs git repositories, or packages names if [-n] is provided.
# Option [-p] specifies file with complete information about packages;
#   the files is downloaded for the first time and reloaded when [-r] provided.
# Option [-o] specifies output file name.
# If [-s] is provided, output is printed to console instead of a file.
# 
#**********************************************************************

#--------------------------------------------------
# Imports
#--------------------------------------------------

using ArgParse

include("lib/pkgs-generation.jl")

###################################################
# Constants and Parameters
###################################################

# Default file for complete packages info
const PKGS_INFO_FILE = "data/julia-pkgs-info.json"
# Default file for output packages list
const PKGS_LIST_FILE = "data/pkgs-list/top-pkgs-list.txt"

#--------------------------------------------------
# Command line arguments
#--------------------------------------------------

# → Dict (arguments)
function parse_command_line_args()
    argsStr = ArgParseSettings()
    @add_arg_table! argsStr begin
        "--name", "-n"
            help = "flag specifying if output should be packages' names instead of repositories"
            action = :store_true
        "--pkginfo", "-p"
            help = "JSON file with packages information"
            arg_type = String
            default = PKGS_INFO_FILE
        "--reload", "-r"
            help = "flag specifying if packages information must be reloaded"
            action = :store_true
        "--out", "-o"
            help = "output file with top packages list"
            arg_type = String
            default = PKGS_LIST_FILE
        "--show", "-s"
            help = "flag specifying if output should be printed to console instead of a file"
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

#--------------------------------------------------
# Main
#--------------------------------------------------

generatePackagesList(
    PARAMS["pkginfo"], PARAMS["reload"], PARAMS["name"],
    PARAMS["pkgnum"], PARAMS["out"], PARAMS["show"]
)
