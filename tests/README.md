# Testing for Julia/Juliette Correspondence

This directory contains the litmus test cases that help validate the logical equivalence of julia and juliette

## Test Cases

Every folder in the `litmus-wa/` and `litmus-optimizations/` directories represents a single test case. All test cases in `litmus-optimizations/` are run using Juliette optimizations, while all test cases in the `litmus-wa/` are not. Every test case consists of 3 files:

* `source.jl` — Julia program of interest;

* `expected.jl` — Julia program with a unit test that describes
  the expected outcome of running `source.jl`;

* `redex.rkt` — Redex program that is generated when a test is run;   
  this file combines is the resulting translation of `source.jl` into Juliette

## Run Tests

The tests can be run in one of the following ways (commands must be run from the
current directory):

* `julia run-test.jl` — runs all the tests in both test directories

* `julia run-test.jl <-s | --select> <list of test cases>` — runs all the tests provided in the args
  * example: `julia run-test.jl -s litmus-wa/test01 litmus-optimizations/test01`

* `julia run-test.jl <-opt | --litmus-opt>` — runs all the tests in `litmus-optimizations`
  * example: `julia run-test.jl --litmus-opt`

* `julia run-test.jl <-wa | --litmus-wa>` — runs all the tests in `litmus-wa`
  * example: `julia run-test.jl -wa`
