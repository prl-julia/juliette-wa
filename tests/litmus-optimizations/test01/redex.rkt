#lang racket
    (require redex)

    ; import surface language
    (require "../../../src/redex/core/wa-surface.rkt")
    ; import full language
    (require "../../../src/redex/core/wa-full.rkt")
    ; import optimizations
    (require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-optimizations/test01:")

(define p
    (term
  (evalg
   (seq
    (mdef "f" ((:: 1_x Any)) "f-any")
    (seq
     (mdef "f" ((:: 1_x Int64)) "f-int")
     (seq
      (mdef "h" ((:: 1_x Float64)) (mcall f 1_x))
      (seq
       (mdef "h" ((:: 1_x Any)) "h-any")
       (seq
        (pcall @assert (pcall == (mcall h 3.14) "f-any"))
        (seq
         (pcall @assert (pcall == (mcall h 413) "h-any"))
         (seq
          (mdef "f" ((:: 1_x Float64)) "f-float")
          (seq
           (pcall @assert (pcall == (mcall h 3.14) "f-float"))
           (seq (mdef "h" ((:: 1_x Float64)) 777) (mcall h 3.14))))))))))))
)

(test-equal (term (run-to-r-opt ,p)) (term 777))

(test-results)