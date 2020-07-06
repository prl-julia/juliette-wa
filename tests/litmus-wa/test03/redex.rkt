#lang racket
    (require redex)

    ; import surface language
    (require "../../../src/redex/core/wa-surface.rkt")
    ; import full language
    (require "../../../src/redex/core/wa-full.rkt")
    ; import optimizations
    (require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-wa/test03:")

(define p
    (term
  (evalg
   (seq
    (mdef "h" () (seq (evalg (mdef "j" () 2)) (evalg (mcall j))))
    (mcall h))))
)

(test-equal (term (run-to-r ,p)) (term 2))

(test-results)