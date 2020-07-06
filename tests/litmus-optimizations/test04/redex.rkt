#lang racket
(require redex)

; import surface language
(require "../../../src/redex/core/wa-surface.rkt")
; import full language
(require "../../../src/redex/core/wa-full.rkt")
; import optimizations
(require "../../../src/redex/optimizations/wa-optimized.rkt")

(displayln "Test for litmus-optimizations/test04:")

(define p
    (term
  (evalg
   (seq
    (mdef "odd" ((:: 1_x Any)) "boo-odd")
    (seq
     (mdef "even" ((:: 1_x Any)) "boo-even")
     (seq
      (pcall @assert (pcall == (mcall odd 7) "boo-odd"))
      (seq
       (mdef
        "odd"
        ((:: 1_x Int64))
        (mcall oddp (if (pcall >= 1_x 0) 1_x (pcall * -1 1_x))))
       (seq
        (mdef
         "even"
         ((:: 1_x Int64))
         (if (pcall >= 1_x 0)
           (mcall evenp 1_x)
           (mcall evenp (pcall * -1 1_x))))
        (seq
         (mdef
          "oddp"
          ((:: 1_x Int64))
          (if (pcall == 1_x 1)
            true
            (if (pcall == 1_x 0) false (mcall even (pcall - 1_x 1)))))
         (seq
          (mdef
           "evenp"
           ((:: 1_x Int64))
           (if (pcall == 1_x 1)
             false
             (if (pcall == 1_x 0) true (mcall odd (pcall - 1_x 1)))))
          (seq
           (pcall @assert (pcall == (mcall odd 7) true))
           (seq
            (pcall @assert (pcall == (mcall odd -7) true))
            (seq
             (pcall @assert (pcall == (mcall even -7) false))
             (seq
              (mdef "oddp" ((:: 1_x Int64)) "oddp")
              (seq
               (pcall @assert (pcall == (mcall odd -7) "oddp"))
               (seq
                (pcall @assert (pcall == (mcall even -7) "oddp"))
                (seq
                 (pcall @assert (pcall == (mcall even -1) false))
                 (mcall even 0)))))))))))))))))
)

(test-equal (term (run-to-r-opt ,p)) (term true))

(test-results)