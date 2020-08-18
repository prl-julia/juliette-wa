# Dynamic Analysis

A dynamic analysis tool that analyzes the use of `eval` and `invokeLatest`
in the Julia language.

## File Overview

* [`package-data/`](package-data)
  directory with all the dynamic analysis results

* [`tests/`](package-data)
  directory containing the julia test files

* [`main.jl`](main.jl)
  the entry point to run dynamic analysis on a package

* [`function-override.jl`](function-override.jl)
  overrides the `eval` and `invokelatest` methods to track usage

* [`test-override.jl`](test-override.jl)
  overrides the package tester function to allow for dynamic analysis to be run

* [`overrideInfo-to-json.jl`](overrideInfo-to-json.jl)
  converts the domain object to a json and writes it to a file

* [`ast-parse-helpers.jl`](ast-parse-helpers.jl)
  contains parsing julia-ast related functions

## Analyze Package

To analyze a package run the following command:

```
$ julia main.jl <PACKAGE_NAME>
```

(NOTE: your Julia version must be >= `1.4.2`).

The analyzed data of each package will be written to
a `package-data/<package_name>` directory.
The directory will contain 3 files:

* `external-lib.json`
  (runtime data collected on external libraries the package calls),

* `internal-lib.json`
  (runtime data collected on julia internal libraries the package calls),

* `source.json`
  (runtime data collected on source code in the package itself).
