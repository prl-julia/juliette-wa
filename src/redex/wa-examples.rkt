#lang racket
(require redex)

(provide (all-defined-out)) ; export all definitions

;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Surface Language Examples
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Types
;; ==================================================

;; --------------------------------------------------
;; Simple Types
;; --------------------------------------------------

(define tInt  (term Int64))
(define tFlt  (term Float64))
(define tNum  (term Number))

(define tStr  (term String))
(define tBool (term Bool))
(define tSkip (term Nothing))

(define tTop  (term Any))
(define tBot  (term Bot))

; method type tage
(define (tMethod name) (term (mtag ,name)))

;; --------------------------------------------------
;; Tuple Types
;; --------------------------------------------------

(define tsEmpty (term ()))
(define tsInt (term (,tInt)))
(define tsTop (term (,tTop)))
(define tsIntInt (term (,tInt ,tInt)))
(define tsTopTop (term (,tTop ,tTop)))

;; ==================================================
;; Values
;; ==================================================

;; ------------------- Simple values

(define i5 (term 5))
(define fpi (term 3.14))
(define btrue (term true))
(define bfalse (term false))

(define skip (term nothing))

;; ------------------- Method values

(define mf   (term (mval "f")))
(define mg   (term (mval "g")))
(define mh   (term (mval "h")))
(define mk   (term (mval "k")))
(define minc (term (mval "inc")))

;; ==================================================
;; Simple Expressions
;; ==================================================

;; ------------------- Primop calls

; x + 1
(define incx      (term (pcall + x 1)))
; -3 + -4
(define n3plusn4  (term (pcall + -3 -4)))
; print(55)
(define print55   (term (pcall print 55)))
; print(66)
(define print66   (term (pcall print 66)))
; print(660)
(define print660  (term (pcall print 660)))
; print(77)
(define print77   (term (pcall print 77)))
; print(-3 + -4)
(define printn3plusn4 (term (pcall print ,n3plusn4)))
; !true
(define nottrue (term (pcall ! ,btrue)))
; true && true
(define trueandtrue (term (pcall && ,btrue ,btrue)))
; true || false
(define trueorfalse (term (pcall || ,btrue ,bfalse)))

;; ------------------- Function calls

; f(0)
(define callf0    (term (mcall f 0)))
; f(1)
(define callf1    (term (mcall f 1)))
(define callmf1   (term (mcall ,mf 1))) ; direct call through value
; f(3.14)
(define callfpi   (term (mcall f 3.14)))
; f(x)
(define callfx    (term (mcall f x)))
(define callmfx    (term (mcall ,mf x))) ; direct call through value
; f(y)
(define callfy    (term (mcall f y)))
; f(42)
(define callf42   (term (mcall f 42)))

; g(0)
(define callg0    (term (mcall g 0)))

; inc(10)
(define callinc10 (term (mcall inc 10)))

; print(f(0))
(define printf0   (term (pcall print ,callf0)))

; f()
(define callf     (term (mcall f)))
; k()
(define callk     (term (mcall k)))
(define callmk    (term (mcall ,mk))) ; direct call through value
; g()
(define callg     (term (mcall g)))

;; ------------------- Sequences

; print("print-seq-left") ; print("print-seq-right")
(define seq-prints
  (term (seq (pcall print "print-seq-left") (pcall print "print-seq-right"))))

;; ==================================================
;; Method Definitions
;; ==================================================

; inc(x :: Int64) = x + 1
(define incint
  (term (mdef "inc" ((:: x ,tInt)) ,incx)))

; f(x :: Int64) = "f-int"
(define fint-str
  (term (mdef "f" ((:: x ,tInt))  "f-int")))
; f(x :: Int64) = "f-int-new"
(define fint-str-new
  (term (mdef "f" ((:: x ,tInt))  "f-int-new")))
; f(x :: Bool) = "f-bool"
(define fbool-str
  (term (mdef "f" ((:: x ,tBool)) "f-bool")))
; f(x :: Number) = "f-num"
(define fnum-str
  (term (mdef "f" ((:: x ,tNum))  "f-num")))

; f(x :: Bool, y :: Int64) = "f-int-bool"
(define fboolint-str
  (term (mdef "f" ((:: x ,tBool) (:: y ,tInt)) "f-int-bool")))

; f(x :: Int64, y :: Number) = "f-int-num"
(define fintnum-str
  (term (mdef "f" ((:: x ,tInt) (:: y ,tNum)) "f-int-num")))
; f(x :: Number, y :: Int64) = "f-num-int"
(define fnumint-str
  (term (mdef "f" ((:: x ,tNum) (:: y ,tInt)) "f-num-int")))

