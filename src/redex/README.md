# Redex model of World Age Calculus

[PLT Redex](https://redex.racket-lang.org/) is a racket DSL
for modeling programming language semantics.

Introductory materials:

* [PLT Redex FAQ](http://prl.ccs.neu.edu/blog/2017/09/25/plt-redex-faq/)
  by [Ben Greenman](http://ccs.neu.edu/home/types)
  and [Sam Caldwell](http://ccs.neu.edu/home/samc)
* [Experimenting with Languages in Redex](https://williamjbowman.com/doc/experimenting-with-redex/index.html)
  by [William J. Bowman](https://williamjbowman.com)
* [Redex Tutorial](https://docs.racket-lang.org/redex/tutorial.html)

## Dependencies

* [Racket](https://racket-lang.org/)
  with [Redex](https://redex.racket-lang.org/)

## Source Code

* [`core`](core) folder with the core operational semantics:

  - [`wa-surface.rkt`](core/wa-surface.rkt) surface language `WA`
    (expressions, types, subtyping);

  - [`wa-full.rkt`](core/wa-full.rkt) semantics of the calculus `WA-full`
    (aux definitions such as `typeof` and primops,
    and small-step reduction relation);

* [`optimizations`](optimizations) folder with program optimizations
  for world age calculus:

  - [`wa-optimized.rkt`](optimizations/wa-optimized.rkt) the optimization semantics 
    of world age, `WA-opt` (optimization algorithm, definition of correctness
    of optimization, and world age semantics employing optimizations);

* [`wa-examples.rkt`](wa-examples.rkt) example expressions;

* [`tests`](tests) folder with tests:

  - [`wa-tests.rkt`](tests/wa-tests.rkt) hand-written unit-tests
    for the grammar and core semantics;

  - [`wa-prop-tests.rkt`](tests/wa-prop-tests.rkt) random testing
    (currently, only for determinism of the semantics);

  - [`wa-optimized-tests.rkt`](wa-optimized-tests.rkt) hand-written unit
    tests to validate the equivalence of optimized and unoptimized expressions;

*Note.* File [`attic/wa-full.rkt`](attic/wa-full.rkt) contains a direct
implementation of finding applicable methods, without an auxiliary
`latest` function.
