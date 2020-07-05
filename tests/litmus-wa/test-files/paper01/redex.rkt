#lang racket
(require redex)

; import surface language
(require "../../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../../src/redex/core/wa-full.rkt")

(displayln "Test for test-files/paper01:")

(define p
    (term
  (evalg
   (seq
    (mdef "g" () 2)
    (seq
     (mdef
      "f"
      ((:: 1_x Any))
      (seq (evalg (mdef "g" () 1_x)) (pcall * 1_x (mcall g))))
     (mcall f 42)))))
)

(test-equal (term (run-to-r ,p)) (term 84))

(test-results)