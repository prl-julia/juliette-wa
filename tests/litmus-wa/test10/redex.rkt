#lang racket
(require redex)

; import surface language
(require "../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../src/redex/core/wa-full.rkt")

(displayln "Test for litmus-wa/test10:")

(define p
    (term
  (evalg
   (seq
    (mdef
     "g"
     ()
     (seq (evalg (mdef "k" () (evalg (mdef "h" () 1)))) (evalg (mcall k))))
    (mcall g))))
)

(test-equal (term (run-to-r ,p)) (term (mval "h")))

(test-results)