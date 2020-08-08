# Testing for Julia/Juliette Correspondence

This directory contains the litmus test cases that help validate
the logical equivalence of Julia and Juliette.

## Test Cases

Every folder in the [`litmus-wa/`](litmus-wa) and
[`litmus-optimizations/`](litmus-optimizations) directories
represents a single test case.  
Every test case consists of 3 files:

* `source.jl` — Julia program of interest;

* `expected.jl` — Julia program with a unit test that describes
  the expected outcome of running `source.jl`;

* `redex.rkt` — Redex program that is generated when a test is run;   
  this file includes the resulting translation of `source.jl` into Juliette.

Files `source.jl` and `expected.jl` are a test input. File `redex.rkt`
gets generated. Every time a test is run, `redex.rkt` is regenerated and run.

Note that all test cases in [`litmus-optimizations/`](litmus-optimizations)
are run using Juliette optimizations.
Test cases in the [`litmus-wa/`](litmus-wa) employ regular operational semantics.

## Running Tests

The tests can be run in one of the following ways
(commands must be run from the current directory):

* `julia run-tests.jl` — runs all the tests in both test directories.

* `julia run-tests.jl <-s | --select> <list of test cases>` — runs all
  the tests provided in the args.
  * example: `julia run-test.jl -s litmus-wa/test01 litmus-optimizations/test01`

* `julia run-tests.jl <-opt | --litmus-opt>` — runs all the tests
  in `litmus-optimizations/`.
  * example: `julia run-test.jl --litmus-opt`

* `julia run-tests.jl <-wa | --litmus-wa>` — runs all the tests in `litmus-wa/`.
  * example: `julia run-test.jl -wa`

Full run of the tests takes several minutes.
World age litmus tests take 1–2 minutes.