#lang racket
    (require redex)

    ; import surface language
    (require "../../../src/redex/core/wa-surface.rkt")
    ; import full language
    (require "../../../src/redex/core/wa-full.rkt")
    ; import optimizations
    (require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-wa/test09:")

(define p
    (term (evalg (seq (mdef "f4" ((:: 1_x Any)) (evalg x)) (mcall f4 0))))
)

(test-equal (term (run-to-r ,p)) (term var-err))

(test-results)