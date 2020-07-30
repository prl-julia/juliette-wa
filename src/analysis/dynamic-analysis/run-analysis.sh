#!/bin/bash

# NOTE: at the moment this form of running the tests in parallel
# causes environment issues
PACKAGES_TO_ANALYZE=("Symata", "DataFrames")

for pkg in ${PACKAGES_TO_ANALYZE[@]}
do
    ~/AppData/Local/Programs/Julia/Julia-1.5.0/bin/julia.exe main.jl $pkg &
done

# Packages with issues when run:
# - "Documenter"
# - "Genie"
# - "Plots"
# - "Gen"
# - "DifferentialEquations"
# - "Knet"
# - "Turing"
# - "PyCall"
# - "DataFrames"
# - "Zygote"
# - "TensorFlow"
# - "MLJ"
# - "UnicodePlots"
# - "PackageCompiler"
# - "Makie"
# - "Cxx"
# - "CUDA"
