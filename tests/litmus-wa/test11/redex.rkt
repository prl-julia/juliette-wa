#lang racket
(require redex)

; import surface language
(require "../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../src/redex/core/wa-full.rkt")

(displayln "Test for litmus-wa/test11:")

(define p
    (term
  (evalg
   (seq
    (mdef
     "h"
     ((:: 1_bool Bool))
     (seq
      (if 1_bool (evalg (mdef "j" () 1)) (evalg (mdef "j" () 2)))
      (evalg (mcall j))))
    (pcall && (pcall == (mcall h true) 1) (pcall == (mcall h false) 2)))))
)

(test-equal (term (run-to-r ,p)) (term true))

(test-results)