#lang racket
(require redex)

; import surface language
(require "../../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../../src/redex/core/wa-full.rkt")

(displayln "Test for test-files/test12:")

(define p
    (term
  (evalg (seq (mdef "h" () (if (pcall + 1 2) (mcall a) nothing)) (mcall h))))
)

(test-equal (term (run-to-r ,p)) (term type-err))

(test-results)