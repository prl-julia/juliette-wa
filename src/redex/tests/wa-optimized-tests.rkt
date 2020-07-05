#lang racket

(require redex)
(require "../core/wa-full.rkt") ; import language semantics
(require "../wa-examples.rkt")  ; import examples
(require "../optimizations/wa-optimized.rkt") ; import optimized language

(define (opt-equivalence e)
  (equal? (term (run-to-r ,e)) (term (run-to-r-opt ,e))))

(module+ test
  ;; ------------------- Trivial/primop programs

  ; (| 5 |) -->* 5
  (test-predicate opt-equivalence p-triv-1)
  ; (| print(...); print(...) |) -->* nothing
  (test-predicate opt-equivalence p-primop-5)
  
;; ------------------- Erroneous programs

  ; (| x |) -->* <∅, var-err>
  (test-predicate opt-equivalence p-fvar-1)
  
  ; (| true + 1 |) -->* <∅, prim-err>
  (test-predicate opt-equivalence p-+bad-2)

  ; (| x |) -->* var-err
  (test-predicate opt-equivalence p-fvar-1)

  ; (| f(1) |) -->* var-err
  (test-predicate opt-equivalence p-nomd-1)
  
  ; (| f() = 0 ; f(1) |) -->* err-no-method
  (test-predicate opt-equivalence p-nomd-2)
  
  ; (| true(1) |) -->* call-err
  (test-predicate opt-equivalence p-nclbl-1)

  ; (| f(x) = (k() = x ; x + k()) ; f(42) |) -->* err-no-method
  (test-predicate opt-equivalence p-undefm-1)

  ; (| f(x) = (k() = x ; x + k()) ; f(42) |) -->* err-no-method
  (test-predicate opt-equivalence p-undefm-1)
  
  ; (| true ! true |) -->* prim-err
  (test-predicate opt-equivalence toomanyargs)
  
  ; (| && |) -->* prim-err
  (test-predicate opt-equivalence toofewargs)
  
  ; (| if 1+1 then 1 else 1 |) -->* type-err
  (test-predicate opt-equivalence if-type-err)
  
;; ------------------- Simple programs

  ; (| f(x)=0 |) -->* (mval "f")
  (test-predicate opt-equivalence p-simple-1)
  
  ; (| f(x)=0 ; f(1) |) -->* 0
  (test-predicate opt-equivalence p-simple-2)
  
  ; (| inc(x::Int64)=x+1 ; inc(10) |) -->* 11
  (test-predicate opt-equivalence p-simple-3)
  
  ; (| f(x)=666 ; print(f(0)) |) -->* nothing
  (test-predicate opt-equivalence p-simple-4)
  
  ; (| f(x)=0 ; f(x::Int64)="f-int" ; f(1) |) -->* "f-int"
  (test-predicate opt-equivalence p-simple-5-1)
  
  ; (| f(x::Int64)="f-int" ; f(x)=0 ; f(1) |) -->* "f-int"
  (test-predicate opt-equivalence p-simple-5-2)
  
  ; (| f(x)=0 ; f(x::Int64)="f-int" ; f(3.14) |) -->* 0
  (test-predicate opt-equivalence p-simple-5-3)
  
  ; (| f(x)=0 ; f(x)=666 ; f(1) |) -->* 666
  (test-predicate opt-equivalence p-simple-5-4)
  
  ; (| f(x)=666 ; f(x)=0 ; f(1) |) -->* 0
  (test-predicate opt-equivalence p-simple-5-5)

  ; (| (f(x) = (| print(1010) |) ; -1010) ; f(1) |) -->* -1010
  (test-predicate opt-equivalence p-simple-6-1)

  ; (| (f(f) = (print(f) ; 55) ; f(0) |) -->* 55
  (test-predicate opt-equivalence p-simple-7-1)
  
  ; (| f() = "f-no-arg" ; f(g) = g() ; f(f) |) -->* "f-no-arg"
  (test-predicate opt-equivalence p-simple-7-2)
  
  ; (| f() = "f-no-arg" ; f(g) = (g()="g-no-arg"; g()) ; f(f) |) -->* "f-no-arg"
  (test-predicate opt-equivalence p-simple-7-3)
  
  ; (| add(x, y) = x + y; addxy(((|f(x)=333|);1),((|f(x)=666|);2)) |) -->* 3
  (test-predicate opt-equivalence order-of-eval-mcall)
  
  ; (| (|f(x)=333|);1) + ((|f(x)=666|);2) |) --->* 3
  (test-predicate opt-equivalence order-of-eval-pcall)

;; ------------------- Eval/world-age programs
  
  ; (| f(x)=0 ; g(y)=...; g(1) |) -->* 0
  (test-predicate opt-equivalence p1)

  ; (| g(y)=...; g(1) |) -->* err-no-method
  (test-predicate opt-equivalence (term (evalg (seq ,gtop-deff-callf (mcall (mval "g") 1)))))

  ; (| f(x)=0 ; g(y)=((|f(x)=333|);f(y)) ; g(0) + g(0) |) -->* 333
  (test-predicate opt-equivalence p2-1)
  
  ; (| f(x)=0 ; g(y)=((|f(x)=333|);f(y)) ; g(0) ; g(0) + g(0) |) -->* 333
  (test-predicate opt-equivalence p2-2)

  ; (| f(x) = (k() = x ; x + k()) ; k() = 2 ; f(42) |) -->* 44
  (test-predicate opt-equivalence p3-1)
  
  ; (| f(x) = (k() = x ; x + k()) ; k() = 2 ; f(42) ; f(42) |) -->* 84
  (test-predicate opt-equivalence p3-2)
  
;; ------------------- Litmus

  ; (| g() = ( k()=2;k() ) ; g() |) -->* err-no-method
  (test-predicate opt-equivalence plitmus-1)
  
  ; (| g() = ( k()=2;(|k()|) ) ; g() |) -->* 2
  (test-predicate opt-equivalence plitmus-2)

  ; (| r2()=r1(); m()=((|r1()=2|);r2()); m() -->* err-no-method
  (test-predicate opt-equivalence plitmus-middle-1)
  
  ; (| r3()=r4(); m()=((|r4()=2|);(|r3()|)); m()
  (test-predicate opt-equivalence plitmus-middle-2)

  ; (| f(y)=(|x|) ; f(0) |) -->* var-err
  (test-predicate opt-equivalence plitmus-undef-var-1)
  
  (test-results))
