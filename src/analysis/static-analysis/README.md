# Lightweight Static Analysis of `eval` and `invokelatest` Usage

Uses simple regular expressions to count the occurrences of
`eval(`, `@eval `, and `invokelatest(` in Julia files.  
*Note.* The analysis prunes incorrect calls such as `myeval(`
but does count calls in comments.

## Usage

### Do-all script

`$julia run-all.jl 10`

To download and analyze 10 most starred Julia packages.

This will create the following files and folders in `static-analysis`:

* `data` folder with the analysis information
* `data/julia-pkgs-info.json` JSON file with information about registered
  Julia packages (repository address, number of stars on GitHub)
* `data/pkgs/10` folder with sources of the 10 most starred Julia packages
* `data/reports/10.txt` text file with the analysis report

### More details

```julia
# generate list of 100 most starred packages
$ julia gen-pkgs-list.jl 100 -o data/pkgs-list/top-100.txt

# clone those packages
$ julia ../../utils/clone.jl -s data/pkgs-list/top-100.txt -d data/pkgs/100

# run static analysis on the downloaded packages
$ julia run-analysis.jl data/pkgs/100 > data/reports/100.txt
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
