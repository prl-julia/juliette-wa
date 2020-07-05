#lang racket
(require redex)

; import surface language
(require "../../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../../src/redex/core/wa-full.rkt")

(displayln "Test for test-files/test07:")

(define p
    (term
  (evalg
   (seq
    (mdef
     "f2"
     ()
     (evalg
      (seq
       (mdef "h1" () (evalg (mdef "h2" () 2)))
       (seq (mcall h1) (mcall h2)))))
    (mcall f2))))
)

(test-equal (term (run-to-r ,p)) (term 2))

(test-results)