; f(y :: Bool) = "f-bool"
(define fybool-str
  (term (mdef "f" ((:: y ,tBool)) "f-bool")))
; g(x :: Bool) = "f-bool"
(define gbool-str
  (term (mdef "g" ((:: x ,tBool)) "g-bool")))

; h(x :: Int64) = f(x)
(define hint-fx
  (term (mdef "h" ((:: x ,tInt)) ,callfx)))

; f() = 0
(define mdef-f-0
  (term (mdef "f" () 0)))
; f(x) = 0
(define ftop0
  (term (mdef "f" ((:: x ,tTop)) 0)))
; f(x) = 333
(define ftop333
  (term (mdef "f" ((:: x ,tTop)) 333)))
; f(x) = 666
(define ftop666
  (term (mdef "f" ((:: x ,tTop)) 666)))

; f(x) = (| print(1010) |) ; -1010
(define ftop-print-1010
  (term (mdef "f" ((:: x ,tTop)) (seq (evalg (pcall print 1010)) -1010))))

; k() = 2
(define mdef-k-2
  (term (mdef "k" () 2)))
; k() = x
(define mdef-k-x
  (term (mdef "k" () x)))
; k() = 42
(define mdef-k-42
  (term (mdef "k" () 42)))

; f(x) = x + k()
(define ftop-plusxk
  (term (mdef "f" ((:: x ,tTop)) (pcall + x ,callk))))
; f(x) = x + 2
(define ftop-plusx2
  (term (mdef "f" ((:: x ,tTop)) (pcall + x 2))))
; f(x) = (k() = x ; x + k())
(define ftop-defk-plusxk
  (term (mdef "f" ((:: x ,tTop)) (seq ,mdef-k-x (pcall + x ,callk)))))
; f(x) = (k() = x ; x + 2)
(define ftop-defk-plusx2
  (term (mdef "f" ((:: x ,tTop)) (seq ,mdef-k-x (pcall + x 2)))))

; g() = k() + 5
(define mdef-g-plusk5
  (term (mdef "g" () (pcall + ,callk 5))))

; h(x) = f(x) + g()
(define htop-plusfg
  (term (mdef "h" ((:: x ,tTop)) (pcall + ,callfx ,callg))))

; add(x, y) = x + y
(define addxy
  (term (mdef "add" ((:: x ,tTop) (:: y ,tTop)) (pcall + x y))))

; f(f) = (print(f) ; 55)
(define ftop-printf
  (term (mdef "f" ((:: f ,tTop)) (seq (pcall print f) 55))))
; f() = "f-no-arg"
(define fnoarg-str
  (term (mdef "f" () "f-no-arg")))
; g() = "g-no-arg"
(define gnoarg-str
  (term (mdef "g" () "g-no-arg")))
; f(g) = g()
(define ftop-callg
  (term (mdef "f" ((:: g ,tTop)) (mcall g))))
; f(g) = (g()="g-no-arg" ; g())
(define ftop-defg-callg
  (term (mdef "f" ((:: g ,tTop)) (seq ,gnoarg-str (mcall g)))))

;; ==================================================
;; More Expressions
;; ==================================================

; f(x)=666 ; print(f(0))
(define seq-ftop333-printf0 (term (seq ,ftop333 ,printf0)))
; (|f(x)=333|);2
(define f333-seq (term (seq (evalg ,ftop333) 1)))
; (|f(x)=666|);2
(define f666-seq (term (seq (evalg ,ftop666) 2)))
; addxy(((|f(x)=333|);1),((|f(x)=666|);2))
(define call-order-addxy (term (mcall add ,f333-seq ,f666-seq)))


;; ==================================================
;; More Definitions
;; ==================================================

; g(y) = ( (| f(x)=333 ; print(f(0)) |) ; f(y) )
(define gtop-deff-callf
  (term (mdef "g" ((:: y ,tTop))
              (seq (evalg ,seq-ftop333-printf0) ,callfy))))

; g(y) = ( (| f(x)=333 |) ; f(y) )
(define gtop-deff333
  (term (mdef "g" ((:: y ,tTop))
              (seq (evalg ,ftop333) ,callfy))))

; (!x && true) || x
(define maketrue (term (pcall || (pcall && (pcall ! x) true) x)))
; maketrue(x::Bool) = (!x && true) || x
(define maketrue-mdef (term (mdef "maketrue" ((:: x ,tBool)) ,maketrue)))
; x ? 1 : 2
(define get1or2 (term (if x 1 2)))
; get1or2(x::Bool) = x ? 1 : 2
(define get1or2-mdef (term (mdef "get1or2" ((:: x ,tBool)) ,get1or2)))
; 1+1
(define 1-plus-1 (term (pcall + 1 1)))
; 1==1
(define 1-eq-1 (term (pcall == 1 1)))

