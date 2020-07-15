PKGS_TO_ANALYZE =
    [
        # "Printf",
        # "Revise",
        # # Top packages
        # "Flux",
        # "IJulia",
        # "Gadfly",
        "Gen",
        "DifferentialEquations",
        "JuMP",
        # "Knet", # Has issue in Pkg.test(...)
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

function analyzePkg(pkg :: String)
    Pkg.add(pkg)
    Pkg.test(pkg)
    fd = open(OUTPUT_FILE, "a")
    write(fd, ",\n")
    close(fd)
end

# Truncate file in the case it already exists
# const OUTPUT_FILE = "$(pwd())/output.json"
# fd = open(OUTPUT_FILE; truncate=true)
# write(fd, "[\n")
# close(fd)
# Override test method to include the overriden eval and invokeLatest
include("test-override.jl")
using Pkg
map(analyzePkg, PKGS_TO_ANALYZE)
fd = open(OUTPUT_FILE, "a")
write(fd, "]\n")
close(fd)
