#!/usr/bin/env julia
using ArgParse
include("clone.jl")

# Parses the arguments to a clone command (run with -h flag for more details)
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
clone(parse_clone_cmd()...)
