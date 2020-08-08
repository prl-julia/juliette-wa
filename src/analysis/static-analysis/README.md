# Lightweight Static Analysis of `eval` and `invokelatest` Usage

This part of the project allows us to statically analyze the usage of
`eval` and `invokelatest` in all registered Julia packages.

For every package, the analysis (1) counts textual occurrences of
`eval` and `invokelatest` in source code, and (2) for `eval`, it also gathers
statistics about ASTs passed as arguments.
More concretely, we do the following:

1. First, we use simple regular expressions to count occurrences of
   `eval(`, `@eval `, and `invokelatest(` in Julia files from
   `<package name>/src/`.  
  *Note.* Regular expressions prevent incorrect calls such as `myeval(`
  from counting, but do not prune commented calls or definitions
  of custom `eval` functions.

2. Second, if a file contains calls to `eval`, we parse it
   with the Julia parser, ignore comments and custom `eval` definitions
   (textually, `eval(x` looks like a function call),
   and record what kinds of ASTs are passed to `eval`.  
   *Note.* If a custom `eval` function is defined, calls to such function
   will produce false positives. However, we record the fact that there is
   an `eval` definition in a package, so it's easy to see which packages might
   have false positives.

   Because we are interested in the usage of `eval` that might be relevant
   for world age, we distinguish top-level calls to `eval`
   and the ones inside functions (macro definitions are treated as top-level).

## Usage

### Do-all script

`$julia [-p N] run-all.jl 10`

To download and analyze 10 most starred Julia packages.

This will create the following files and folders in `static-analysis`:

* `data` folder with the analysis information;
* `data/julia-pkgs-info.json` JSON file with information about registered;
  Julia packages (repository address, number of stars on GitHub);
* `data/pkgs-list/top-10.txt` text file with the list of top 10 packages;
* `data/pkgs/10` folder with sources of the 10 most starred Julia packages;
* `data/reports/10.txt` text file with the analysis report.

The script has a bunch of parameters, for example:

* to re-download JSON file, add `-r`;
* to skip cloning/checking a folder with packages, add `-n`.

Cloning can be done in parallel, so we recommend running `julia` with `-p N`.

### More details

All scripts below have help messages (run them with `-h` to see help).

```julia
# generate list of 100 most starred packages
$ julia gen-pkgs-list.jl 100 -o data/pkgs-list/top-100.txt

# clone those packages
$ julia ../../utils/clone.jl -s data/pkgs-list/top-100.txt -d data/pkgs/100

# run static analysis on the downloaded packages
$ julia run-analysis.jl data/pkgs/100 -o data/reports/100.txt
```

## Executable scripts

### Generating list of most starred packages

```
$ [julia] gen-pkgs-list.jl 1000
```

**Note.** For some reason, `StatsPlots.jl` appears on
[JuliaHub](https://juliahub.com/ui/Packages) twice.

## Notes

### Julia Packages

List of Julia packages can be obtained from
[here](https://juliahub.com/app/packages/info), e.g.:

```
wget https://juliahub.com/app/packages/info
```

The following packages don't have `src` folder:

```
# failed folders (without src): 2
Decentralized-Internet
MXNet.jl
```

`Decentralized-Internet` isn't even a Julia package.

### Load Path

To set a custom package directory, use `JULIA_DEPOT_PATH` environment variable
(old Julia versions used `JULIA_PKG_DIR`):

```julia
JULIA_DEPOT_PATH=... julia
```

## Dependencies

Julia packages (`import Pkg; Pkg.add("<pkgname>")`):

* `ArgParse`
* `JSON`
