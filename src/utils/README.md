# Utilities

## Executable scripts

### Cloning git repositories

Use `clone.jl` or `clone.sh` to clone git repositories
listed in the given text file (one git address per line)
to the given folder.  
Default values: `repos.txt` and `.` (current directory).  
Julia script overwrites existing directories if `-r` is provided.

```
$ [julia] clone.jl [-d <folder>] [-s <file>] [-r]
```

or 

```
$ clone.sh [<folder>] [<file>]
```

#### Notes on cloning with the Julia script

We recommend running the script as:

```
julia -p 4 -O 0 --compile=min clone.jl -s <file> -d <folder>
```

Parameter `-p 4` enables parallel cloning, and `-O 0 --compile=min`
reduces the start-up time of the script.

* The script supports parallel cloning. Run the script with `-p 4`
  to clone repositories using 4 workers.

  ```
  $ julia -p 4 clone.jl [-d <folder>] [-s <file>]
  ```

* To reduce start-up time of the script, use `-O 0` and `--compile=min`
  arguments:

  ```
  $ julia -O 0 --compile=min clone.jl [-d <folder>] [-s <file>]
  ```

## Dependencies

Julia packages (`import Pkg; Pkg.add("<pkgname>")`):

* `ArgParse`

## Source Code

* [`lib.jl`](lib.jl) implementation of utilities functions

* [`clone.jl`](clone.jl) julia-script executable
* [`clone.sh`](clone.sh) bash-script executable
