#!/usr/bin/env julia

#**********************************************************************
# Script for cloning git repositories
#**********************************************************************
# Clones git repositories listed in the given file
#   to the given directory.
# Default values: repos.txt and . (current directory)
# 
# Usage:
#
#   $ julia clone.jl [-d <folder>] [-s <fname>]
#
# File <fname> should list git addresses one per line.
#**********************************************************************

using ArgParse
include("lib.jl")

# Parses arguments to [clone] routine (run with -h flag for more details)
function parse_clone_cmd()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--source", "-s"
            help = "the file from which to read the repository links"
            arg_type = String
            default = "repos.txt"
        "--destination", "-d"
            help = "the directory to which to clone the repositories"
            arg_type = String
            default = "./"
    end
    argDict = parse_args(s)
    (argDict["source"], argDict["destination"])
end

# Runs the clone command
(cloned, total) = gitclone(parse_clone_cmd()...)
infoMsg("Successfully cloned $(cloned)/$(total)")