;; ==================================================
;; Programs
;; ==================================================

;; ------------------- Trivial programs

; (| 5 |)
(define p-triv-1  (term (evalg 5)))
; (| skip ; -5 |)
(define p-triv-2  (term (evalg (seq ,skip -5))))
; (| f(x::Int64)="f-int" ; 7 |)
(define p-triv-3  (term (evalg (seq ,fint-str 7))))
; (| f(x::Int64)="f-int" ; 2+2 |)
(define p-triv-4  (term (evalg (seq ,fint-str (pcall + 2 2)))))
; (| maketrue(x::Bool) = (!x && true) || x; maketrue(false)|)
(define p-triv-5 (term (evalg (seq ,maketrue-mdef (mcall maketrue ,btrue)))))
; (| !true |)
(define p-triv-6 (term (evalg ,nottrue)))
; (| true && true |)
(define p-triv-7 (term (evalg ,trueandtrue)))
; (| true || false |)
(define p-triv-8 (term (evalg ,trueorfalse)))
; (| get1or2(x::Bool) = x ? 1 : 2; get1or2(true) + get1or2(false)|)
(define p-triv-9 (term (evalg (seq ,get1or2-mdef
                                   (pcall + (mcall get1or2 ,btrue) (mcall get1or2 ,bfalse))))))
; (| get1or2(x::Bool) = x ? 1 : 2; get1or2(true)|)
(define p-triv-10 (term (evalg (seq ,get1or2-mdef (mcall get1or2 ,btrue)))))
; (| get1or2(x::Bool) = x ? 1 : 2; get1or2(false)|)
(define p-triv-11 (term (evalg (seq ,get1or2-mdef (mcall get1or2 ,bfalse)))))

;; ------------------- Print-sequence programs

; (| print("I'm print") |)
(define p-primop-1  (term (evalg (pcall print "I'm print"))))
; (| print(55) ; print(-3 + -2) |)
(define p-primop-2  (term (evalg (seq ,print55 (pcall print (pcall + -3 -2))))))
; (| print(660) ; print(-1 + -3) ; -6 |)
(define p-primop-3-0 (term (evalg (seq ,print660 (seq (pcall print (pcall + -1 -3)) -6)))))
; (| print(66) ; (| print(-3 + -3) ; -6 |) |)
(define p-primop-3  (term (evalg (seq ,print66 (evalg (seq (pcall print (pcall + -3 -3)) -6))))))
; (| (| print(77) ; print(-3 + -4) ; |) -6 |)
(define p-primop-4  (term (evalg (seq (evalg (seq ,print77 ,printn3plusn4)) -6))))
; (| print(...); print(...) |)
(define p-primop-5 (term (evalg ,seq-prints)))

;; ------------------- Erroneous programs

; (| x |)
(define p-fvar-1 (term (evalg x)))
; (| + 1 |)
(define p-+bad-1 (term (evalg (pcall + 1))))
; (| true + 1 |)
(define p-+bad-2 (term (evalg (pcall + true 1))))

; (| f(1) |)
(define p-nomd-1 (term (evalg ,callf1)))
; (| f() = 0 ; f(1) |)
(define p-nomd-2 (term (evalg (seq ,mdef-f-0 ,callf1))))
; (| true(1) |)
(define p-nclbl-1 (term (evalg (mcall true 1))))

; (| f(x) = (k() = x ; x + k()) ; f(42) |)
(define p-undefm-1 (term (evalg (seq ,ftop-defk-plusxk ,callf42))))

; (| true ! true |)
(define toomanyargs (term (evalg (pcall ! ,btrue ,btrue))))
; (| && |)
(define toofewargs (term (evalg (pcall &&))))
; (| if 1+1 then 1 else 1 |)
(define if-type-err (term (evalg (if ,1-plus-1 1 1))))
; (| if 2 then 1 else 1 |)
(define if-type-err-2 (term (evalg (if 2 1 1))))
; (| if 1==1 then 3 else 4 |)
(define if-eq (term (evalg (if ,1-eq-1 3 4))))

;; ------------------- Simple programs

