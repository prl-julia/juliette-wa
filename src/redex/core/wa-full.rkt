#lang racket
(require redex)

(require "wa-surface.rkt")  ; import surface language

(provide (all-defined-out)) ; export all definitions

;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Full Language
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Grammar
;; ==================================================

(define-extended-language WA-full WA

;; -------------------- Evaluation contexts
  
  ;; simple evaluation context
  [X ::=
     hole       ; □
     (seq X e)  ; X;e
     (if X e e) ; if X then e else e
     (mcall v ... X e ...)    ;  v(v..., X, e...)
     (pcall op v ... X e ...) ; op(v..., X, e...)
     ]
  ;; full evaluation context
  [C ::=
     X
     (in-hole X (evalg C)) ; X[(|C|)]
     ; evaluation in the given method table (|e|)_MT
     (in-hole X (evalt MT C))
     ]

;; -------------------- State

  ;; method table
  [MT ::=
      ∅         ; empty table
      (md • MT) ; table extended with a method definition
      ]

  ;; program state < MT , C[e] >
  [st ::= (< MT ce >)]
  [ce ::= (in-hole C e)]

;; -------------------- Evaluation result

  ;; error
  [err ::=
       md-err      ; dispatch error
       call-err    ; callee is not callable error
       prim-err    ; primop error
       var-err     ; undefined variable error
       type-err    ; expected one type but got another
       assert-err  ; assertion failed
       ]
  ;; dispatch-related error
  [md-err ::=
          err-no-method   ; method not found
          err-amb-method  ; method ambigous
          ]

  ;; program result
  [r ::=
     v      ; value
     err    ; error
     ]

  ;; intermediate state (normal state or error state)
  [sti ::= st (< MT err >)]
  
  ;; final state
  [stf ::= (< MT r >)]
)

;; ==================================================
;; Types Semantics
;; ==================================================

;; -------------------- Typeof type

;; Returns type tag of the given value
(define-metafunction WA-full
  typeof : v -> σ
  [(typeof integer)      Int64]
  [(typeof real)         Float64]
  [(typeof string)       String]
  [(typeof bool)         Bool]
  [(typeof nothing)      Nothing]
  [(typeof (mval mname)) (mtag mname)]
)

(test-equal (term (typeof 5))       (term Int64))
(test-equal (term (typeof 3.14))    (term Float64))
(test-equal (term (typeof nothing)) (term Nothing))

;; -------------------- Typeof tuple-type

;; Returns tuple-type tag of the given tuple
(define-metafunction WA-full
  typeof-tuple : (v ...) -> (σ ...)
  [(typeof-tuple (v ...)) ((typeof v) ...)]
)

(test-equal (term (typeof-tuple ()))        (term ()))
(test-equal (term (typeof-tuple (true 5)))  (term (Bool Int64)))

;; -------------------- Return type of primop

;; Returns the result type of a primop call
;; with the given argument types
(define-metafunction WA-full
  res-type-primop : op τ ... -> τ
  [(res-type-primop bin-arithop Int64   Int64)   Int64]
  [(res-type-primop bin-arithop Float64 Int64)   Float64]
  [(res-type-primop bin-arithop Int64   Float64) Float64]
  [(res-type-primop bin-arithop Float64 Float64) Float64]
  [(res-type-primop bin-arithop-to-bool τ_1 τ_2) Bool
   (side-condition (judgment-holds (<: τ_1 Number)))
   (side-condition (judgment-holds (<: τ_2 Number)))]
  [(res-type-primop bin-boolop   Bool Bool) Bool]
  [(res-type-primop unary-boolop Bool)      Bool]
  [(res-type-primop == σ_1 σ_2) Bool]
  [(res-type-primop unary-void σ)  Nothing]
  [(res-type-primop op τ ...) Any])

(test-equal (term (res-type-primop + Int64 Float64))  (term Float64))
(test-equal (term (res-type-primop + Int64))          (term Any))
(test-equal (term (res-type-primop + Int64 Bool))     (term Any))
(test-equal (term (res-type-primop print Bool))       (term Nothing))
(test-equal (term (res-type-primop >= Int64 Float64)) (term Bool))
(test-equal (term (res-type-primop < Int64 Bool))     (term Any))

;; ==================================================
;; Primops Semantics
;; ==================================================

