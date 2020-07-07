#lang racket

(require redex)
(require "../core/wa-full.rkt") ; import language semantics
(require "../wa-examples.rkt")  ; import examples
(require "../optimizations/wa-optimized.rkt") ; import optimized language
(require "../optimizations/wa-optimized-examples.rkt") ; import optimized examples


(define (opt-equivalence e)
  (equal? (term (run-to-r ,e)) (term (run-to-r-opt ,e))))

(module+ test

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Typing Judgement Tests
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  ; Type-check tests
  (test-equal (judgment-holds (⊢ () 1 Float64)) #false)
  (test-equal (judgment-holds (⊢ () 1.1 Float64)) #true)
  (test-equal (judgment-holds (⊢ () false Bool)) #true)
  (test-equal (judgment-holds (⊢ () (mval "test") (mtag "test"))) #true)
  (test-equal (judgment-holds (⊢ () (mval "test") Bool)) #false)
  (test-equal (judgment-holds (⊢ () nothing Nothing)) #true)
  (test-equal (judgment-holds (⊢ ((y Bool)) y Bool)) #true)
  (test-equal (judgment-holds (⊢ ((x Int64) (y Bool)) z Bool)) #false)
  (test-equal (judgment-holds (⊢ ((y Bool)) y Int64)) #false)
  (test-equal (judgment-holds (⊢ ((y Bool)) (seq y true) Bool)) #true)
  (test-equal (judgment-holds (⊢ ((x String) (y Float64)) (seq y x) Bool)) #false)
  (test-equal (judgment-holds (⊢ ((y Bool)) (evalg y) Bool)) #true)
  (test-equal (judgment-holds (⊢ ((y Bool)) (evalg 1.1) Bool)) #false)
  ; Type-check primop tests
  (test-equal (judgment-holds (⊢ ((x String) (y Float64)) (pcall + 1 y) Float64)) #true)
  (test-equal (judgment-holds (⊢ ((x String) (y Float64)) (pcall * 1 1) Int64)) #true)
  (test-equal (judgment-holds (⊢ ((y Float64)) (pcall - y y) Float64)) #true)
  (test-equal (judgment-holds (⊢ ((y Float64)) (pcall / y 1) Float64)) #true)
  (test-equal (judgment-holds (⊢ ((b Bool)) (pcall ! b) Bool)) #true)
  (test-equal (judgment-holds (⊢ ,yfloat-bBool (pcall && b y) Any)) #true)
  (test-equal (judgment-holds (⊢ ,yfloat-bBool (pcall == b y) Bool)) #true)
  (test-equal (judgment-holds (⊢ ,yfloat-bBool (pcall print b y) Any)) #true)
  (test-equal (judgment-holds (⊢ ,yfloat-bBool (pcall print b) Nothing)) #true)
  (test-equal (judgment-holds (⊢ ,yfloat-bBool (pcall + b y 1.1) Any)) #true)
  (test-equal (judgment-holds (⊢ ,yfloat-bBool (if b y 1.1) Any)) #true)
  ; Type-check method tests
  (test-equal (judgment-holds (⊢ () (seq (mdef "test" ((:: x Int64)) x) (mcall "test" 1))
                                 Any)) #true)
  (test-equal (judgment-holds (⊢ () (seq (mdef "test" ((:: x Int64)) x) (mcall "test" 1))
                                 Int64)) #false)
  (test-equal (judgment-holds (⊢ () (seq (mdef "test" ((:: y Bool) (:: x Int64))
                                               (evalg (mdef "h" ((:: y Nothing)) y)))
                                         (mcall "test" 1))  Any)) #true)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Optimization Judgement Tests
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; Manual optimization judgments
  (test-equal (judgment-holds (~~> () (evalt (,func-return3 • ∅) (mcall func))
                                   (evalt (,func-return3 • ∅) (mcall (mval "func"))))) #true)
  (test-equal (judgment-holds (~~> () (evalt (,func-return3 • ∅) (mcall func))
                                   (evalt (,func-return3 • ∅) (seq nothing 3)))) #true)
  (test-equal (judgment-holds (~~> ((y Int64))
                                   (evalt (,add-intNum • ∅)
                                          (mcall (mval "add") 1 (pcall + y 1.1)))
                                   (evalt ((mdef "add_P" ((:: x Int64) (:: y Int64)) (pcall + x y))
                                           • (,add-intNum • ∅))
                                          (mcall (mval "add_P") 1 (pcall + y 1.1))))) #false)
  
  ; Automatically generated optimization judgements
  ; () ∅ 1 -> true
  (test-equal (term (valid-optimization () ∅ 1)) #t)
  ; () ∅ func(x) undeclared-var -> false
  (test-equal (term (valid-optimization () ∅ ,call-func-with-x)) #t)
  ; ((x Bool)) ∅ 1+x -> true
  (test-equal (term (valid-optimization ,xBool-type-env ∅ ,one-plus-x)) #t)
  ; () ∅ func() err-no-method -> true
  (test-equal (term (valid-optimization () ∅ ,call-func)) #t)
  ; () (f()=1 • ∅) func() -> true
  (test-equal (term (valid-optimization () (,func1 • ∅) ,call-func)) #t)
  ; ((y Int64)) (y()=1 • ∅) y() ->
  (test-equal (term (valid-optimization ,wInt-type-env (,func1 • ∅) (mcall w))) #t)
  ; ((w Int64)) (y()=x • ∅) id(id(w)) -> true
  (test-equal (term (valid-optimization ,wInt-type-env (,idInt • ∅) (mcall id ,call-id-with-w))) #t)
  ; ((w Int64)) (y(x:Int64)=x • ∅) id(w);id(w);id(w) -> true
  (test-equal (term (valid-optimization ,wInt-type-env (,idInt • ∅) seq-id-calls)) #t)
  ; ((var1 Bool) (var2 Int64) (var1 Int64))
  ; (f(x:Int64)=2 • (add(x:Int64,y=Int64)=x+y • (f(x:Bool)=1 • ∅)))
  ; f(var1) -> true
  (test-equal (term (valid-optimization ,var-type-env ,MT_1 ,call-f-with-var1)) #t)
  ; ((var1 Bool) (var2 Int64) (var1 Int64))
  ; (f(x:Int64)=2 • (add(x:Int64,y=Int64)=x+y • (f(x:Bool)=1 • ∅)))
  ; f(var1);add(var1,var2) err-no-method -> true
  (test-equal (term (valid-optimization ,var-type-env ,MT_1 ,seq-f-then-add)) #t)
  ; ((var1 Int64) (var2 Int64) (var1 Bool))
  ; (f(x:Int64)=2 • (add(x:Int64,y=Int64)=x+y • (f(x:Bool)=1 • ∅)))
  ; f(var1);add(var1,var2) -> true
  (test-equal (term (valid-optimization ,var-type-env-2 ,MT_1 ,seq-f-then-add)) #t)
  ; () ((mdef "func" ((:: x Int64)) 2) • ∅) func(1*2) -> true
  (test-equal (term (valid-optimization () (,func3-with-x • ∅) (mcall func (pcall * 1 2)))) #t)
  ; () ((mdef "func" ((:: x Int64)) 2) • ∅) (|func(2)|)
  (test-equal (term (valid-optimization () (,func3-with-x • ∅) (evalg (mcall func 2)))) #t)
  ; ((var1 Int64))
  ; (first()=second() • (second()=1 • ∅))
  ; first() -> true
  (test-equal (term (valid-optimization ((var1 Int64))
                                        (,first-calls-second • (,second-1 • ∅))
                                        (mcall first))) #t)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Unoptimized to Optimized Juliette Equivalence Tests
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; Trivial/primop programs
  
  ; (| 5 |) -->* 5
  (test-predicate opt-equivalence p-triv-1)
  ; (| print(...); print(...) |) -->* nothing
  (test-predicate opt-equivalence p-primop-5)
  
  ; Erroneous programs

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
  
  ; Simple programs

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

  ; Eval/world-age programs
  
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
  
  ; Litmus

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
