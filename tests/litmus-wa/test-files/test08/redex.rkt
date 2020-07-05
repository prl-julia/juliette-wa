#lang racket
(require redex)

; import surface language
(require "../../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../../src/redex/core/wa-full.rkt")

(displayln "Test for test-files/test08:")

(define p
    (term
  (evalg
   (seq
    (mdef
     "f3"
     ()
     (seq (mdef "h1" () (seq (evalg (mdef "h3" () 2)) (mcall h3))) (mcall h1)))
    (mcall f3))))
)

(test-equal (term (run-to-r ,p)) (term err-no-method))

(test-results)