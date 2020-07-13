# Lightweight Static Analysis of `eval` Usage

Grep a file, and if there is `eval`, output info.

## Notes

To set a custom package directory, use `JULIA_LOAD_PATH` environment variable
(old Julia versions used `JULIA_PKG_DIR`):

```julia
JULIA_LOAD_PATH=... julia
```

List of Julia packages can be obtained from
[here](https://juliahub.com/app/packages/info), e.g.:

```
wget https://juliahub.com/app/packages/info
```

To get a text file with top packages' addresses, run the following,
assuming that JSON above is saved to `data/julia-pkgs--jul-12-2020.json`:

```
julia gen-pkgs-list.jl data/julia-pkgs--jul-12-2020.json > data/top-packages.txt
```

To clone packages:

```
./../utils/clone.sh data/pkgs data/top-packages.txt
```

To run trivial analysis:

```
julia lib.jl data/pkgs/

or

julia lib.jl data/pkgs/ > data/report.txt
```