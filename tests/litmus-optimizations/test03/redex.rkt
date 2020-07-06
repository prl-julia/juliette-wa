#lang racket
    (require redex)

    ; import surface language
    (require "../../../src/redex/core/wa-surface.rkt")
    ; import full language
    (require "../../../src/redex/core/wa-full.rkt")
    ; import optimizations
    (require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-optimizations/test03:")

(define p
    (term
  (evalg
   (seq
    (mdef
     "h"
     ((:: 1_y Int64))
     (pcall * (mcall f 1_y) (mcall g (pcall + 1_y 1_y))))
    (seq
     (mdef "f" ((:: 1_x Any)) 1)
     (seq
      (mdef "g" ((:: 1_x Int64)) (pcall + 1_x (mcall f 1_x)))
      (seq
       (mdef "g" ((:: 1_x Any)) 0)
       (seq
        (pcall @assert (pcall == (mcall h 3) 7))
        (seq
         (mdef "f" ((:: 1_x Any)) -1)
         (seq
          (pcall @assert (pcall == (mcall h 3) -5))
          (seq
           (mdef "f" ((:: 1_x Int64)) 2)
           (seq
            (mdef "g" ((:: 1_x Int64)) (pcall - 1_x (mcall f 1_x)))
            (mcall h 3))))))))))))
)

(test-equal (term (run-to-r-opt ,p)) (term 8))

(test-results)