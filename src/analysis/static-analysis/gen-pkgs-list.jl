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
using JSON

include("../../utils/lib.jl")

###################################################
# Constants and Parameters
###################################################

# API for getting JSON with info about Julia packages
# from official Julia Computing web page
const PKGS_INFO_URL = "https://juliahub.com/app/packages/info"
# Expected format of JSON data: {packages: [...]}
const PKGS_KEY = "packages"

# Default file for complete packages info
const PKGS_INFO_FILE = "data/julia-pkgs-info.json"
# Default file for output packages list
const PKGS_LIST_FILE = "data/pkgs-list/top-pkgs-list.txt"

# Repositories of bad packages that might be in the list
const BAD_PKGS = [
    "https://github.com/JuliaLang/julia.git", # Julia repo itself
    "https://github.com/Lonero-Team/Decentralized-Internet.git", # Decentralized-Internet
]

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
pkgsInfoFileName = PARAMS["pkginfo"]
pkgsNum = PARAMS["pkgnum"]
pkgsListFileName = PARAMS["out"]

###################################################
# Retrieve complete packages information
###################################################

# Dowload packages info if needed
if !isfile(pkgsInfoFileName) || PARAMS["reload"]
    infoMsg("Downloading packages info...")
    download(PKGS_INFO_URL, pkgsInfoFileName)
    infoMsg("Downloading completed")
end

# Read JSON info about packages
infoMsg("Loading packages info...")
pkgsInfo = 
    try 
        JSON.parse(read(pkgsInfoFileName, String)) 
    catch e
        exitErrWithMsg(string(e))
    end
# Check that JSON has [packages] field
if !haskey(pkgsInfo, PKGS_KEY)
    exitErrWithMsg("Wrong JSON: packages field is expected")
end
# Retrieve list of packages information
pkgsList = pkgsInfo[PKGS_KEY]
infoMsg("Loading completed")

###################################################
# Process list of packages
###################################################

#--------------------------------------------------
# Aux functions
#--------------------------------------------------

# Dict (pkg info), String → Any
# Retrieves value of [key] from [pkgInfo] metadata or returns [default]
function getMetaDataValue(pkgInfo :: Dict, key :: String, default :: Any)
    if haskey(pkgInfo, "metadata") 
        metaData = pkgInfo["metadata"]
        haskey(metaData, key) ? metaData[key] : default
    else
        default
    end
end

# Dict (pkg info) → Int
# Returns the number of stars if available
getStarCount(pkgInfo :: Dict) = getMetaDataValue(pkgInfo, "starcount", 0)

# Dict (pkg info) → String
# Returns the repository address if available
getRepo(pkgInfo :: Dict) = getMetaDataValue(pkgInfo, "repo", "<NA-repo>")

# Dict (pkg info) → String
# Returns package name if available
getName(pkgInfo :: Dict) = haskey(pkgInfo, "name") ? pkgInfo["name"] : "<NA-name>"

#--------------------------------------------------
# Processing
#--------------------------------------------------

# Remove Julia itself and other blacklisted packages
infoMsg("Cleaning packages...")
pkgsList = filter(pkg -> !in(getRepo(pkg), BAD_PKGS), pkgsList)
infoMsg("Cleaning completed")

# Check and possibly fix the number of packages
if pkgsNum < 0
    pkgsNum = 1
    warnMsg("requested number of packages cannot be negative -- set to $(pkgsNum)")
elseif pkgsNum > length(pkgsList)
    pkgsNum = length(pkgsList)
    warnMsg("requested number of packages is too big -- set to $(pkgsNum)")
end

# Sort packages from most to least starred
infoMsg("Sorting packages...")
pkgsList = sort(pkgsList, by=getStarCount, rev=true)
infoMsg("Sorting completed")

###################################################
# Output required information
###################################################

infoMsg("Ready to output the result")

# Required information depends on the parameters
getInfo = PARAMS["name"] ? getName : getRepo

# Get required information about the top pkgsNum packages
# Note. We use unique because the package list sometimes has duplicates,
#       e.g. https://github.com/JuliaPlots/StatsPlots.jl.git
topPkgsInfoList = unique(map(getInfo, pkgsList))[1:pkgsNum]

# Prepare output
output = join(topPkgsInfoList, "\n")

# Output
if PARAMS["show"]
    println(output)
else 
    #=
    if isfile(pkgsListFileName)
        println("File $(pkgsListFileName) already exists. Do you want to overwrite it? (y/N)")
        readline() == "y" || exit()
    end
    =#
    open(pkgsListFileName, "w") do io
        write(io, output)
    end
    infoMsg("Output completed")
end
