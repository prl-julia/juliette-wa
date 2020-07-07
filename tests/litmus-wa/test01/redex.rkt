#lang racket
(require redex)

; import surface language
(require "../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../src/redex/core/wa-full.rkt")
; import optimizations
(require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-wa/test01:")

(define p
    (term
  (evalg
   (seq (mdef "g" () (seq (evalg (mdef "k" () 2)) (mcall k))) (mcall g))))
)

(test-equal (term (run-to-r ,p)) (term err-no-method))

(test-results)