#lang racket
(require redex)

(require "wa-surface.rkt")  ; import surface language
(require "wa-full.rkt")     ; import language semantics
(require "wa-examples.rkt") ; import examples

(provide (all-defined-out)) ; export all definitions

;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Language with Optimizations
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Grammar
;; ==================================================

(define-extended-language WA-opt WA-full

  ;; simple optimization context
  [E ::=
      hole        ; □
      (seq E e)  ; E;e
      (seq e E)  ; e;E
      (mcall e ... E e ...)    ;  e(e..., E, e...)
      (pcall op e ... E e ...) ; op(e..., E, e...)
      ]

  ; expression in local evaluation
  [mte ::= (evalt MT E)]

)

;; ==================================================
;; Optimization
;; ==================================================

;; --------------------------------------------------
;; Expression
;; --------------------------------------------------

;; TODO: environment

;; -------------------- Relation

;; (| e |)_MT ~~> (| e' |)_MT
(define ->opt-expr
  (reduction-relation
   WA-opt
   #:domain (evalt MT e)
   ; (| E[v;e] |)_MT ~~> (| E[e] |)_MT
   [--> (evalt MT (in-hole E (seq v e)))
        (evalt MT (in-hole E e))
        OE-Seq]
   ; (| !Ω(op) E[op(v...)] |)_MT ~~> (| E[v'] |)_MT
   [--> (evalt MT (in-hole E (pcall op v ...)))
        (evalt MT (in-hole E v_r))
        ; primop does not have side-effects
        (where #f (side-eff-primop op))
        ; primop runs successfully
        (where v_r (run-primop op v ...))
        OE-Primop]
   ; (| E[x] |)_MT if x \in dom(MT) ~~> (| E[(mval "x")] |)_MT
   [--> (evalt MT (in-hole E x))
        (evalt MT (in-hole E (mval mname)))
        (where #t (inMTdom MT x))
        (where mname ,(~a (term x)))
        OE-VarMethod]
   ; (| E[m(v...)] |)_MT ~~> (| E[e[x...:=v...]] |)_MT
   [--> (evalt MT (in-hole E (mcall (mval mname) v ...)))
        ; inline the body of the best method
        (evalt MT (in-hole E (subst-n e (x v) ...)))
        ; take tags of values
        (where (σ ...) (typeof-tuple (v ...)))
        ; find the best applicable method
        (where (mdef mname ((:: x _) ...) e) (getmd MT mname (σ ...)))
        OE-CallLocal]
))

;; -------------------- Tests

; (| nothing ; 2 |)_∅ ~~> (| 2 |)_∅
(test-equal (apply-reduction-relation* ->opt-expr (term (evalt ,mtempty (seq nothing 2))))
            (term ((evalt ∅ 2))))
; (| 1 + 1 |)_∅ ~~> (| 2 |)_∅
(test-equal (apply-reduction-relation* ->opt-expr (term (evalt ,mtempty (pcall + 1 1))))
            (term ((evalt ∅ 2))))
; (| 1 + 1 |)_MT ~~> (| 2 |)_MT
(test-equal (apply-reduction-relation* ->opt-expr (term (evalt ,mt1-1 (pcall + 1 1))))
            (term ((evalt ,mt1-1 2))))
; (| f(1) |)_{f(x::Int)="f-int"} ~~> (| "f-int" |)_{f(x::Int)="f-int"}
(test-equal (apply-reduction-relation* ->opt-expr (term (evalt ,mt1-1 ,callmf1)))
            (term ((evalt ,mt1-1 "f-int"))))
; (| x ; f(1) |)_{f(x::Int)="f-int"} ~~> (| "f-int" |)_{f(x::Int)="f-int"}
(test-equal (apply-reduction-relation* ->opt-expr (term (evalt ,mt1-1 (seq x ,callmf1))))
            (term ((evalt ,mt1-1 (seq x "f-int")))))
; (| k() + k() |)_{k() = 2} ~~> (| 4 |)_{k() = 2}
(test-equal (apply-reduction-relation* ->opt-expr (term (evalt ,mt2-1 (pcall + ,callmk ,callmk))))
            (term ((evalt ,mt2-1 4))))
; (| print(2) ; 1 + 1 |)_∅ ~~> (| print(2) ; 2 |)_∅
(test-equal (apply-reduction-relation*
               ->opt-expr (term (evalt ,mtempty (seq (pcall print 2) (pcall + 1 1)))))
            (term ((evalt ∅ (seq (pcall print 2) 2)))))

;; -------------------- Aux

;; Returns true if expression is optimizable
;; (i.e. e ~~>* e' and e' != e)
(define-metafunction WA-opt
  optimizable-expr : mte -> boolean
  ; optimized expression is different
  [(optimizable-expr (evalt MT e))
     #t
     (where ((evalt MT e_opt))
            ,(apply-reduction-relation* ->opt-expr (term (evalt MT e))))
     (where #f (expr-eq e e_opt))]
  ; otherwise, no mo optimization is possible
  [(optimizable-expr (evalt MT e))
     #f]
)

;; Returns true if method definition is optimizable
;; (i.e. body of the method is optimizable)
(define-metafunction WA-opt
  optimizable-md : MT md -> boolean
  [(optimizable-md MT (mdef mname ((:: x τ) ...) e))
   (optimizable-expr (evalt MT e))]
)

(test-equal (term (optimizable-expr (evalt ,mtempty (seq nothing 2)))) #t)
(test-equal (term (optimizable-expr (evalt ,mtempty 2)))               #f)

;; --------------------------------------------------
;; Table
;; --------------------------------------------------

;; -------------------- Relation

;; MT --> MT'
(define ->opt-tbl
  (reduction-relation
   WA-opt
   #:domain MT
   ; MT ~~> md • MT (start optimizing with the oldest md)
   ; where md is an optmized method from MT
   [--> MT
        ; add optimized method to the beginning of the table
        ((mdef mname ((:: x τ) ...) e_opt) • MT)
        ; take only newest methods
        (where (md md_1 ...) (latest MT))
        ; get details of the first method
        (where (mdef mname ((:: x τ) ...) e) md)
        ; optimize body (should be deterministic)
        (where ((evalt MT e_opt))
               ,(apply-reduction-relation* ->opt-expr (term (evalt MT e))))
        (where #f (expr-eq e e_opt)) ; make sure e_opt != e to stop recursion
        OT-ExtOldest]
   ; MT ~~> md • MT (start optimizing with the next)
   [--> MT
        ; add optimized method to the beginning of the table
        ((mdef mname ((:: x τ) ...) e_opt) • MT)
        ; take only newest methods
        (where (md_1 ... md md_2 ...) (latest MT))
        ; get details of the first optimizable method
        (where (mdef mname ((:: x τ) ...) e) md)
        ; optimize body (should be deterministic)
        (where ((evalt MT e_opt))
               ,(apply-reduction-relation* ->opt-expr (term (evalt MT e))))
        (where #f (expr-eq e e_opt)) ; make sure e_o != e to stop recursion
        ; make sure older methods are not optimizable
        (where (#f ...) ,(map (lambda (md) (term (optimizable-md MT ,md))) (term (md_1 ...))))
        OT-ExtNext]
))

;; -------------------- Tests

; ∅ ~~> ∅
(test-equal (apply-reduction-relation* ->opt-tbl mtempty)
            (term (,mtempty)))
; {k() = 2} ~~> {k() = 2}
(test-equal (apply-reduction-relation* ->opt-tbl mt2-1)
            (term (,mt2-1)))

; {k() = 2, f(x) = x + k()} ~~> {k() = 2, f(x) = x + k(), f(x) = x + 2}
(test-predicate (alpha-eq? (apply-reduction-relation* ->opt-tbl mt2-2))
                (term ((,ftop-plusx2 • ,mt2-2))))
; {f(x) = x + k(), k() = 2} ~~> {f(x) = x + k(), k() = 2, f(x) = x + 2}
(test-predicate (alpha-eq? (apply-reduction-relation* ->opt-tbl mt2-3))
                (term ((,ftop-plusx2 • ,mt2-3))))
; {f(x) = x + k(), k() = 2, g() = k() + 5} ~~>
; {f(x) = x + k(), k() = 2, g() = k() + 5, f(x) = x + 2, g() = 7}
(test-predicate (alpha-eq? (apply-reduction-relation* ->opt-tbl mt2-4))
                (term (((mdef "g" () 7) • (,ftop-plusx2 • ,mt2-4)))))
; {f(x) = x + k(), k() = 2, g() = k() + 5, h(x) = f(x) + g()} ~~>
; {f(x) = x + k(), k() = 2, g() = k() + 5, h(x) = f(x) + g(), f(x) = x + 2, g() = 7, h(x) = f(x) + 7}
(test-predicate (alpha-eq? (apply-reduction-relation* ->opt-tbl mt2-5))
                (term (((mdef "h" ((:: x ,tTop)) (pcall + ,callmfx 7)) • ((mdef "g" () 7) • (,ftop-plusx2 • ,mt2-5))))))
; {f(x) = x + k(), k() = 2, h(x) = f(x) + g(), g() = k() + 5} ~~>
; {f(x) = x + k(), k() = 2, h(x) = f(x) + g(), g() = k() + 5, h(x) = f(x) + 7, g() = 7}
(test-predicate (alpha-eq? (apply-reduction-relation* ->opt-tbl mt2-6))
                (term (((mdef "g" () 7) • ((mdef "h" ((:: x ,tTop)) (pcall + ,callmfx 7)) • (,ftop-plusx2 • ,mt2-6))))))

; {f(x) = (k() = x ; x + k()), k() = 2} ~~> {f(x) = (k() = x ; x + k()), k() = 2, f(x) = (k() = x ; x + 2)}
(test-predicate (alpha-eq? (apply-reduction-relation* ->opt-tbl mt3-2-2))
                (term ((,ftop-defk-plusx2 • ,mt3-2-2))))

;; --------------------------------------------------
;; Expression with Table
;; --------------------------------------------------

;; (| e |)_MT ~~> (| e' |)_MT'
(define ->opt-expr-tbl
  (reduction-relation
   WA-opt
   #:domain (evalt MT e)
   ; MT~~>MT', (|e|)_MT'~~>(|e'|)_MT' ~~> (|e'|)_MT'
   [--> (evalt MT e)
        (evalt MT_opt e_opt)
        ; optimize table
        (where (MT_opt) ,(apply-reduction-relation* ->opt-tbl  (term MT)))
        ; optimize expression in the optimized table
        (where ((evalt MT_opt e_opt)) ,(apply-reduction-relation* ->opt-expr (term (evalt MT_opt e))))
        ; stop recursion
        (where #f (expr-eq e_opt e))
        OET-All]
))

; (|f(42)|)_{f(x) = (k()=x ; x+k()) ; k()=2} ~~>
; (|(k()=42 ; 44)|)_{f(x)=(k()=x ; x+k()) ; k()=2 ; f(x)=(k()=x ; x+2)}
(test-predicate (alpha-eq? (apply-reduction-relation* ->opt-expr-tbl (term (evalt ,mt3-2-2 ,callf42))))
                (term ((evalt (,ftop-defk-plusx2 • ,mt3-2-2) (seq ,mdef-k-42 44)))))

;; ==================================================
;; Evaluation with Optimization
;; ==================================================

;; <MTg , C[e]> -->opt <MTg' , C'[e']>
;; Almost the same as --> except we do optimization
;; for a global method call
;; (search for "!!! optimization")
(define ->step-opt
  (reduction-relation
   WA-opt
   #:domain st
   ; <MTg, C[x]> where x \in dom(MTg) --> <MTg, (mval "x")>
   [--> (< MT_g (in-hole C x) >)
        (< MT_g (in-hole C (mval mname)) >)
        (where #t (inMTdom MT_g x))
        ; transform variable name to a string
        (where mname ,(~a (term x)))
        E-VarMethod]
   ; <MTg, C[v;e]> --> <MTg, C[e]>
   [--> (< MT_g (in-hole C (seq v e)) >)
        (< MT_g (in-hole C e) >)
        E-Seq]
   ; <MTg, C[op(v...)]> --> <MTg, C[v']>
   [--> (< MT_g (in-hole C (pcall op v ...)) >)
        (< MT_g (in-hole C v_r) >)
        (where v_r (run-primop op v ...))
        E-Primop]
   ; <MTg, C[(|v|)]> --> <MTg, C[v]>
   [--> (< MT_g (in-hole C (evalg v)) >)
        (< MT_g (in-hole C v) >)
        E-ValGlobal]
   ; <MTg, C[(|v|)_MT]> --> <MTg, C[v]>
   [--> (< MT_g (in-hole C (evalt MT v)) >)
        (< MT_g (in-hole C v) >)
        E-ValLocal]
   ; <MTg, C[md]> --> <MTg, C[nothing]>
   [--> (< MT_g        (in-hole C md) >)
        (< (md • MT_g) (in-hole C nothing) >)
        E-MD]
   ; !!! optimization
   ; <MTg, C[(| X[m(v...)] |)]> --> <MTg, C[(|X[ optimiztion of (|m(v...)|)_MTg ]|)]>
   [--> (< MT_g (in-hole C (evalg (in-hole X (mcall (mval mname) v ...)))) >)
        (< MT_g (in-hole C (evalg (in-hole X (evalt MT_gopt e_opt)))) >)
        ; optimize call in the global table
        (where ((evalt MT_gopt e_opt))
               ,(apply-reduction-relation ->opt-expr-tbl (term (evalt MT_g (mcall (mval mname) v ...)))))
        E-CallGlobal]
   ; <MTg, C[(| X[m(v...)] |)_MT]> --> <MTg, C[(| X[e[x...:=v...]] |)_MT]>
   [--> (< MT_g (in-hole C (evalt MT (in-hole X (mcall (mval mname) v ...)))) >)
        (< MT_g (in-hole C (evalt MT (in-hole X (subst-n e (x v) ...)))) >)
        (where (σ ...) (typeof-tuple (v ...)))
        (where (mdef mname ((:: x _) ...) e) (getmd MT mname (σ ...)))
        E-CallLocal]
))

;; Runs program normally with optimization while possible
(define-metafunction WA-opt
  run-opt-normal : p -> (st ...)
  [(run-opt-normal p)
   ,(apply-reduction-relation* ->step-opt (term (< ∅ p >)))]
)

;; Runs program down to the result with optimization
(define-metafunction WA-full
  run-opt : p -> (stf ...)
  [(run-opt p)
   ; for every end state of normal execution, try step to an error
   ; (if the state st is good, (run-error st) will simply return the same (st) back))
   (flatten ((run-error st) ...))
   ; run program normally
   (where (st ...) (run-opt-normal p))]
)

; (| f(x) = (k() = x ; x + k()) ; k() = 2 ; f(42) |) -->* 44
(test-predicate (alpha-eq? (term (run-opt ,p3-1)))
                (term ((< ,mt3-3-2 44 >))))

;; --------------------------------------------------
;; Coinsides with regular execution
;; --------------------------------------------------

;; Program p evaluates to the same final state
;; both regular evaluatin and optimization
(define-judgment-form WA-opt
  #:contract (optimization-correct p)
  #:mode (optimization-correct I)
  ; (run-opt p) = (run p)
  [ (where (stf) (run p))
    (where (stf) (run-opt p))
   ---------------------------- OptimizationCorrect
    (optimization-correct p) ]
)
