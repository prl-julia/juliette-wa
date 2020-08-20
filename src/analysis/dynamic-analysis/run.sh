#!/bin/bash

PACKAGES_TO_ANALYZE=(
    "Symata.jl" "MonteCarloMeasurements.jl"
    "Genie.jl" "JuliaInterpreter.jl"
    "Documenter.jl" "Plots.jl" "Mads.jl"
    "Modia.jl" "Atom.jl" "FileIO.jl"
    "IJulia.jl" "SymEngine.jl" "Soss.jl"
    "PyCall.jl" "Weave.jl" "BenchmarkTools.jl"
    "Formatting.jl" "SymPy.jl" "Pluto.jl"
    "Rebugger.jl" "Yota.jl" "IRTools.jl"
    "Bukdu.jl" "Literate.jl" "Revise.jl"
    "SemanticModels.jl" "Dagger.jl" "Unitful.jl"
    "IntervalArithmetic.jl" "Reduce.jl"
    "ADCME.jl" "RCall.jl" "JLD.jl"
    "ModelingToolkit.jl" "Cxx.jl" "Gtk.jl"
    "Franklin.jl" "DataStreams.jl" "ProtoBuf.jl"
    "SQLite.jl" "DiffEqOperators.jl"
    "FixedEffectModels.jl" "ResumableFunctions.jl"
    "Omega.jl" "TimeseriesPrediction.jl"
    "Juno.jl" "NeuralNetDiffEq.jl" "NeuralPDE.jl"
    "PowerSystems.jl"
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
