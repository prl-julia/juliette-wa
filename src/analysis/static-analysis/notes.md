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



## Processed Packages



**Note.** There is a difference between

```julia
julia> function foo(s)
         eval(:(bar() = 0))
         eval(Symbol(s))()
       end
foo (generic function with 1 method)

julia> foo("bar")
ERROR: MethodError: no method matching bar()
The applicable method may be too new: running in world age 27232, while current world is 27233.
```

and

```julia
julia> function zoo(s)
         eval(:(zar() = 0))
         eval(Symbol(s)())
       end
zoo (generic function with 1 method)

julia> zoo("zar")
ERROR: MethodError: objects of type Symbol are not callable
```

* `Genie.jl` other (`&&`), call (`Revise.revise()`x2 and resource generator),
   parse (include, export, and multiple function definitions)
* `Documenter.jl` call (type and probably function call), expr (`=`)
   symbol (most likely function)
* `Plots.jl` call (function call)
* `CxxWrap.jl` symbol (struct)
* `IJulia.jl` call (function calls, something related to help mode)
* `PyCall.jl` expr (const and function definitions)
* `Weave.jl` expr (tuple value)
* `BenchmarkTools.jl` macrocall (function definition), parse (type),
  call (function call)
* `Pluto.jl` symbol (import)
* `Revise.jl` symbol (function definition)
* `Dagger.jl` symbol (type)
* `CuArrays.jl`: `/src/forwarddiff.jl` call and macrocall (function definition)
* `Knet.jl` macrocall (`@primitive`)
* `Unitful.jl` expr (import/export), call (function call and environment)
* `TensorFlow.jl` macrocall (probably function call, `@op`)
* `ForwardDiff.jl` call (function call, which defines a function)
* `ModelingToolkit.jl` call (function call)
* `Oceananigans.jl` expr (function call), call (function definition),
   symbol (function call, function)
* `Cxx.jl` symbol (function definition), call (function call)
* `DSGE.jl` symbol (function), expr (`=`)
* `Franklin.jl` parse (module), call (function call), symbol (function call, `=`)
* `ScikitLearn.jl` macrocall (`@reexportsk` exports names)
* `Distributions.jl` symbol (function definition)
* `Distributions.jl` expr (function definition)
* `Latexify.jl` symbol (function call)
* `Cassette.jl` call (overdub function call)
* `Debugger.jl` symbol (function, `let`)
* `Gen.jl` symbol (function definition):
  ```julia
  for function_defn in generated_functions
      Core.eval(__module__, function_defn)
  end
  ```
* `LightGraphs.jl` symbol (type)
* `TextAnalysis.jl` symbol (function)
* `AutoMLPipeline.jl` symbol (tuple to vector conversion)
* `Query.jl` symbol (types or tuples)