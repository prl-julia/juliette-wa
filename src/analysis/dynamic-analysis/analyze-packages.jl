PKGS_TO_ANALYZE =
    [
        # "Printf"
        # "Revise",
        # # Top packages
        # "Flux",
        "IJulia"
        # "Gadfly",
        # # "Gen", # Has issue in Pkg.test(...)
        # # "DifferentialEquations", # Has issue in Pkg.test(...)
        # "JuMP",
        # # "Knet", # Has issue in Pkg.test(...)
        # # "Plots", # Has issue in Pkg.test(...)
        # "Genie",
        # # "Turing", # Has issue in Pkg.test(...)
        # # "PyCall", # Has issue in Pkg.test(...)
        # "DataFrames",
        # "Zygote",
        # "TensorFlow",
        # "MLJ",
        # "UnicodePlots",
        # "PackageCompiler",
        # "Makie",
        # "Cxx"
        # "Documenter"
    ]

function analyzePkg(pkg :: String)
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkg
    Pkg.add(pkg)
    Pkg.test(pkg)
end

# Override test method to include the overriden eval and invokeLatest
include("test-override.jl")
using Pkg
ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
map(analyzePkg, PKGS_TO_ANALYZE)
