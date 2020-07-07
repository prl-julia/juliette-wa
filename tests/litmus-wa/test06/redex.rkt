#lang racket
(require redex)

; import surface language
(require "../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../src/redex/core/wa-full.rkt")
; import optimizations
(require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-wa/test06:")

(define p
    (term
  (evalg
   (seq
    (mdef "l" () (evalg (seq (evalg (mdef "f1" () 2)) (mcall f1))))
    (mcall l))))
)

(test-equal (term (run-to-r ,p)) (term 2))

(test-results)