; (| f(x)=0 |)
(define p-simple-1 (term (evalg ,ftop0)))
; (| f(x)=0 ; f(1) |)
(define p-simple-2 (term (evalg (seq ,ftop0 ,callf1))))
; (| inc(x::Int64)=x+1 ; inc(10) |)
(define p-simple-3 (term (evalg (seq ,incint ,callinc10))))
; (| f(x)=666 ; print(f(0)) |)
(define p-simple-4 (term (evalg (seq ,ftop666 ,printf0))))

; (| f(x)=0 ; f(x::Int64)="f-int" ; f(1) |)
(define p-simple-5-1 (term (evalg (seq ,ftop0 (seq ,fint-str ,callf1)))))
; (| f(x::Int64)="f-int" ; f(x)=0 ; f(1) |)
(define p-simple-5-2 (term (evalg (seq ,fint-str (seq ,ftop0 ,callf1)))))
; (| f(x)=0 ; f(x::Int64)="f-int" ; f(3.14) |)
(define p-simple-5-3 (term (evalg (seq ,ftop0 (seq ,fint-str ,callfpi)))))

; (| f(x)=0 ; f(x)=666 ; f(1) |)
(define p-simple-5-4 (term (evalg (seq ,ftop0 (seq ,ftop666 ,callf1)))))
; (| f(x)=666 ; f(x)=0 ; f(1) |)
(define p-simple-5-5 (term (evalg (seq ,ftop666 (seq ,ftop0 ,callf1)))))

; (| (f(x) = (| print(1010) |) ; -1010) ; f(1) |)
(define p-simple-6-1 (term (evalg (seq ,ftop-print-1010 ,callf1))))

; (| f(f) = (print(f) ; 55) ; f(0) |)
(define p-simple-7-1 (term (evalg (seq ,ftop-printf ,callf0))))
; (| f() = "f-no-arg" ; f(g) = g() ; f(f) |)
(define p-simple-7-2 (term (evalg (seq ,fnoarg-str (seq ,ftop-callg (mcall f f))))))
; (| f() = "f-no-arg" ; f(g) = (g()="g-no-arg"; g()) ; f(f) |)
(define p-simple-7-3
  (term (evalg (seq ,fnoarg-str (seq ,ftop-defg-callg (mcall f f))))))
; (| add(x, y) = x + y; addxy(((|f(x)=333|);1),((|f(x)=666|);2)) |)
(define order-of-eval-mcall (term (evalg (seq ,addxy ,call-order-addxy))))
; (| (|f(x)=333|);1) + ((|f(x)=666|);2) |)
(define order-of-eval-pcall (term (evalg (pcall + ,f333-seq ,f666-seq))))

;; ------------------- Eval/world-age programs

; (| f(x)=0 ; g(y)=...; g(1) |)
(define p1
  (term (evalg (seq ,ftop0 (seq ,gtop-deff-callf (mcall g 1))))))

; (| f(x)=0 ; g(y) = ( (| f(x) = 333 |) ; f(y) ) ; g(0) + g(0) |)
(define p2-1
  (term (evalg (seq ,ftop0 (seq ,gtop-deff333 (pcall + ,callg0 ,callg0))))))
; (| f(x)=0 ; g(y) = ( (| f(x) = 333 |) ; f(y) ) ; g(0) ; g(0) + g(0) |)
(define p2-2
  (term (evalg (seq ,ftop0 (seq ,gtop-deff333 (seq ,callg0 (pcall + ,callg0 ,callg0)))))))

; (| f(x) = (k() = x ; x + k()) ; k() = 2 ; f(42) |)
(define p3-1
  (term (evalg (seq ,ftop-defk-plusxk (seq ,mdef-k-2 ,callf42)))))
; (| f(x) = (k() = x ; x + k()) ; k() = 2 ; f(42) ; f(42) |)
(define p3-2
  (term (evalg (seq ,ftop-defk-plusxk (seq ,mdef-k-2 (seq ,callf42 ,callf42))))))

;; ------------------- Litmus

; g() = ( k()=2 ; k() )
(define mdef-g-defcallk-1
  (term (mdef "g" () (seq (evalg ,mdef-k-2) ,callk))))
; g() = ( k()=2 ; (| k() |) )
(define mdef-g-defcallk-2
  (term (mdef "g" () (seq ,mdef-k-2 (evalg ,callk)))))

; (| g() = ( k()=2;k() ) ; g() |)
(define plitmus-1
  (term (evalg (seq ,mdef-g-defcallk-1 ,callg))))
; (| g() = ( k()=2;(|k()|) ) ; g() |)
(define plitmus-2
  (term (evalg (seq ,mdef-g-defcallk-2 ,callg))))

