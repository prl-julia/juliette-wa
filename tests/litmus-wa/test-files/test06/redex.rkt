#lang racket
(require redex)

; import surface language
(require "../../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../../src/redex/core/wa-full.rkt")

(displayln "Test for test-files/test06:")

(define p
    (term
  (evalg
   (seq
    (mdef "l" () (evalg (seq (evalg (mdef "f1" () 2)) (mcall f1))))
    (mcall l))))
)

(test-equal (term (run-to-r ,p)) (term 2))

(test-results)