#!/bin/bash

PACKAGES_TO_ANALYZE=(
    "Symata" "MonteCarloMeasurements"
    "Genie" "JuliaInterpreter"
    "Documenter" "Mads"
    "Modia" "Atom" "FileIO"
    "IJulia" "SymEngine" "Soss"
    "PyCall" "Weave" "BenchmarkTools"
    "Formatting"
    "SymPy" "Pluto"
    "Rebugger" "Yota" "IRTools"
    "Bukdu" "Literate"
    "SemanticModels" "Dagger" "Unitful"
    "IntervalArithmetic" "Reduce"
    "ADCME" "RCall" "JLD"
    "ModelingToolkit" "Cxx" "Gtk"
    "Franklin" "DataStreams" "ProtoBuf"
    "SQLite" "DiffEqOperators"
    "FixedEffectModels" "ResumableFunctions"
    "Omega" "TimeseriesPrediction"
    "Juno" "NeuralNetDiffEq" "NeuralPDE"
    "PowerSystems"
    "Revise" "Plots"
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
