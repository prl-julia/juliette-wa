# Testing for Julia/Juliette Correspondence

## Test cases (`test-files`)

Every folder in this directory represents a single test case.
Every test case consists of 3 files:

* `source.jl` — Julia program of interest;

* `expected.jl` — Julia program with a unit test that describes
  the expected outcome of running `source.jl`;

* `redex.rkt` — Redex program that is generated when a test is run;   
  this file combines the translation of `source.jl`into Juliette
  and the test case corresponding to `expected.jl`.

## Run Tests/Transpile Julia

The tests in the test-files directory can be run in one of
the following ways (commands must be run from the
current directory):

* `julia run-test.jl` — runs all the tests in the test-files directory

* `julia run-test.jl <-r | -run> <list of test names>` —
  runs all the tests in the `<list of tests>`
  * example: `julia run-test.jl -r test01 test03` runs
    `test-files/test01` and `test-files/test03`

* `julia run-test.jl <-i | -ignore> <list of tests names>` —
  runs all the tests in the test-files directory that are not
  in the `<list of tests>`
  * example: if the test-files directory contained
  {test01, test02, test03, test04}, then `julia run-test.jl -r test01 test03`
  runs `test-files/test02` and `test-files/test04`

A Julia file in the `transpile-files` directory can be transpiled
in one of the following ways (commands must be run from the
current directory):

* `julia julia-to-juliette.jl <file name>` - transpiles the given
  file (hides method table) to a target file with the same name but
  `.rkt` extension
  * example: `julia julia-to-juliette.jl exmp1.jl` transpiles the
  `transpile-files/exmp1.jl` file to a `transpile-files/exmp1.rkt`
  file that hides the method table when run

* `julia julia-to-juliette.jl <file name>` - transpiles the given
  file (shows method table) to a target file with the same name but
  `.rkt` extension
  * example: `julia julia-to-juliette.jl -m exmp2.jl` transpiles the
  `transpile-files/exmp2.jl` file to a `transpile-files/exmp2.rkt`
  file that shows the method table when run

## Assumptions

Source programs don't use global variables
and don't throw method ambiguity errors.
The former is not supported by the calculus,
and latter is not supported by the testing framework.

Source programs are allowed to have:

* global method definitions;
* method calls;
* integers, floats, strings;
* `eval` and `invokelatest`;
* interpolated local variables inside `eval`.