; (| r2()=r1(); m()=((|r1()=2|);r2()); m()
(define plitmus-middle-1
  (term (evalg (seq (seq
          (mdef "r2" () (mcall r1))
          (mdef "m"  () (seq 
                         (evalg (mdef "r1" () 2))
                         (mcall r2))))
          (mcall m)))))
; (| r3()=r4(); m()=((|r4()=2|);(|r3()|)); m()
(define plitmus-middle-2
  (term (evalg (seq (seq
          (mdef "r3" () (mcall r4))
          (mdef "m"  () (seq 
                         (evalg (mdef "r4" () 2))
                         (evalg (mcall r3)))))
          (mcall m)))))

; (| f(y)=(|x|) ; f(0) |)
(define plitmus-undef-var-1
  (term (evalg (seq (mdef "f" ((:: y ,tTop)) (evalg x)) ,callf0))))

;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Language Semantics Examples
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Method Tables
;; ==================================================

; ∅
(define mtempty (term ∅))

; f() = 0
(define mt0-1 (term (,mdef-f-0 • ∅)))

; f(x::Int64)="..."
(define mt1-1   (term (,fint-str • ∅)))
; f(x::Bool)="..." • f(x::Int64)="..."
(define mt1-2   (term (,fbool-str • ,mt1-1)))
; h(x::Int)=f(x) • f(x::Bool)="..." • f(x::Int64)="..."
(define mt1-3   (term (,hint-fx • ,mt1-2)))

; f(x::Int64)="..." • h(x::Int)=f(x) • f(x::Bool)="..." • f(x::Int64)="..."
(define mt1-4-1 (term (,fint-str-new • ,mt1-3)))
; f(x::Int64)="..." • f(x::Number)="..." • h(x::Int)=f(x) • ...
(define mt1-4-2 (term (,fint-str-new • (,fnum-str • ,mt1-3))))

; f(y::Bool)="..." • f(x::Int64)="..." • f(x::Number)="..." • h(x::Int)=f(x) • ...
(define mt1-5   (term (,fybool-str • ,mt1-4-2)))
; f(x::Bool,y::Int64)="..." • f(y::Bool)="..." • f(x::Int64)="..." • ...
(define mt1-6   (term (,fboolint-str • ,mt1-5)))

; f(x::Number,y::Int64)="..." • f(x::Int64,y::Number)="..." • ...
(define mt1-7   (term (,fnumint-str • (,fintnum-str • ,mt1-6))))

; k() = 2
(define mt2-1 (term (,mdef-k-2 • ∅)))
; k() = 2 ; f(x) = x + k()
(define mt2-2 (term (,ftop-plusxk • ,mt2-1)))
; f(x) = x + k() ; k() = 2
(define mt2-3 (term (,mdef-k-2 • (,ftop-plusxk • ∅))))
; f(x) = x + k() ; k() = 2 ; g() = k() + 5
(define mt2-4 (term (,mdef-g-plusk5 • ,mt2-3)))
; f(x) = x + k() ; k() = 2 ; g() = k() + 5 ; h(x) = f(x) + g()
(define mt2-5 (term (,htop-plusfg • ,mt2-4)))
; f(x) = x + k() ; k() = 2 ; h(x) = f(x) + g() ; g() = k() + 5
(define mt2-6 (term (,mdef-g-plusk5 • (,htop-plusfg • ,mt2-3))))

; f(x) = x + k()
(define mt2-1-1 (term (,ftop-defk-plusxk • ∅)))
; f(x) = x + k() ; k() = 2
(define mt2-2-1 (term (,mdef-k-2 • ,mt2-1-1)))

; f(x) = (k() = x ; x + k())
(define mt3-1 (term (,ftop-defk-plusxk • ∅)))
; f(x) = (k() = x ; x + k()) ; k() = 42
(define mt3-2-1 (term (,mdef-k-42 • ,mt3-1)))
; f(x) = (k() = x ; x + k()) ; k() = 2 
(define mt3-2-2 (term (,mdef-k-2 • ,mt3-1)))
; f(x) = (k() = x ; x + k()) ; k() = 2 ; k() = 42
(define mt3-3-2 (term (,mdef-k-42 • ,mt3-2-2)))
; f(x) = (k() = x ; x + k()) ; k() = 2 ; k() = 42 ; k() = 42
(define mt3-4-2 (term (,mdef-k-42 • ,mt3-3-2)))

; f(x::Any)=666 • f(x::Any)=333 • addxy(x::Any,y::Any)="..."
(define mt5-1 (term (,ftop666 • (,ftop333 • (,addxy • ∅)))))
; f(x::Any)=666 • f(x::Any)=333
(define mt5-2 (term (,ftop666 • (,ftop333 • ∅))))
