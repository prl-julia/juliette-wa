# Utilities

## Executables

### Cloning git repositories

Use `clone.jl` or `clone.sh` to clone git repositories
listed in the given text file (one git address per line)
to the given folder.  
Default values: `repos.txt` and `.` (current directory).

```
$ [julia] clone.jl [-d <folder>] [-s <fname>]
```

or 

```
$ clone.sh [<folder>] [<fname>]
```

## Dependencies

Julia packages (`import Pkg; Pkg.add("<pkgname>")`):

* ArgParse

## Source Code

* [`lib.jl`](lib.jl) util functions

* [`clone.jl`](clone.jl) julia-script executable
* [`clone.sh`](clone.sh) bash-script executable
