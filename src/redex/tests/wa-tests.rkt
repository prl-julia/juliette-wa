#lang racket
(require redex)

(require "../core/wa-surface.rkt")  ; import surface language
(require "../core/wa-full.rkt")     ; import language semantics
(require "../wa-examples.rkt")      ; import examples

(provide (all-defined-out)) ; export all definitions

(module+ test
  
  (displayln "********** TESTS BEGIN")
  
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Surface Language Tests
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Types
;; ==================================================

;; -------------------- Subtyping

  (test-equal (term (get-supertype ,tInt))  tNum)
  (test-equal (term (get-supertype ,tNum))  tTop)
  (test-equal (term (get-supertype ,tBot))  tTop)
  (test-equal (term (get-supertype ,tBool)) tTop)

  (test-equal (judgment-holds (<: ,tInt ,tTop)) #t)
  (test-equal (judgment-holds (<: ,tNum ,tTop)) #t)
  (test-equal (judgment-holds (<: ,tBot ,tStr)) #t)
  
  (test-equal (judgment-holds (<: ,tInt ,tBot)) #f)
  (test-equal (judgment-holds (<: ,tTop ,tNum)) #f)

  (test-equal (judgment-holds (<:-tuple () ())) #t)
  (test-equal (judgment-holds (<:-tuple (,tInt) (,tNum))) #t)
  (test-equal (judgment-holds (<:-tuple (,tStr ,tInt ,tBool ,tBot)
                                        (,tTop ,tNum ,tBool ,tStr))) #t)
  
  (test-equal (judgment-holds (<:-tuple (,tInt  ,tBot)
                                        (,tBool ,tNum)))      #f)
  (test-equal (judgment-holds (<:-tuple (,tInt ,tBot ,tTop)
                                        (,tInt ,tNum)))       #f)
  (test-equal (judgment-holds (<:-tuple (,tInt ,tBot)
                                        (,tNum ,tNum ,tTop))) #f)

;; -------------------- Equivalence

  (test-equal (judgment-holds (== ,tInt ,tInt)) #t)
  (test-equal (judgment-holds (== ,tNum ,tNum)) #t)
  (test-equal (judgment-holds (== ,tTop ,tTop)) #t)
  
  (test-equal (judgment-holds (== ,tInt ,tNum)) #f)
  (test-equal (judgment-holds (== ,tInt ,tFlt)) #f)
  (test-equal (judgment-holds (== ,tTop ,tBot)) #f)

  (test-equal (judgment-holds (==-tuple () ())) #t)
  (test-equal (judgment-holds (==-tuple (,tStr ,tTop)
                                        (,tStr ,tTop))) #t)
  
  (test-equal (judgment-holds (==-tuple (,tStr ,tTop ,tTop)
                                        (,tStr ,tTop)))     #f)
  
;; ==================================================
;; Grammar
;; ==================================================

;; ------------------- Values

  (test-equal (redex-match? WA v i5) #t)
  (test-equal (redex-match? WA v btrue) #t)
  (test-equal (redex-match? WA v skip) #t)
  
  (test-equal (redex-match? WA v mf) #t)
  (test-equal (redex-match? WA m mf) #t)

;; ------------------- Simple expressions

  (test-equal (redex-match? WA e btrue) #t)
  (test-equal (redex-match? WA e skip)  #t)
  (test-equal (redex-match? WA e incx)  #t)
  (test-equal (redex-match? WA e printf0) #t)
  (test-equal (redex-match? WA e seq-prints) #t)

;; ------------------- Method definitions

  (test-equal (redex-match? WA md incint) #t)
  (test-equal (redex-match? WA e  incint) #t)
  
  (test-equal (redex-match? WA md fbool-str) #t)
  (test-equal (redex-match? WA md hint-fx) #t)
  (test-equal (redex-match? WA md ftop0) #t)
  (test-equal (redex-match? WA md gtop-deff-callf) #t)
  
;; ------------------- Programs

  (test-equal (redex-match? WA p i5) #f)
  (test-equal (redex-match? WA p seq-ftop333-printf0) #f)
  
  (test-equal (redex-match? WA p p-triv-1) #t)
  (test-equal (redex-match? WA p p-triv-4) #t)

  (test-equal (redex-match? WA p p-primop-1) #t)
  (test-equal (redex-match? WA p p-primop-3) #t)
  
  (test-equal (redex-match? WA p p1) #t)

;; ==================================================
;; Substitution
;; ==================================================

  (test-equal (term (substitute x x 5) #:lang WA) (term 5))
  (test-equal (term (substitute 7 x 5) #:lang WA) (term 7))
  (test-equal (term (substitute y x 5) #:lang WA) (term y))
  
  (test-equal (alpha-equivalent? WA (term (substitute ,addxy x 5) #:lang WA) addxy) #t)
  (test-equal (term (substitute (pcall + x y) x 5) #:lang WA) (term (pcall + 5 y)))
  
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Language Semantics Tests
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Grammar
;; ==================================================

;; ------------------- Method tables

  (test-equal mt1-2 (term (,fbool-str • (,fint-str • ∅))))
  
  (test-equal (redex-match? WA-full MT mtempty) #t)
  (test-equal (redex-match? WA-full MT mt1-1)   #t)
  (test-equal (redex-match? WA-full MT mt1-4-1) #t)
  (test-equal (redex-match? WA-full MT mt1-4-2) #t)

;; ==================================================
;; Types
;; ==================================================

;; ------------------- Typeof type
  
  (test-equal (term (typeof ,i5))   tInt)
  (test-equal (term (typeof ,fpi))  tFlt)
  (test-equal (term (typeof false)) tBool)
  (test-equal (term (typeof "world-age")) tStr)
  (test-equal (term (typeof ,skip)) tSkip)
  (test-equal (term (typeof ,mf))   (tMethod "f"))
  (test-equal (term (typeof ,minc)) (tMethod "inc"))

;; ------------------- Typeof tuple-type
  
;; ==================================================
;; Primops
;; ==================================================

  (test-equal (term (run-primop + 5 -4))   (term 1))
  (test-equal (term (run-primop + 5 -4 0)) (term prim-err))
  (test-equal (term (run-primop + true 5)) (term prim-err))
  
  (test-equal (term (run-primop print))      (term ,skip))
  (test-equal (term (run-primop print "hi")) (term ,skip))
  (test-equal (term (run-primop print 5 -4)) (term prim-err))
  (test-equal mt1-2 (term (,fbool-str • (,fint-str • ∅))))

;; ==================================================
;; Multiple Dispatch
;; ==================================================

;; --------------------------------------------------
;; Helper fuctions
;; --------------------------------------------------
  
  (test-equal (term (contains-equiv-md ()           ,fint-str))  #f)
  (test-equal (term (contains-equiv-md (,fbool-str) ,fint-str))  #f)
  (test-equal (term (contains-equiv-md (,fbool-str) ,gbool-str)) #f)
  
  (test-equal (term (contains-equiv-md (,fint-str)  ,fint-str))   #t)
  (test-equal (term (contains-equiv-md (,fbool-str) ,fybool-str)) #t)
  (test-equal (term (contains-equiv-md (,fbool-str ,fint-str-new) ,fint-str)) #t)
  (test-equal (term (contains-equiv-md (,fint-str-new ,fbool-str) ,fint-str)) #t)

;; --------------------------------------------------
;; Main functions
;; --------------------------------------------------

;; -------------------- Step 1: applicable methods
  
  (test-equal (term (get-applicable-methods ,mtempty "f" ()))      (term ()))
  (test-equal (term (get-applicable-methods ,mtempty "f" (,tInt))) (term ()))
  
  (test-equal (term (get-applicable-methods ,mt1-1 "f" (,tInt)))   (term (,fint-str)))
  (test-equal (term (get-applicable-methods ,mt1-1 "f" (,tBool)))  (term ()))
  (test-equal (term (get-applicable-methods ,mt1-1 "h" (,tInt)))   (term ()))

  (test-equal (term (get-applicable-methods ,mt1-3 "h" (,tInt)))   (term (,hint-fx)))
  
  (test-equal (term (get-applicable-methods ,mt1-4-1 "f" (,tInt)))  (term (,fint-str-new)))
  (test-equal (term (get-applicable-methods ,mt1-4-1 "f" (,tBool))) (term (,fbool-str)))

  (test-equal (term (get-applicable-methods ,mt1-5 "f" (,tBool))) (term (,fybool-str)))
  (test-equal (term (get-applicable-methods ,mt1-5 "f" (,tInt)))  (term (,fnum-str ,fint-str-new)))

  (test-equal (term (get-applicable-methods ,mt1-5 "f" (,tBool ,tInt))) (term ()))
  (test-equal (term (get-applicable-methods ,mt1-6 "f" (,tBool ,tInt))) (term (,fboolint-str)))

;; -------------------- Step 2: minimal of the applicable methods
  
  (test-equal (term (min-method ())) (term err-no-method))
  (test-equal (term (min-method (,fint-str))) fint-str)
  (test-equal (term (min-method (,fint-str ,fnum-str))) fint-str)
  (test-equal (term (min-method (,fnum-str ,fint-str))) fint-str)
  (test-equal (term (min-method (,fnum-str ,fbool-str))) (term err-amb-method))

;; -------------------- Full dispatch

  (test-equal (term (getmd ,mtempty "f" (,tBool)))  (term err-no-method))
  (test-equal (term (getmd ,mt1-1   "f" (,tBool)))  (term err-no-method))
  (test-equal (term (getmd ,mt1-2   "h" (,tInt)))   (term err-no-method))
  
  (test-equal (term (getmd ,mt1-2   "f" (,tBool)))  fbool-str)
  (test-equal (term (getmd ,mt1-2   "f" (,tInt)))   fint-str)
  
  (test-equal (term (getmd ,mt1-4-2 "h" (,tInt)))   hint-fx)
  (test-equal (term (getmd ,mt1-4-2 "f" (,tInt)))   fint-str-new)
  (test-equal (term (getmd ,mt1-4-2 "f" (,tFlt)))   fnum-str)

  (test-equal (term (getmd ,mt1-5   "f" (,tBool)))  fybool-str)

  (test-equal (term (getmd ,mt1-5   "f" (,tBool ,tInt))) (term err-no-method))
  (test-equal (term (getmd ,mt1-6   "f" (,tBool ,tInt))) fboolint-str)

  (test-equal (term (getmd ,mt1-7   "f" (,tInt ,tInt)))  (term err-amb-method))
  (test-equal (term (getmd ,mt1-7   "f" (,tInt ,tFlt)))  fintnum-str)

;; ==================================================
;; Small-step Semantics
;; ==================================================

;; --------------------------------------------------
;; Normal Evaluation
;; --------------------------------------------------

  ; (| 5 |) -->* 5
  (test-equal (term (run-normal ,p-triv-1))
              (term ((< ∅ 5 >))))
   ; (| assert(true && true) |)
  (test-equal (term (run-to-r ,p-assert-t))
              (term nothing))
  ; (| assert(1 == 2) |)
  (test-equal (term (run-to-r ,p-assert-f))
              (term assert-err))
  ; (| assert(-3+-4) |)
  (test-equal (term (run-to-r ,p-assert-n7))
              (term type-err))
  ; (| skip ; -5 |) -->* -5
  (test-equal (term (run-normal ,p-triv-2))
              (term ((< ∅ -5 >))))
  ; (| f(x::Int64)="f-int" ; 7 |) -->* <f(x::Int64)="f-int", 5>
  (test-equal (term (run-normal ,p-triv-3))
              (term ((< ,mt1-1 7 >))))
  ; (| f(x::Int64)="f-int" ; 2+2 |) -->* <f(x::Int64)="f-int", 4>
  (test-equal (term (run-normal ,p-triv-4))
              (term ((< ,mt1-1 4 >))))

  ; (| print("I'm print") |) -->* nothing
  (displayln "*** p-primop-1")
  (test-equal (term (run-normal ,p-primop-1))
              (term ((< ∅ nothing >))))
  ; (| print(55) ; print(-3 + -2) |) -->* nothing
  (displayln "*** p-primop-2")
  (test-equal (term (run-normal ,p-primop-2))
              (term ((< ∅ nothing >))))
  ; (| print(660) ; print(-1 + -3) ; -6 |) -->* -6
  (displayln "*** p-primop-3-0")
  (test-equal (term (run-normal ,p-primop-3-0))
              (term ((< ∅ -6 >))))
  ; (| print(66) ; (| print(-3 + -3) ; -6 |) |) -->* -6
  (displayln "*** p-primop-3")
  (test-equal (term (run-normal ,p-primop-3))
              (term ((< ∅ -6 >))))
  ; (| (| print(77) ; print(-3 + -4) ; |) -6 |) -->* -6
  (displayln "*** p-primop-4")
  (test-equal (term (run-normal ,p-primop-4))
              (term ((< ∅ -6 >))))
  ; (| maketrue(x::Bool) = (!x && true) || x; maketrue(false)|) -->* true
  (test-equal (term (run-to-r ,p-triv-5))
              (term true))
  ; (| !true |) -->* false
  (test-equal (term (run-to-r ,p-triv-6))
              (term false))
  ; (| true && true |) -->* true
  (test-equal (term (run-to-r ,p-triv-7))
              (term true))
  ; (| true || false |) -->* true
  (test-equal (term (run-to-r ,p-triv-8))
              (term true))
  ; (| get1or2(x::Bool) = x ? 1 : 2; get1or2(true) + get1or2(false)|) -->* 3
  (test-equal (term (run-to-r ,p-triv-9))
              (term 3))
  ; (| get1or2(x::Bool) = x ? 1 : 2; get1or2(true)|) -->* 1
  (test-equal (term (run-to-r ,p-triv-10))
              (term 1))
  ; (| get1or2(x::Bool) = x ? 1 : 2; get1or2(false)|) -->* 2
  (test-equal (term (run-to-r ,p-triv-11))
              (term 2))
  ; (| if 1==1 then 3 else 4 |) -->* 3
  (test-equal (term (run-to-r ,if-eq)) (term 3))
;; --------------------------------------------------
;; Error States
;; --------------------------------------------------

  ; <∅, (|x|)> -->e <∅, var-err>
  (test-equal (term (run-error (< ∅ ,p-fvar-1 >)))
              (term ((< ∅ var-err >))))
  ; <∅, (|+ 1|)> -->e <∅, prim-err>
  (test-equal (term (run-error (< ∅ ,p-+bad-1 >)))
              (term ((< ∅ prim-err >))))
  ; <∅, (|true + 1|)> -->e <∅, prim-err>
  (test-equal (term (run-error (< ∅ ,p-+bad-2 >)))
              (term ((< ∅ prim-err >))))
  ; (| true ! true |) -->* <∅, prim-err>
  (test-equal (term (run-error (< ∅ ,toomanyargs >)))
              (term ((< ∅ prim-err >))))
  ; (| && |) -->* <∅, prim-err>
  (test-equal (term (run-error (< ∅ ,toofewargs >)))
              (term ((< ∅ prim-err >))))
  ; ; (| if 2 then 1 else 1 |) -->* < ∅ type-err >
  (test-equal (term (run-error (< ∅ ,if-type-err-2 >)))
              (term ((< ∅ type-err >))))
;; --------------------------------------------------
;; Full Evaluation
;; --------------------------------------------------

;; ------------------- Trivial/primop programs

  ; (| 5 |) -->* 5
  (test-equal (term (run ,p-triv-1))
              (term ((< ∅ 5 >))))
  ; (| print(...); print(...) |) -->* nothing
  (displayln "*** p-primop-5")
  (test-equal (term (run ,p-primop-5))
              (term ((< ∅ nothing >))))

  ; (| 5 |) -->* 5
  (test-equal (term (run-to-r ,p-triv-1)) (term 5))
  
;; ------------------- Erroneous programs

  ; (| x |) -->* <∅, var-err>
  (test-equal (term (run ,p-fvar-1))
              (term ((< ∅ var-err >))))
  ; (| true + 1 |) -->* <∅, prim-err>
  (test-equal (term (run ,p-+bad-2))
              (term ((< ∅ prim-err >))))

  ; (| x |) -->* var-err
  (test-equal (term (run-to-r ,p-fvar-1)) (term var-err))

  ; (| f(1) |) -->* var-err
  (test-equal (term (run ,p-nomd-1))
              (term ((< ∅ var-err >))))
  ; (| f() = 0 ; f(1) |) -->* err-no-method
  (test-equal (term (run ,p-nomd-2))
              (term ((< ,mt0-1 err-no-method >))))
  ; (| true(1) |) -->* call-err
  (test-equal (term (run ,p-nclbl-1))
              (term ((< ∅ call-err >))))

  ; (| f(x) = (k() = x ; x + k()) ; f(42) |) -->* err-no-method
  (test-equal (term (run ,p-undefm-1))
              (term ((< ,mt3-2-1 err-no-method >))))

  ; (| f(x) = (k() = x ; x + k()) ; f(42) |) -->* err-no-method
  (test-equal (term (run-to-r ,p-undefm-1)) (term err-no-method))
  ; (| true ! true |) -->* prim-err
  (test-equal (term (run-to-r ,toomanyargs)) (term prim-err))
  ; (| && |) -->* prim-err
  (test-equal (term (run-to-r ,toofewargs)) (term prim-err))
  ; (| if 1+1 then 1 else 1 |) -->* type-err
  (test-equal (term (run-to-r ,if-type-err)) (term type-err))
  
;; ------------------- Simple programs

  ; (| f(x)=0 |) -->* (mval "f")
  (test-equal (term (run ,p-simple-1))
              (term ((< (,ftop0 • ∅) (mval "f") >))))
  ; (| f(x)=0 ; f(1) |) -->* 0
  (test-equal (term (run ,p-simple-2))
              (term ((< (,ftop0 • ∅) 0 >))))
  ; (| inc(x::Int64)=x+1 ; inc(10) |) -->* 11
  (test-equal (term (run ,p-simple-3))
              (term ((< (,incint • ∅) 11 >))))
  ; (| f(x)=666 ; print(f(0)) |) -->* nothing
  (displayln "*** p-simple-4")
  (test-equal (term (run ,p-simple-4))
              (term ((< (,ftop666 • ∅) nothing >))))

  ; (| f(x)=0 ; f(x::Int64)="f-int" ; f(1) |) -->* "f-int"
  (test-equal (term (run ,p-simple-5-1))
              (term ((< (,fint-str • (,ftop0 • ∅)) "f-int" >))))
  ; (| f(x::Int64)="f-int" ; f(x)=0 ; f(1) |) -->* "f-int"
  (test-equal (term (run ,p-simple-5-2))
              (term ((< (,ftop0 • (,fint-str • ∅)) "f-int" >))))
  ; (| f(x)=0 ; f(x::Int64)="f-int" ; f(3.14) |) -->* 0
  (test-equal (term (run ,p-simple-5-3))
              (term ((< (,fint-str • (,ftop0 • ∅)) 0 >))))
  
  ; (| f(x)=0 ; f(x)=666 ; f(1) |) -->* 666
  (test-equal (term (run ,p-simple-5-4))
              (term ((< (,ftop666 • (,ftop0 • ∅)) 666 >))))
  ; (| f(x)=666 ; f(x)=0 ; f(1) |) -->* 0
  (test-equal (term (run ,p-simple-5-5))
              (term ((< (,ftop0 • (,ftop666 • ∅)) 0 >))))

  ; (| (f(x) = (| print(1010) |) ; -1010) ; f(1) |) -->* -1010
  (test-equal (term (run ,p-simple-6-1))
              (term ((< (,ftop-print-1010 • ∅) -1010 >))))

  ; (| (f(f) = (print(f) ; 55) ; f(0) |) -->* 55
  (displayln "*** p-simple-7-1")
  (test-equal (term (run ,p-simple-7-1))
              (term ((< (,ftop-printf • ∅) 55 >))))
  ; (| f() = "f-no-arg" ; f(g) = g() ; f(f) |) -->* "f-no-arg"
  (test-equal (term (run ,p-simple-7-2))
              (term ((< (,ftop-callg • (,fnoarg-str • ∅)) "f-no-arg" >))))
  ; (| f() = "f-no-arg" ; f(g) = (g()="g-no-arg"; g()) ; f(f) |) -->* "f-no-arg"
  (test-equal (term (run ,p-simple-7-3))
              (term ((< (,gnoarg-str • (,ftop-defg-callg • (,fnoarg-str • ∅))) "f-no-arg" >))))
  ; (| add(x, y) = x + y; addxy(((|f(x)=333|);1),((|f(x)=666|);2)) |) -->* 3
  (test-equal (term (run ,order-of-eval-mcall))
              (term ((< ,mt5-1 3 >))))
  ; (| (|f(x)=333|);1) + ((|f(x)=666|);2) |) --->* 3
  (test-equal (term (run ,order-of-eval-pcall))
              (term ((< ,mt5-2 3 >))))

;; ------------------- Eval/world-age programs
  
  ; (| f(x)=0 ; g(y)=...; g(1) |) -->* 0
  (displayln "*** p1")
  (test-predicate (alpha-eq? (term (run ,p1)))
                  (term ((< (,ftop333 • (,gtop-deff-callf • (,ftop0 • ∅))) 0 >))))

  ; (| g(y)=...; g(1) |) -->* err-no-method
  (test-predicate (alpha-eq? (term (run (evalg (seq ,gtop-deff-callf (mcall (mval "g") 1))))))
                  (term ((< (,ftop333 • (,gtop-deff-callf • ∅)) err-no-method >))))

  ; (| f(x)=0 ; g(y)=((|f(x)=333|);f(y)) ; g(0) + g(0) |) -->* 333
  (test-predicate (alpha-eq? (term (run ,p2-1)))
                  (term ((< (,ftop333 • (,ftop333 • (,gtop-deff333 • (,ftop0 • ∅)))) 333 >))))
  ; (| f(x)=0 ; g(y)=((|f(x)=333|);f(y)) ; g(0) ; g(0) + g(0) |) -->* 333
  (test-predicate (alpha-eq? (term (run ,p2-2)))
                  (term ((< (,ftop333 • (,ftop333
                                         • (,ftop333 • (,gtop-deff333 • (,ftop0 • ∅))))) 666 >))))

  ; (| f(x) = (k() = x ; x + k()) ; k() = 2 ; f(42) |) -->* 44
  (test-predicate (alpha-eq? (term (run ,p3-1)))
                  (term ((< ,mt3-3-2 44 >))))
  ; (| f(x) = (k() = x ; x + k()) ; k() = 2 ; f(42) ; f(42) |) -->* 84
  (test-predicate (alpha-eq? (term (run ,p3-2)))
                  (term ((< ,mt3-4-2 84 >))))
  
;; ------------------- Litmus

  ; (| g() = ( k()=2;k() ) ; g() |) -->* err-no-method
  (test-predicate (alpha-eq? (term (run ,plitmus-1)))
                  (term ((< (,mdef-k-2 • (,mdef-g-defcallk-1 • ∅)) err-no-method >))))
  ; (| g() = ( k()=2;(|k()|) ) ; g() |) -->* 2
  (test-predicate (alpha-eq? (term (run ,plitmus-2)))
                  (term ((< (,mdef-k-2 • (,mdef-g-defcallk-2 • ∅)) 2 >))))

  ; (| g() = ( k()=2;k() ) ; g() |) -->* err-no-method
  (test-equal (term (run-to-r ,plitmus-1)) (term err-no-method))
  ; (| g() = ( k()=2;(|k()|) ) ; g() |) -->* 2
  (test-equal (term (run-to-r ,plitmus-2)) (term 2))

  ; (| r2()=r1(); m()=((|r1()=2|);r2()); m() -->* err-no-method
  (test-equal (term (run-to-r ,plitmus-middle-1)) (term err-no-method))
  ; (| r3()=r4(); m()=((|r4()=2|);(|r3()|)); m()
  (test-equal (term (run-to-r ,plitmus-middle-2)) (term 2))

  ; (| f(y)=(|x|) ; f(0) |) -->* var-err
  (test-equal (term (run-to-r ,plitmus-undef-var-1)) (term var-err))
  
;; ==================================================
  (displayln "********** TESTS END")
  (test-results) ; print results
)
