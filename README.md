# Juliette: World Age

Formalization of **world age**, a [Julia language](https://julialang.org/)
mechanism for efficient implementation of `eval`.

## World Age

World age is a language mechanism that prevents
new methods defined in `eval` to be called from an already running function.
For example, consider the following program:

```julia
f(x) = 1

# g(x) calls f(x) once, then
# redefines f(x) in eval, and calls f(x) again
function g(x)
  v1 = f(x)
  v2 = (eval(:(f(x) = 0)); f(x))
  v1 * v2
end

# at this point, there are two methods:
# f(x) = 1 and g(x) = ...
g(5)     # 1

# at this point, methods are:
# g(x) = ... and f(x) = 0
g(666)   # 0
```

Without the world age feature, call `g(5)` would return 0: 
the first call to `f` returns 1, the second returns 0
(because `f` was redefined in `eval`), and 1*0 is 0.

However, in Julia, `g(5)` will actually return 1
because the redefinition `f(x) = 0` from `eval` is not visible
while `g(5)` is running.
Julia's run-time sort of takes the snapshot of method definitions
before the call `g(5)`, and uses the snapshot to resolve nested method calls.  
But once `g(5)` is done, the new definition of `f` becomes visible,
so the next call `g(666)` will return 0.

## Repository Organization

* [`src`](src) folder with the implementation of the calculus
  and related utilities:

  * [`redex`](src/redex) Redex prototype of the calculus;

  * [`jl-transpiler`](src/jl-transpiler) transpiler from a subset of Julia
    to the surface language of the Redex model;

* [`litmus`](litmus) folder with summaries of litmus tests
  (files in this folder are not supposed to be executed):

  - [`world-age.jl`](litmus/world-age.jl) short Julia programs demonstrating
    the interaction of `eval` and world age.

* [`tests`](tests) folder with runnable tests related to
  the world age semantics:

  - [`litmus-wa`](tests/litmus-wa) world-age litmus tests written in Julia,
    transpiled and checked with Redex;

## Dependencies

* [Julia](https://julialang.org/) with the following packages:
  - `ArgParse`
  - `JSON`

  We used Julia [1.4.2](https://julialang.org/downloads/oldreleases/#v142_may_23_2020),
  but the version should not make a big difference.

* [Racket](https://racket-lang.org/)
  with [Redex](https://redex.racket-lang.org/)

### Installing Julia dependencies and running Julia

Since we are using pretty basic Julia packages, we don't expect any problems
with their versions. Thus, most likely, Option 1 will work just fine,
but if not, try Option 2.

#### Option 1 (easiest)

Run this from the main directory (`jl-wa`):

```
jl-wa$ julia install-julia-deps.jl
```

After that, run Julia code with `julia` command.

#### Option 2

To use the same versions of the packages that we did,
run this from the main directory (`jl-wa`):

```
jl-wa$ julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
```

After that, to run Julia code anywhere in `jl-wa`,
use `julia --project=@.` command instead of `julia`.

## Notes on running Julia

Small scripts (for IO) are much faster if run with:

```
$ julia -O 0 --compile=min <script.jl>
```
