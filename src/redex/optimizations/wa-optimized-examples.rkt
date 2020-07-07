#lang racket

(require redex)
(require "../core/wa-full.rkt") ; import language semantics
(require "../optimizations/wa-optimized.rkt") ; import optimized language

(provide (all-defined-out)) ; export all definitions

;;;;;;;;;;;;;;;;;
;; Expressions
;;;;;;;;;;;;;;;;;

;; func() = 1
(define func1 (term (mdef "func" () 1)))
;; func(x :: Int64) = 3
(define func3-with-x (term (mdef "func" ((:: x Int64)) 3)))
;; id(x :: Int64) = x
(define idInt (term (mdef "id" ((:: x Int64)) x)))
;; id(w)
(define call-id-with-w (term (mcall id w)))
;; func()
(define call-func (term (mcall func)))
;; func(x)
(define call-func-with-x (term (mcall func x)))
;; id(w);id(w);id(w)
(define seq-id-calls (term (seq ,call-id-with-w
                                (seq ,call-id-with-w
                                     ,call-id-with-w))))
;; add(x :: Int64, y :: Number) = x+y
(define add-intNum (term (mdef "add" ((:: x Int64) (:: y Number)) (pcall + x y))))
;; func() = 3
(define func-return3 (term (mdef "func" () 3)))
;; f(var1)
(define call-f-with-var1 (term (mcall (mval "f") var1)))
;; f(var1);add(var1,var2)
(define seq-f-then-add (term (seq ,call-f-with-var1
                                  (mcall (mval "add") var1 var2))))
;; 1+x
(define one-plus-x (term (pcall + 1 x)))
;; first() = second()
(define first-calls-second (term (mdef "first" () (mcall second))))
;; second() = 1
(define second-1 (term (mdef "second" () 1)))

;;;;;;;;;;;;;;;;;;;;;;;
;; Type Environments
;;;;;;;;;;;;;;;;;;;;;;;

;; ((var1 Bool) (var2 Int64) (var1 Int64))
(define var-type-env (term ((var1 Bool) (var2 Int64) (var1 Int64))))
;; ((var1 Int64) (var2 Int64) (var1 Bool))
(define var-type-env-2 (term ((var1 Int64) (var2 Int64) (var1 Bool))))
;; ((w Int64))
(define wInt-type-env (term ((w Int64))))
;; ((x Bool))
(define xBool-type-env (term ((x Bool))))
;; ((y Float64) (b Bool))
(define yfloat-bBool (term ((y Float64) (b Bool))))

;;;;;;;;;;;;;;;;;;;
;; Method Tables
;;;;;;;;;;;;;;;;;;;

;; (f(x:Int64)=2 • (add(x:Int64,y=Int64)=x+y • (f(x:Bool)=1 • ∅)))
(define MT_1 (term ((mdef "f" ((:: x Int64)) 2)
              •((mdef "add" ((:: x Int64) (:: y Int64)) (pcall + x y))
                • ((mdef "f" ((:: x Bool)) 1) • ∅)))))