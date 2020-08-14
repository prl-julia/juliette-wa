# Dynamic Analysis

A dynamic analysis tool that analyzes the use of eval and invokeLatest in the Julia language

## File Overview
* `package-data` - directory containing all the dynamic analysis results
* `ast-parse-helpers.jl` - contains parsing julia-ast related functions
* `func-override.jl` - overrides the eval and invokelatest methods to track usage
* `main.jl` - the entry point to run dynamic analysis on a package
* `overrideInfo-to-json.jl` - converts the domain object to a json and writes it to a file
* `test-override.jl` - overrides the package tester function to allow for dynamic analysis to be run

## Analyze Package

1. To analyze a package run the following command `julia main.jl <PACKAGE_NAME>` (NOTE: your julia version must be >= `1.5.0`).

3. The analyzed data of each package will be written to a `package-data/<package_name>` directory. The directory will contain 3 files: `external-lib.json` (runtime data collected on external libraries the package calls), `internal-lib.json` (runtime data collected on julia internal libraries the package calls), and `source.json` (runtime data collected on source code in the package itself)
