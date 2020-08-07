## Notes on Eval Usage

Sometimes `eval` evaluates a symbol to produce a function, but a function call
itself is not inside `eval`. This is often some kind of package-managed
function selection. E.g. `PkgPage.jl`:

```julia
function lx_begin(com, _)
   ...
   starter = Symbol("_begin_$env")
   return eval(starter)(; kwargs...)
end
```

Sometimes `eval` does not make any sense, e.g. in `Alpine.jl`:

```julia
   if isa(m.disc_var_pick, Function)
      eval(m.disc_var_pick)(m)
```

In some cases, `eval(var)` corresponds to a complex function definition or
some other complex expression. But it seems that in cases where a package
has several top-level things and just a single `eval(var)` in a function,
such an `eval` corresponds to this "picking a function by name" thingy.

## Packages

1. [`Symata.jl`](https://github.com/jlapeyre/Symata.jl) --
   for doing symbolic math.

   * The majority of `eval` usages define functions, a lot at the top level
     (38 at the top, 31 in functions).
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

1. `Azure.jl` evals parsed types, nothing interesting.

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

1. `MLStyle.jl` functional programming style macros (`@data` for ADT,
   `@match` for pattern-matching); `eval` is used for this meta-programming
   but not function definitions or calls.

1. `SQLite.jl`generates scalar functions using `scalarfunc`, which relies
   on `eval`. And this is interesting: `newidentity() = @eval x->x`.
   It does not call functions with `eval`, however, but rather makes them
   into C functions.

1. `PkgPage.jl` (`/src/coms/begin-end.jl`) `eval` is used to evaluate function
   name but not function call:
   
   ```julia
   closer = Symbol("_end_$env")
   return eval(closer)()
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

* `Symata.jl` include (runtime include of a file),
  macro `@mkapprule` defines functions

* `Azure.jl` call (`Base.Meta.parse` that parses type)

* `MonteCarloMeasurements.jl` variable (function name)

* `Genie.jl` other (`&&`), call (`Revise.revise()`x2 and resource generator),
   parse (include, export, and multiple function definitions),
   include (includes some "task" file and includes in `loadapp`) + using

* `JuliaInterpreter.jl` variable (using/export, type, various defs)

* `Documenter.jl` call (type and probably function call), expr (`=`)
   variable (most likely function)

* `Plots.jl` call (function call)

* `CxxWrap.jl` variable (struct/type), call (builds function)

* `Mads.jl` variable (some expression with vars, module, text of Julia file
   with function definitions), parse (function name)

* `Modia.jl` variable (various expressions) (also has `invokelatest`)

* `Atom.jl` something interpreting-related, variable (any expression)

* `IJulia.jl` call (function calls, something related to help mode)

* `PyCall.jl` expr (top-level const and function definitions)

* `Weave.jl` expr (tuple value)

* `BenchmarkTools.jl` macrocall (function definition), parse (type),
  call (function call), parse (function name)

* `Pluto.jl` variable (import)

* `Revise.jl` variable (function definition)
* `Dagger.jl` symbol (type)
* `CuArrays.jl`: `/src/forwarddiff.jl` call and macrocall (function definition)

* `Grassmann.jl` some algebra package, generates various functions,
  but the generation function itself is called at the top-level;
  thus, does not seem to have any world age.

* `Knet.jl` top-level macro `@primitive`

* `Unitful.jl` expr (import/export), call (function call and environment)

* `Alpine.jl` variable (function name), completely useless `eval`.

* `TensorFlow.jl` variable (function name),
  macrocall (top-level, probably function call, `@op`)

* `ForwardDiff.jl` call (function call, which defines a function)
* `ModelingToolkit.jl` call (function call)
* `Oceananigans.jl` expr (function call), call (function definition),
   symbol (function call, function)

* `Espresso.jl` variable (possibly any expressions or limited), seems to define
  functions.

* `Cxx.jl` variable (top-level function definition), call (function call LLVM)

* `DSGE.jl` symbol (function), expr (`=`)

* `FlatBuffers.jl` variable (most likely not function or call, some expression)

* `ADCME.jl` macrocall (`@r_str $name`), call (`call`, unrelated to world age)

* `Hecke.jl` macrocall (`eval(Main, :(@spawnat $d eval(Main, :(include`),
  variable (caching of data + checking the type of function (not call))

* `Pandas.jl` macrocall `@pyattr` defines functions in `pyattr_set`,
  but `pyattr_set` itself is always called at the top-level.

* `Gtk.jl` variable (function definitions, library), call (deserialization)
  
* `Franklin.jl` parse (module), call (function call),
  variable (function, function call, and arbitrary expression)

* `RandomMatrices.jl` variable (matrix multiplication expression)
* `Compose.jl` variable (name of some attribute)
* `BinDeps.jl` variable (top-level with include), for (`@show` in a loop)
* `ParallelDataTransfer.jl` variable (possibly a function)

* `ProtoBuf.jl` variable (function name, not call), and one call to parse.
  Why use function names instead of function pointers directly?

* `ScikitLearn.jl` macrocall (`@reexportsk` exports names)
* `Distributions.jl` symbol (function definition)
* `Distributions.jl` expr (function definition)

* `SQLite.jl` variable (function definition), call (function generation
  via `scalarfunc`)

* `Laplacians.jl` variable (graph value)
* `ThreadsX.jl` macrocall (`@eval ThreadsX $Base.@doc $doc $name`)
* `Latexify.jl` variable (function, not call)

* `Cassette.jl` call (overdub function call)

* `MathOptInterface.jl` variable (type)

* `AbstractAlgebra.jl` search of name by value (whaaat?)

* `Debugger.jl` variable (function (not call), assignments)

* `Gen.jl` variable (function definition):
  ```julia
  for function_defn in generated_functions
      Core.eval(__module__, function_defn)
  end
  ```

* `LightGraphs.jl` variable (type)
* `TextAnalysis.jl` variable (function)
* `AutoMLPipeline.jl` variable (tuple to vector conversion)
* `Query.jl` variable (types or tuples)

* `NTFk.jl` parse (function name), symbol (symbol or module)

* `RCall.jl` call (prepare some Julia code), macrocall (`@formula`),
  expr (top-level const and function definitions)

* `Strategems.jl` variable (function but not function call)
* `Twitter.jl` variable (seems to be a string or JSON something)
* `AutoMLPipeline.jl` variable (value conversion)
* `FourierFlows.jl` variable (function call)
* `Infiltrator.jl` variable (any expression)