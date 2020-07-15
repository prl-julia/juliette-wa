PKGS_TO_ANALYZE =
    [
        "Printf",
        "Revise",
        # Top packages
        "Flux",
        "IJulia",
        "Gadfly",
        "Gen",
        "DifferentialEquations",
        "JuMP",
        "Knet",
        "Plots",
        "Genie",
        "Turing",
        "PyCall",
        "DataFrames",
        "Zygote",
        "TensorFlow",
        "MLJ",
        "UnicodePlots",
        "PackageCompiler",
        "Makie",
        "Cxx"
    ]

# Truncate file in the case it already exists
const OUTPUT_FILE = "$(pwd())/output.json"
fd = open(OUTPUT_FILE; truncate=true)
close(fd)
# Override test method to include the overriden eval and invokeLatest
include("test-override.jl")
using Pkg
analyzePkg(pkg :: String) = (Pkg.add(pkg); Pkg.test(pkg))
map(analyzePkg, PKGS_TO_ANALYZE)