;; Returns true if primop operation has side effects
;; Ω(op)
(define-metafunction WA-full
  side-eff-primop : op -> boolean
  [(side-eff-primop print) #t]
  [(side-eff-primop op)    #f]
)

(test-equal (term (side-eff-primop print)) #t)
(test-equal (term (side-eff-primop +))     #f)

;; Divides the two numbers if the second is not 0
(define (handle-/ arg1 arg2)
  (if (equal? arg2 0) (term prim-err) (/ arg1 arg2)))
;; Takes the logical or of two boolean values
(define (|| a b) (or a b))
;; Takes the logical and of two boolean values
(define (&& a b) (and a b))
;; Takes the logical not of a boolean value
(define (! a) (not a))

;; A map of ops to their repective racket implementations
(define op-map
  (list (list '! !) (list '&& &&) (list '|| ||)
        (list '> >) (list '< <) (list '>= >=) (list '<= <=)
        (list '+ +) (list '- -) (list '* *) (list '/ handle-/)))

;; Given an binop symbol, returns the respective racket procedure
(define (get-op op)
  (second (findf
           (lambda (op-pair)
             (equal? (first op-pair) op))
           op-map)))

;; Converts the boolean to its respective symbol value
(define (bool->sym bool)
  (if bool 'true 'false))
;; Converts the world age value to its respective racket value
(define (wa-val->racket wa-val)
  (cond
    [(equal? wa-val 'true) #t]
    [(equal? wa-val 'false) #f]
    [#t wa-val])
  )

;; Executes primop operation on the given values
;; Δ(op, v...)
(define-metafunction WA-full
  run-primop : op v ... -> r
  [(run-primop print v ...) (pcall-print v ...)]
  [(run-primop @assert v) (pcall-assert v)]
  [(run-primop == v_1 v_2) (pcall-== v_1 v_2)]
  [(run-primop bin-arithop real_1 real_2)
   ,((get-op (term bin-arithop)) (term real_1) (term real_2))]
  [(run-primop bin-arithop-to-bool real_1 real_2)
    ,(bool->sym ((get-op (term bin-arithop-to-bool))
                 (term real_1) (term real_2)))]
  [(run-primop bin-boolop bool_1 bool_2)
   ,(bool->sym ((get-op (term bin-boolop))
                (wa-val->racket (term bool_1)) (wa-val->racket (term bool_2))))]
  [(run-primop unary-boolop bool_1)
   ,(bool->sym ((get-op (term unary-boolop))
                (wa-val->racket (term bool_1))))]
  [(run-primop op v ...) prim-err]
)

;; Equality primop
(define-metafunction WA-full
  pcall-== : v v -> r
  [(pcall-== v v) true]
  [(pcall-== _ _) false]
)

;; Assertion primop
(define-metafunction WA-full
  pcall-assert : v -> r
  [(pcall-assert true) nothing]
  [(pcall-assert false) assert-err]
  [(pcall-assert _) type-err]
)

;; Printing-single-value primop
(define-metafunction WA-full
  pcall-print : v ... -> r
  [(pcall-print)   nothing
     (where _ ,(newline))]
  [(pcall-print v) nothing
     (where _ ,(println (term v)))]
  [(pcall-print _ ...) prim-err]
)

(test-equal (term (run-primop + 5 3.14))                  (term 8.14))
(test-equal (term (run-primop + 5))                       (term prim-err))
(test-equal (term (run-primop print 5))                   (term nothing))
(test-equal (term (run-primop - 2 2))                     (term 0))
(test-equal (term (run-primop * 5 3.5))                   (term 17.5))
(test-equal (term (run-primop / 5 0))                     (term prim-err))
(test-equal (term (run-primop / 10 2))                    (term 5))
(test-equal (term (run-primop / 2 10))                    (term 1/5))
(test-equal (term (run-primop - 2 2 2))                   (term prim-err))
(test-equal (term (run-primop && true true))              (term true))
(test-equal (term (run-primop ||))                        (term prim-err))
(test-equal (term (run-primop ! false false))             (term prim-err))
(test-equal (term (run-primop && true false))             (term false))
(test-equal (term (run-primop || false false))            (term false))
(test-equal (term (run-primop ! false))                   (term true))
(test-equal (term (run-primop ! true))                    (term false))
(test-equal (term (run-primop == true))                   (term prim-err))
(test-equal (term (run-primop == true false))             (term false))
(test-equal (term (run-primop == false false))            (term true))
(test-equal (term (run-primop == 1 1.1))                  (term false))
(test-equal (term (run-primop == 1 1))                    (term true))
(test-equal (term (run-primop == 1.1 1.1))                (term true))
(test-equal (term (run-primop == (mval "a") (mval "b")))  (term false))
(test-equal (term (run-primop == (mval "a") (mval "a")))  (term true))
(test-equal (term (run-primop @assert 1))                 (term type-err))
(test-equal (term (run-primop @assert true))              (term nothing))
(test-equal (term (run-primop @assert false))             (term assert-err))
(test-equal (term (run-primop > 5 3.5))                   (term true))
(test-equal (term (run-primop > 5 5))                     (term false))
(test-equal (term (run-primop < 1 2))                     (term true))
(test-equal (term (run-primop < 10 10))                   (term false))
(test-equal (term (run-primop >= 2 2))                    (term true))
(test-equal (term (run-primop >= 1 2))                    (term false))
(test-equal (term (run-primop <= -1 -1))                  (term true))
(test-equal (term (run-primop <= -1 2))                   (term true))


;; ==================================================
;; Method table
;; ==================================================

;; Returns true if a method named x is defined in MT
(define-metafunction WA-full
  inMTdom : MT x -> boolean
  ; empty table definitely does not have it
  [(inMTdom ∅         x)
     #f]
  ; the first method has the right name
  [(inMTdom (md • MT) x)
     #t
     ; details of the first method in the table
     (where (mdef mname _ _) md)
     ; name of the method is what we look for
     ; (function ~a transforms variable term to a string)
     (where mname ,(~a (term x)))]
  ; maybe the rest of the table contains it
  [(inMTdom (md • MT) x)
     (inMTdom MT x)]
)

(define-metafunction WA-full
  inMTdomWrap : MT mname -> boolean
  [(inMTdomWrap MT mname) (inMTdom MT ,(string->symbol (term mname)))]
)

(test-equal #f (term (inMTdom ∅ f)))
(test-equal #f (term (inMTdom ((mdef "g" () 0) • ∅) f)))
(test-equal #t (term (inMTdom ((mdef "f" () 0) • ∅) f)))
(test-equal #t (term (inMTdom ((mdef "g" () 0) • ((mdef "f" () 0) • ∅)) f)))


;; ==================================================
;; Multiple Dispatch
;; ==================================================

;; --------------------------------------------------
;; Helper fuctions
;; --------------------------------------------------

;; -------------------- Utils

;; Checks if the given list of methods (md_acc ...) contains
;; a method with the same name and equivalent type signature as md_?
(define-metafunction WA-full
  contains-equiv-md : (md_acc ...) md_? -> boolean
  ; empty list definitely does not
  [(contains-equiv-md ()              md_?) #f]
  ; first method in the list has equivalent signature
  [(contains-equiv-md (md md_acc ...) md_?) #t
     ; details of the first method in the list
     (where (mdef mname ((:: _ τ) ...)   _) md)
     ; details of the method we are interested in
     (where (mdef mname ((:: _ τ_?) ...) _) md_?)
     ; type signatures are equivalent
     (side-condition (judgment-holds (==-tuple (τ ...) (τ_? ...)))) ]
  ; otherwise, search in the rest of the list
  [(contains-equiv-md (md md_acc ...) md_?)
     (contains-equiv-md  (md_acc ...) md_?) ]
)

(test-equal (term (contains-equiv-md ()                            (mdef "f" ((:: x Bool)) x))) #f)
(test-equal (term (contains-equiv-md ((mdef "g" ((:: x Bool)) 0))  (mdef "f" ((:: x Bool)) x))) #f)
(test-equal (term (contains-equiv-md ((mdef "f" ((:: x Int64)) x)) (mdef "f" ((:: x Bool)) x))) #f)
(test-equal (term (contains-equiv-md ((mdef "f" ((:: x Bool)) 0))  (mdef "f" ((:: x Bool)) x))) #t)

;; -------------------- Dispatch

;; Returns the list of all MT methods
;; if equivalent methods are not already in (md_acc ...)
;; Accumulator: distinct methods from
;;              the already-processed part of MT
(define-metafunction WA-full
  latest/acc : (md_acc ...) MT -> (md ...)
  ; empty table -- everything is in the accumulator
  [(latest/acc (md_acc ...) ∅)
     (md_acc ...)]
  ; md does not have an equivalent in (md_acc ...)
  [(latest/acc (md_acc ...) (md • MT))
     ; call recursively with updated accumulator
     (latest/acc (md md_acc ...) MT)
     ; get details of the next method definition
     (where (mdef mname ((:: x τ) ...) e) md)
     ; make sure the accumulator does not already contain
     ; an equivalent method (because we need only the newest definitions)
     (where #f (contains-equiv-md (md_acc ...) md))]
  ; otherwise (if md is already accounted for) skip md
  [(latest/acc (md_acc ...) (md • MT))
     (latest/acc (md_acc ...) MT)]
)

; Returns minimal of the methods (md ...) if it exists
; Otherwise, produces ambiguity error
; Accumulator: minimal method so far
(define-metafunction WA-full
  min-method/acc : md_min (md ...) -> md or err-amb-method
  ; list exhausted -- the acc is the minimum method
  [(min-method/acc md_min ()) md_min]
  ; current minimum is less than the next candidate
  [(min-method/acc md_min (md_next md ...))
     (min-method/acc md_min  (md ...))
     (where (mdef mname ((:: _ τ_min)  ...) _) md_min)
     (where (mdef mname ((:: _ τ_next) ...) _) md_next)
     (side-condition (judgment-holds (<:-tuple (τ_min ...) (τ_next ...))))]
  ; next candidate is less than the current minimum
  [(min-method/acc md_min (md_next md ...))
     (min-method/acc md_next (md ...))
     (where (mdef mname ((:: _ τ_min)  ...) _) md_min)
     (where (mdef mname ((:: _ τ_next) ...) _) md_next)
     (side-condition (judgment-holds (<:-tuple (τ_next ...) (τ_min ...))))]
  ; otherwise, methods are not comparable
  [(min-method/acc _ _) err-amb-method]
)

;; --------------------------------------------------
;; Main fuctions
;; --------------------------------------------------

;; -------------------- Step 1: latest methods

;; Returns the list of only the newest methods
;; among equivalent ones in table MT
(define-metafunction WA-full
  latest : MT -> (md ...)
  [(latest MT) (latest/acc () MT)]
)

(test-equal (term (latest ∅)) (term ()))
(test-equal (term (latest ((mdef "f" () 0) • ∅))) (term ((mdef "f" () 0))))
(test-equal (term (latest ((mdef "f" () 1) • ((mdef "f" () 0) • ∅))))
            (term ((mdef "f" () 1))))
(test-equal (term (latest ((mdef "f" () 1) • ((mdef "f" () 0) • ((mdef "h" () 7) • ∅)))))
            (term ((mdef "h" () 7) (mdef "f" () 1))))

;; -------------------- Step 1: applicable methods

;; Returns the list of methods named mname in (md_latest ...)
;; that are applicable to (σ ...)
;; Assumption. (md_latest ...) does not contain equivalent methods
;; Accumulator: applicable method from (md_latest ...) processed so far
(define-metafunction WA-full
  get-applcbl-methods : (md_latest ...) mname (σ ...) -> (md ...)
  ; empty list of methods
  [(get-applcbl-methods () _ _) ()]
  ; the first md is applicable
  [(get-applcbl-methods (md md_latest ...) mname (σ ...))
     ; call recursively
     ,(cons (term md) (term (get-applcbl-methods (md_latest ...) mname (σ ...))))
     ; get details of the next method definition
     (where (mdef mname ((:: x τ) ...) e) md)
     ; check if the method is applicable (tags are subtypes of its annotations)
     (side-condition (judgment-holds (<:-tuple (σ ...) (τ ...))))]
  ; otherwise (md is not applicable), skip md
  [(get-applcbl-methods (md md_latest ...) mname (σ ...))
    (get-applcbl-methods (md_latest ...) mname (σ ...))]
)

(test-equal (term (get-applcbl-methods ((mdef "h" () 7) (mdef "f" () 1)) "f" ()))
            (term ((mdef "f" () 1))))
(test-equal (term (get-applcbl-methods ((mdef "h" () 7) (mdef "f" () 1) (mdef "f" ((:: x Number)) 1)) "f" (Int64)))
            (term ((mdef "f" ((:: x Number)) 1))))

;; Returns the list of newest MT methods applicable to mname(σ ...)
(define-metafunction WA-full
  get-applicable-methods : MT mname (σ ...) -> (md ...)
  [(get-applicable-methods MT mname (σ ...))
   (get-applcbl-methods (latest MT) mname (σ ...))]
)

;; -------------------- Step 2: minimal of the applicable methods

; Returns minimal of the methods if it exists
; Can produce dispatch errors
; Note: it is not supposed to be called with
;       equivalent methods in the list
(define-metafunction WA-full
  min-method : (md ...) -> md or md-err
  ; no method
  [(min-method ()) err-no-method]
  ; otherwise, call the helper with the first method as accumulator
  [(min-method (md_min md ...))
     (min-method/acc md_min (md ...))]
)

;; -------------------- Full dispatch

; Returns the best applicable method to mname(σ ...) from MT if it exists
; Can produce dispatch errors (no method found or ambiguity)
(define-metafunction WA-full
  getmd : MT mname (σ ...) -> md or md-err
  [(getmd MT mname (σ ...))
   ; take minimal of the applicable methods
   (min-method (md ...))
   ; find all the newset applicable methods
   (where (md ...) (get-applicable-methods MT mname (σ ...)))]
)

;; ==================================================
;; Substitution
;; ==================================================

;; Capture avoiding substitution any_where[x:=any]
(define-metafunction WA-full
  subst : any_where x any -> any
  [(subst any_where x any)  (substitute any_where x any)]
)

(test-equal (term (subst (evalt ∅ x) x 5)) (term (evalt ∅ 5)))
(test-equal (term (subst (evalt ∅ y) x 5)) (term (evalt ∅ y)))

;; Capture avoiding substitution any_where[x1:=any1, x2:=any2, ...]
;; (Copied from IPPL notes)
(define-metafunction WA-full
  subst-n : any_where (x any) ... -> any
  [(subst-n any_where) any_where]
  [(subst-n any_where (x_1 any_1) (x_2 any_2) ...)
   (subst (subst-n any_where (x_2 any_2) ...) x_1 any_1)]
)

(test-equal (term (subst-n (pcall + x y) (x 5) (y 7))) (term (pcall + 5 7)))

;; Checks if terms t1 and t2 are alpha-equiavlent
(define ((alpha-eq? t1) t2) (alpha-equivalent? WA-full t1 t2))

;; Returns true if the given expression is a boolean, false otherwise
(define-metafunction WA
  is-bool : v -> boolean
  [(is-bool bool) #t]
  [(is-bool v) #f]
  )

;; ==================================================
;; Small-step Semantics
;; ==================================================

;; --------------------------------------------------
;; Normal Evaluation
;; --------------------------------------------------

;; <MTg , C[e]> --> <MTg' , C'[e']> 
(define ->step
  (reduction-relation 
   WA-full
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
   ; <MTg, C[(if true e_1 e_2)]> --> <MTg, C[e_1]>
   [--> (< MT_g (in-hole C (if true e_1 e_2)) >)
        (< MT_g (in-hole C e_1) >)
        E-IfTrue]
   ; <MTg, C[(if false e_1 e_2)]> --> <MTg, C[e_2]>
   [--> (< MT_g (in-hole C (if false e_1 e_2)) >)
        (< MT_g (in-hole C e_2) >)
        E-IfFalse]
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
        (< (md • MT_g) (in-hole C (mval mname)) >)
        (where (mdef mname _ _) md)
        E-MD]
   ; <MTg, C[(| X[m(v...)] |)]> --> <MTg, C[(|X[ (|m(v...)|)_MTg ]|)]>
   [--> (< MT_g (in-hole C (evalg (in-hole X (mcall (mval mname) v ...)))) >)
        (< MT_g (in-hole C (evalg (in-hole X (evalt MT_g (mcall (mval mname) v ...))))) >)
        E-CallGlobal]
   ; <MTg, C[(| X[m(v...)] |)_MT]> --> <MTg, C[(| X[e[x...:=v...]] |)_MT]>
   [--> (< MT_g (in-hole C (evalt MT (in-hole X (mcall (mval mname) v ...)))) >)
        (< MT_g (in-hole C (evalt MT (in-hole X (subst-n e (x v) ...)))) >)
        (where (σ ...) (typeof-tuple (v ...)))
        (where (mdef mname ((:: x _) ...) e) (getmd MT mname (σ ...)))
        E-CallLocal]
))

; C[e] --> C'[e']

; (| pcall + (pcall 1 2) 3 |)  ==  C[pcall 1 2] where C is (| pcall + hole 3 |)
; -->
; (| pcall + 3 3 |) == C[pcall + 3 3] where C is (| hole |)
; -->
; (| 6 |) == hole[(| 6 |)]
; --> E-ValGlobal
; 6

;; Runs program normally while possible
(define-metafunction WA-full
  run-normal : p -> (st ...)
  [(run-normal p) 
   ,(apply-reduction-relation* ->step (term (< ∅ p >)))]
)

;; --------------------------------------------------
;; Error States
;; --------------------------------------------------

;; <MTg , C[e]> -->e <MTg , err>
;; NOTE Method Table does not change, but we keep it here
;;      for simplicity of merging this relation with normal evaluation
;;      in run meta-function
(define ->error
  (reduction-relation 
   WA-full
   #:domain sti
   ; <MTg, C[x]> where x \notin dom(MTg) --> <MTg, var-err>
   [--> (< MT_g (in-hole C x) >)
        (< MT_g var-err >)
        (where #f (inMTdom MT_g x))
        E-VarErr]
   ; <MTg, C[(if v e e)]> where e not Bool --> <MTg, type-err>
   [--> (< MT_g (in-hole C (if v e_1 e_2)) >)
        (< MT_g type-err >)
        (where #f (is-bool v))
        E-IfErr]
   ; <MTg, C[op(v...)]> --> <MTg, prim-err>
   [--> (< MT_g (in-hole C (pcall op v ...)) >)
        (< MT_g err >)
        (where err (run-primop op v ...))
        E-PrimopErr]
   ; <MTg, C[(| X[m(v...)] |)_MT]> --> <MTg, md-err>
   [--> (< MT_g (in-hole C (evalt MT (in-hole X (mcall (mval mname) v ...)))) >)
        (< MT_g md-err >)
        (where (σ ...) (typeof-tuple (v ...)))
        (where md-err (getmd MT mname (σ ...)))
        E-CallErr]
   ; <MTg, C[v(v...)]> --> <MTg, call-err>
   [--> (< MT_g (in-hole C (mcall v_call v ...)) >)
        (< MT_g call-err >)
        (where #f ,(redex-match? WA m (term v_call)))
        E-CalleeErr]
))

;; Runs program into error state
(define-metafunction WA-full
  run-error : st -> (sti ...)
  [(run-error st) 
   ,(apply-reduction-relation* ->error (term st))]
)

;; --------------------------------------------------
;; Full Evaluation
;; --------------------------------------------------

;; Flattens nested lists
(define-metafunction WA-full
  flatten : ((sti ...) ...) -> (sti ...)
  [(flatten ((sti ...) ...)) (sti ... ...)]
)

(test-equal (term (flatten (((< ∅ var-err >))))) (term ((< ∅ var-err >))))
(test-equal (term (flatten (((< ∅ var-err >)) ((< ∅ prim-err >))))) (term ((< ∅ var-err >) (< ∅ prim-err >))))

;; Runs program all the way down to the result
;; and returns the list of all possible states
;;
;; Reproduces the following relation:
;;
;;  <MTg, C[e]> -->* <MTg', v>
;; ----------------------------
;;    <MTg, C[e]> ⇓ <MTg', v>
;;
;;  <MTg, C[e]> -->* <MTg', C'[e']>    <MTg', C'[e']> -->e <MTg', err>
;; --------------------------------------------------------------------
;;                    <MTg, C[e]> ⇓ <MTg', err>
;;
;; Our relations should be deterministic
;; so run should always return singleton list
(define-metafunction WA-full
  run : p -> (stf ...)
  [(run p)
   ; for every end state of normal execution, try step to an error
   ; (if the state st is good, (run-error st) will simply return the same (st) back))
   (flatten ((run-error st) ...))
   ; run program normally
   (where (st ...) (run-normal p))]
)

;; Evaluates a program in the empty table
;; and returns only the result
;; (throwing away the resulting global table)
(define-metafunction WA-full
  run-to-r : p -> r
  [(run-to-r p)
   r
   (where (( < MT r >)) (run p))]
)

;; --------------------------------------------------
;; Determinism
;; --------------------------------------------------

;; program p is deterministic
(define-judgment-form WA-full
  #:contract (p-deterministic p)
  #:mode (p-deterministic I)
  ; (run p) = (stf)
  [ (where (stf) (run p))   
   ------------------------- P-Deterministic
     (p-deterministic p) ]
)

(test-results)