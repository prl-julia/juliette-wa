# Lightweight Static Analysis of `eval` Usage

Grep a file, and if there is `eval`/`invokelatest`, output info.

## Usage

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

`Decentralized-Internet` isn't even Julia package.

### Load Path

To set a custom package directory, use `JULIA_LOAD_PATH` environment variable
(old Julia versions used `JULIA_PKG_DIR`):

```julia
JULIA_LOAD_PATH=... julia
```

## Dependencies

Julia packages (`import Pkg; Pkg.add("<pkgname>")`):

* `ArgParse`
* `JSON`
