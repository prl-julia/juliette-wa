#lang racket
(require redex)

; import surface language
(require "../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../src/redex/core/wa-full.rkt")
; import optimizations
(require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-wa/test05:")

(define p
    (term
  (evalg
   (seq
    (mdef "r3" () (mcall r2))
    (seq
     (mdef "m" () (seq (evalg (mdef "r2" () 2)) (evalg (mcall r3))))
     (mcall m)))))
)

(test-equal (term (run-to-r ,p)) (term 2))

(test-results)