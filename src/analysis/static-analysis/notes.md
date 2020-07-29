## Packages

1. [`Symata.jl`](https://github.com/jlapeyre/Symata.jl) --
   for doing symbolic math.

   * `eval` is used a lot for evaluating symbolic expressions.
   * `eval` is also used for integrating with IJulia and Jupyter
      (`load_ijulia_handlers`).
   * `invokelatest` seems to be primarily used for IJulia/Jupyter hooks as well.
   * `@eval` in `sortorderless.jl` creates a bunch of functions
      at the top-level.

   Nice example of function generation:

   ```julia
   symata> f = Compile(x^2 + y^2)
   symata> f(3,4)
         25

   @doap function Compile(a::Mxpr{:List}, body)
      aux = MtoECompile()
      jexpr = Expr(:function, Expr(:tuple, [mxpr_to_expr(x, aux) for x in margs(a)]...) , mxpr_to_expr(body, aux))
      Core.eval(Main, jexpr)
   end
   ```

1. `Cuda.jl` -- uses `@eval` to define `@inline` functions at the top-level
   (e.g. in `atomics.jl`), and also `struct` with `convert` function for it.
   Also some variables.  
   `invokelatest` is used to call some hooks (this was added
   [recently](https://github.com/JuliaGPU/CUDA.jl/commit/c0ae20c0dc78d9eba4ca3f90a8186d690d023006))


1. `Genie.jl` -- `eval` for const, include, using; more interestingly,
   `Core.eval(Main, :(Revise.revise()))`, something for new resource,
   loading environment.
   Also (in `Renderer.jl`):

   ```julia
   function WebRenderable(f::Function, args...)
      fr::String = try
         f()::String
      catch
         Base.invokelatest(f)::String
      end

      WebRenderable(fr, args...)
   end
   ```

   `renderers/Html.jl` uses `eval` to generate a bunch of functions for HTML
   tags.

   And `invokelatest` is used to run hooks:

   ```julia
   function run_hook(controller::Module, hook_type::Symbol) :: Bool
      isdefined(controller, hook_type) || return false

      getfield(controller, hook_type) |> Base.invokelatest

      true
   end
   ```

   and with the pattern above, Router and Commands do something:
   
   ```julia
   result = try
      (r.action)() |> to_response
   catch
      Base.invokelatest(r.action) |> to_response
   end
   ```

1. `TensorOperations.jl` -- a single call to eval with `const`.

1. `GasModels.jl` -- 3 calls to `eval` with export/import.