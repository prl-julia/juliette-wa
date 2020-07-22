#!/bin/bash

PACKAGES_TO_ANALYZE=("IJulia")

for pkg in ${PACKAGES_TO_ANALYZE[@]}
do
    ~/AppData/Local/Programs/Julia/Julia-1.5.0/bin/julia.exe main.jl $pkg &
done

# Packages with issues when run:
# - "Documenter"
# - "Gen"
# - "DifferentialEquations"
# - "Knet"
# - "Plots"
# - "Turing"
# - "PyCall"
# - "DataFrames"
# - "Genie"
# - "Zygote"
# - "TensorFlow"
# - "MLJ"
# - "UnicodePlots"
# - "PackageCompiler"
# - "Makie"
# - "Cxx"
