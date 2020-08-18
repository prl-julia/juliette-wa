#!/bin/bash

PACKAGES_TO_ANALYZE=(
    "Genie"
    "Documenter"
    "Plots"
    "CxxWrap"
    "IJulia"
    "PyCall"
    "Weave"
    "BenchmarkTools"
    "Pluto"
    "Literate"
    "Revise"
    "Dagger"
    "Unitful"
    "ModelingToolkit"
    "Cxx"
    "Franklin"
)

for pkg in ${PACKAGES_TO_ANALYZE[@]}
do
    julia main.jl $pkg 
done
