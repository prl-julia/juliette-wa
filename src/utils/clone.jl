#!/usr/bin/env julia

#**********************************************************************
# Script for cloning git repositories
#**********************************************************************
# Clones git repositories listed in the given file
#   to the given directory.
# Default values: repos.txt and . (current directory)
#
# If Julia is launched in parallel mode, clones in parallel.
#
# Usage:
#
#   $ julia [-p N] clone.jl [-s <file>] [-d <folder>] [-r]
#
# File <file> should list git addresses one per line.
#**********************************************************************

#--------------------------------------------------
# Imports
#--------------------------------------------------

using ArgParse
include("lib.jl")

#--------------------------------------------------
# Command Line Arguments
#--------------------------------------------------

# Parses arguments to [clone] routine (run with -h flag for more details)
function parse_clone_cmd()
    s = ArgParseSettings()
    s.description = """
    Clones git repositories listed in [SRC] to [DEST].
    If Julia is launched in parallel mode (-p N), clones in parallel.
    """
    @add_arg_table! s begin
        "--src", "-s"
            help = "file with git-repository links"
            arg_type = String
            default = "repos.txt"
        "--dest", "-d"
            help = "directory to clone repositories"
            arg_type = String
            default = "./"
        "--overwrite", "-r"
            help = "if set, overwrites existing directories"
            action = :store_true
    end
    argDict = parse_args(s)
    (argDict["src"], argDict["dest"], argDict["overwrite"])
end

#--------------------------------------------------
# Main
#--------------------------------------------------

# Runs the clone command
(cloned, total) = gitcloneAll(parse_clone_cmd()...)
@info "Successfully processed $(cloned)/$(total)"
