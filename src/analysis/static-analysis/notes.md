## Packages

1. [`Symata.jl`](https://github.com/jlapeyre/Symata.jl) --
   for doing symbolic math.

   * `eval` is used a lot for evaluating symbolic expressions.
   * `eval` is also used for integrating with IJulia and Jupyter
      (`load_ijulia_handlers`).
   * `invokelatest` seems to be primarily used for IJulia/Jupyter hooks as well.

1. `TensorOperations.jl` -- a single call to eval with `const`.

1. `GasModels.jl` -- 3 calls to `eval` with export/import.