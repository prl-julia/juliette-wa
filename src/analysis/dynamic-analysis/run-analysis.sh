#!/bin/bash

PACKAGES_TO_ANALYZE=("JuMP" "Genie" "Zygote" "TensorFlow" "MLJ" "UnicodePlots" "PackageCompiler" "Makie" "Cxx")

for pkg in ${PACKAGES_TO_ANALYZE[@]}
do
    ~/AppData/Local/Programs/Julia/Julia-1.5.0/bin/julia.exe analyze-packages.jl $pkg &
done

# Packages with issue in Pkg.test(...):
# - "Documenter"
# - "Gen"
# - "DifferentialEquations"
# - "Knet"
# - "Plots"
# - "Turing"
# - "PyCall"
# - "DataFrames"
