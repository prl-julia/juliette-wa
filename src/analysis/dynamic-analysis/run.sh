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
    julia -e "using Pkg; Pkg.add(\"$pkg\")"
    pkgVersion=$(julia -e "using Pkg; println(Pkg.installed()[\"$pkg\"])" | tail -n 1)
    outputDir=package-data/$pkg-$pkgVersion
    stdioOutputDir=$outputDir/stdio
    mkdir -p $stdioOutputDir
    julia analyze-package.jl $pkg 1>$stdioOutputDir/analysis-stdout.txt 2>$stdioOutputDir/analysis-stderr.txt
    julia test-package.jl $pkg 1>$stdioOutputDir/test-stdout.txt 2>$stdioOutputDir/test-stderr.txt
done
