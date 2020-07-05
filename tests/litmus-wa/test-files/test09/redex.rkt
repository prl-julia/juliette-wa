#lang racket
(require redex)

; import surface language
(require "../../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../../src/redex/core/wa-full.rkt")

(displayln "Test for test-files/test09:")

(define p
    (term (evalg (seq (mdef "f4" ((:: 1_x Any)) (evalg x)) (mcall f4 0))))
)

(test-equal (term (run-to-r ,p)) (term var-err))

(test-results)