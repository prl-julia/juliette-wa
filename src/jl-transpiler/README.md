# Julia to Redex transpiler

This transpiler converts a subset of the Julia language into
the Redex defined world age language (can be found [here](../redex)).
This is meant to help more easily test the Redex defined semantics
by writing examples in a more familiar language like Julia.

## How to test

- To run all the tests, run the following command:
  - `cd tests; julia test.jl`

## Code organization

- [`main.jl`](main.jl): main project file;

- [`world-age-ast.jl`](world-age-ast.jl): `WAAST` data definitions
  for the internal representation of transpilable programs;

- [`parser.jl`](parser.jl): parser from Julia AST into `WAAST`;

- [`unparser.jl`](unparser.jl): unparser from `WAAST` into the Redex model;

- [`transpiler.jl`](transpiler.jl): string-to-string transpiler from
  Julia syntax to the Redex-model syntax;

- [`auxiliary`](auxiliary): folder with auxiliary definitions.

## Notes on design

At a high level, this transpiler (1) converts SubJulia (defined below) to
a `WAAST` (world-age ast) using the parser and (2) converts this `WAAST` to
a string that is its Redex representation using the unparser.

Note that due to the target language being transpiled to, there are still
a few structures of SubJulia programs that are not supported by the transpiler;
such structures include but are not limited to programs with free variables,
programs that redefine `eval`/`invokelatest`, programs with calls to primops/eval
who's callee is not the immediate symbol representing the function,
interpolated methods, and programs calling `invokelatest` on a local variable.

The main component that may require a bit of design clarification is the environment (defined in [`auxiliary/environment.jl`](auxiliary/environment.jl)). In particular, the environment, which stores variables in scope for a given expression, is made up of local variables and scope separators. Local variables have a source name and target name because the target language does not have variable interpolation, so to achieve correct translation variable names need to be renamed so that there is no overlap. To a similar effect, scope separators are needed to differentiate which version of variables are being referenced when a variable is interpolated

## Supported Julia sub-language

Following is the definition of the SubJulia language, which is the supported
subset of the Julia language in the traspiler.

#### A `SubJulia` expression is one of:

- `Number`

- `Bool`

- `String`

- `Symbol`

- `<VarRef>`

- Return expression of the form:
  ```julia
  # Julia code:
  return <SubJulia>

  # Julia AST:
  Expr
      head: :return
      args:
          1: <SubJulia>
  ```

- If-Then expression of the form:
  ```julia
  # Julia code:
  if <SubJulia>
      <SubJulia>
  end

  # Julia AST:
  Expr
      head: :if | :elseif
      args:
          1: <SubJulia>
          2: <SubJulia>
  ```
- If-Then-Else expression of the form:
  ```julia
  # Julia code:
  if <SubJulia>
      <SubJulia>
  else
      <SubJulia>
  end

  # Julia code:
  <SubJulia> ? <SubJulia> : <SubJulia>

  # Julia AST:
    Expr
        head: :if | :elseif
        args:
            1: <SubJulia>
            2: <SubJulia>
            3. <SubJulia>
  ```
- Quoted expression of the form:
  ```julia
  # Julia code:
  quote <SubJulia> end

  # Julia AST:
  Expr
      head: :quote
      args:
          1: <SubJulia>
  ```

- Quoted expression of the form:
  ```julia
  # Julia code:
  :(<SubJulia>)

  # Julia AST:
  QuoteNode
      value: <SubJulia>
  ```

- Block expression of the form:
  ```julia
  # Julia code:
  begin
      <SubJulia>
          .
          .
      <SubJulia>
  end

  # Julia AST:
  Expr
      head: :block
      args:
        1: <SubJulia>
            .
            .
        n: <SubJulia>
  ```

- Method call expression of the form:
  ```julia
  # Julia code:
  <SubJulia>(<SubJulia>)

  # Julia AST:
  Expr
      head: :call
      args:
          1: <SubJulia>
              .
              .
          n: <SubJulia>
  ```

- `Base.invokelatest` method call expression of the form:
  ```julia
  # Julia code:
  Base.invokelatest(<SubJulia>, ..., <SubJulia>)

  # Julia AST:
  Expr
      head: :call
      args:
          1: Expr
              head: :(.)
              args:
                  1. :Base
                  2. QuoteNode
                      value: :invokelatest
          2: <SubJulia>
              .
              .
          n: <SubJulia>
  ```

- Method definition expression of the form:
  ```julia
  # Julia code:
  <Symbol>(<Param>,...,<Param>) = <SubJulia>

  # Julia AST:
  Expr
    head: <MethodDef>
    args:
        1: Expr
            head: :call
            args:
              1. Symbol
              2. <Param>
                  .
                  .
              n: <Param>
        2: <SubJulia>
  ```

#### A `VarRef` is one of:

- Symbol

- Interpolated expression of the form:
  ```julia
  # Julia code:
  $(<VarRef>)

  # Julia AST:
  Expr
      head: :$
      args:
          1: <VarRef>
  ```


#### A `Param` is one of:

- Symbol

- Typed parameter of the form:
  ```julia
  # Julia code:
  <Symbol> :: <ParamType>

  # Julia AST:
  Expr
    head: :(::)
    args:
      1. Symbol
      2. <ParamType>
  ```


#### A `ParamType` is one of:

- Symbol in the set `{:Bool,:Number,:Int64,:Float64,:String,:Nothing,:Any}`

- Method type of the form:
  ```julia
  # Julia code:
  typeof(<Symbol>)

  # Julia AST:
  Expr
    head: :call
    args:
      1. :typeof
      2. Symbol
  ```

- Bottom type of the form:
  ```julia
  # Julia code:
  Union{}

  # Julia AST:
  Expr
    head: :curly
    args:
      1. :Union
  ```


#### A `MethodDef` is one of:

- `:(=)`

- `:function`
