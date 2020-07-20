PKGS_TO_ANALYZE =
    [
        # "Printf",
        # "Revise",
        # # Top packages
        # "Flux",
        # "IJulia",
        # "Gadfly",
        # # "Gen", # Has issue in Pkg.test(...)
        # # "DifferentialEquations", # Has issue in Pkg.test(...)
        # "JuMP",
        # # "Knet", # Has issue in Pkg.test(...)
        # # "Plots", # Has issue in Pkg.test(...)
        # "Genie",
        # # "Turing", # Has issue in Pkg.test(...)
        # # "PyCall", # Has issue in Pkg.test(...)
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
const OUTPUT_FILE = "$(pwd())/output.json"
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
