#lang racket

(require redex)
(require "../core/wa-full.rkt")  ; import language semantics
(provide (all-defined-out))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Optimization Language Extenstions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-extended-language WA-opt WA-full
  (nv ::= x v)                   ; near value
  
  (Γ ::= ((x τ) ...))            ; environment of types

  (sig-σ ::= (mdef mname (σ ...))) ; concrete type method signature
  (sig-τ ::= (mdef mname (τ ...))) ; abstract type method signature
  
  (Δ ::= ((sig-τ real) ...))       ; environment of inlined methods
  (Φ ::= ((sig-σ mname) ...))      ; environment of methods with direct calls
  (opt-err ::= undeclared-var md-err type-err)
  
  (maybe-τ ::= τ opt-err)
  (maybe-e ::= e opt-err)
  (maybe-mname ::= mname nothing)

  (N ::= natural)
  (L ::= N)

  ;; simple optimization context
  [E ::=
      hole    ; □
      (seq E e)  ; E;e
      (seq e E)  ; e;E
      (mcall e ... E e ...)    ;  e(e..., E, e...)
      (pcall op e ... E e ...) ; op(e..., E, e...)
      ]

  ;; optimize state < Γ Φ xe >
  [st-opt ::= (< Γ Δ Φ (evalt MT (in-hole E maybe-e)) >)]
  [st-mtopt ::= (< Φ MT L >)])

(define MAX_INLINE_COUNT 3)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Language Extension Helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ==================================================
;; Typing Environment Helpers
;; ==================================================

;; (lookup Γ x) retrieves x's type from Γ
(define-metafunction WA-opt
  lookup : Γ x -> τ or opt-err
  [(lookup ((x_1 τ_1) ... (x τ) (x_2 τ_2) ...) x)
   τ
   (side-condition (not (member (term x) (term (x_1 ...)))))]
  [(lookup any_1 any_2) undeclared-var])

(test-equal (term (lookup ((x Int64) (x (mtag "s")) (y Bool)) x)) (term Int64))
(test-equal (term (lookup ((x Int64) (x (mtag "s")) (y Bool)) y)) (term Bool))

;; (extend Γ (x τ) ...) add (x τ) to Γ so that x is found before other x-s
(define-metafunction WA-opt
  extend : Γ (x τ) ... -> Γ
  [(extend ((x_Γ τ_Γ) ...) (x τ) ...) ((x τ) ...(x_Γ τ_Γ) ...)])

(test-equal (term (extend () (x Int64))) (term ((x Int64))))
(test-equal (term (extend ((x Int64)) (x Bool))) (term ((x Bool) (x Int64))))

;; ==================================================
;; Near-Value Helpers
;; ==================================================

;; Returns type tag of the given near values
(define-metafunction WA-opt
  typeof-nv : Γ nv -> maybe-τ
  [(typeof-nv Γ v) (typeof v)]
  [(typeof-nv Γ x) (lookup Γ x)]
  )

(test-equal (term (typeof-nv () 3)) (term Int64))
(test-equal (term (typeof-nv ((x Bool)) "a")) (term String))
(test-equal (term (typeof-nv ((x Bool)) x)) (term Bool))

;; Returns tuple-type tag of the given tuple of near values
(define-metafunction WA-opt
  typeof-nv-tuple : Γ (nv ...) -> (maybe-τ ...)
  [(typeof-nv-tuple Γ (nv ...)) ((typeof-nv Γ nv) ...)]
  )

(test-equal (term (typeof-nv-tuple () (3 "string")))
            (term (Int64 String)))
(test-equal (term (typeof-nv-tuple ((x Bool) (y Float64) (x Int64)) (x y)))
            (term (Bool Float64)))

;; Determines if the expression is a near value
(define-metafunction WA-opt
  is-nv : e -> boolean
  [(is-nv nv) #t]
  [(is-nv _)  #f])

;; ==================================================
;; Method Table Helpers
;; ==================================================

;; -------------------- Length

;; Determines the length of the method table
(define-metafunction WA-opt
  length : MT -> integer
  [(length ∅) 0]
  [(length (_ • MT_rest)) ,(+ 1 (term (length MT_rest)))]
  )

(define id-fInt (term (mdef "func" ((:: x Int64)) x)))
(define g-return1 (term (mdef "g" () 1)))
(test-equal (term (length ∅)) 0)
(test-equal (term (length (,id-fInt • (,g-return1 • ∅)))) 2)

;; -------------------- Reverse

;; Reverses the given method-table using the given accumulated reverse list
(define-metafunction WA-opt
  reverse-mt-acc : MT MT -> MT
  [(reverse-mt-acc ∅         MT_acc) MT_acc]
  [(reverse-mt-acc (md • MT) MT_acc) (reverse-mt-acc MT (md • MT_acc))])

;; Reverses the given method-table
(define-metafunction WA-opt
  reverse-mt : MT -> MT
  [(reverse-mt MT) (reverse-mt-acc MT ∅)])

(define f-return0 (term (mdef "f" () 0)))
(define g-return0 (term (mdef "g" () 0)))
(define f-g-table (term (,f-return0 • (,g-return0 • ∅))))
(test-equal (term (reverse-mt ∅))
            (term ∅))
(test-equal (term (reverse-mt (,g-return0 • (,f-return0 • ∅))))
            (term ,f-g-table))

;; -------------------- Append

;; Appends the two method tables together
(define-metafunction WA-opt
  append : MT MT -> MT
  [(append ∅ MT)
   MT]
  [(append (md • MT_rest) MT_2)
   (md • (append MT_rest MT_2))])

(test-equal (term (append ,f-g-table ∅))
            (term ,f-g-table))
(test-equal (term (append ∅ ,f-g-table))
            (term ,f-g-table))
(test-equal (term (append ∅ (,f-return0 • (,g-return0 • ,f-g-table))))
            (term (,f-return0 • (,g-return0 • ,f-g-table))))

;; -------------------- Cut

;; Takes the first N mdefs from the method table
(define-metafunction WA-opt
  take : natural MT -> MT
  [(take 0 MT) ∅]
  [(take N ∅)  ∅]
  [(take N (md_first • MT_rest))
   (md_first • (take ,(- (term N) 1) MT_rest))]
  )

(test-equal (term (take 1 ∅)) (term ∅))
(test-equal (term (take 1 (,id-fInt • (,g-return1 • ∅))))
            (term (,id-fInt • ∅)))
(test-equal (term (take 0 (,id-fInt • (,g-return1 • ∅))))
            (term ∅))
(test-equal (term (take 2 (,id-fInt • (,g-return1 • ∅))))
            (term (,id-fInt • (,g-return1 • ∅))))

;; Removes the first N mdefs from the method table
(define-metafunction WA-opt
  drop : natural MT -> MT
  [(drop 0 MT) MT]
  [(drop N  ∅) ∅]
  [(drop N (_ • MT_rest))
   (drop ,(- (term N) 1) MT_rest)]
  )

(test-equal (term (drop 1 ∅)) (term ∅))
(test-equal (term (drop 1 (,id-fInt • (,g-return1 • ∅))))
            (term (,g-return1 • ∅)))
(test-equal (term (drop 0 (,id-fInt • (,g-return1 • ∅))))
            (term (,id-fInt • (,g-return1 • ∅))))
(test-equal (term (drop 2 (,id-fInt • (,g-return1 • ∅)))) (term ∅))

;; -------------------- Indexing

;; Gets the i-th method (indexing at 0 where 0 is the outermost element)
(define-metafunction WA-opt
  get-element-wrap : natural MT -> md or nothing
  [(get-element-wrap _ ∅)
   nothing]
  [(get-element-wrap 0 (md • MT_rest))
   md]
  [(get-element-wrap N (_ • MT_rest))
   (get-element-wrap ,(- (term N) 1) MT_rest)]
  )

;; Gets the ith method (indexing at 0 where 0 is the innermost element)
(define-metafunction WA-opt
  get-element : natural MT -> md or nothing
  [(get-element N MT)
   (get-element-wrap N (reverse-mt MT))]
  )

(test-equal (term (get-element 0 (,id-fInt • (,g-return1 • ∅))))
            (term ,g-return1))
(test-equal (term (get-element 2 (,id-fInt • (,g-return1 • ∅))))
            (term nothing))
(test-equal (term (get-element 2 ∅)) (term nothing))
(test-equal (term (get-element 1 (,id-fInt • (,g-return1 • ∅))))
            (term ,id-fInt))

;; ==================================================
;; Syntax and Bindings Helpers
;; ==================================================

;; Determines if the given value is value is a mval
(define-metafunction WA-opt
  is-mval : v -> boolean
  [(is-mval (mval _)) #t]
  [(is-mval _) #f])
(test-equal (term (is-mval 1)) #f)
(test-equal (term (is-mval (mval "func"))) #t)

;; Gets the name of the direct call method if one exists
(define-metafunction WA-opt
  get-opt-method : Φ sig-σ -> mname or nothing
  [(get-opt-method (_ ... (sig-σ mname_opt) _ ...) sig-σ)
   mname_opt]
  [(get-opt-method _ _) nothing]
  )

;; Determines if the given local variable has the same name as the given variable
;; The regex match is needed in order to ignore the substitution id of redex vars
(define (same-varname localvar x_str)
  (let* ((localvar_match
          (first (regexp-match* #rx".*«" (~a localvar))))
         (localvar_str (substring localvar_match
                                  0 (- (string-length localvar_match) 1))))
    (equal? localvar_str x_str)))

;; Determines whether the given name is used in the given expression
(define-metafunction WA-opt
  contains-name-e : e x -> boolean
  [(contains-name-e (mdef mname ((:: x_local _) ...) e_mbody) x)
   ,(or (equal? (~a (term x)) (term mname))
        (ormap (λ (localvar) (same-varname localvar (~a (term x))))
               (term (x_local ...)))
        (term (contains-name-e e_mbody x)))]
  [(contains-name-e (evalg e) x)
   (contains-name-e e x)]
  [(contains-name-e (mcall e ...) x)
   ,(ormap (λ (expr) (term (contains-name-e ,expr x)))
           (term (e ...)))]
  [(contains-name-e (seq e_1 e_2) x)
   ,(or (term (contains-name-e e_1 x))
        (term (contains-name-e e_2 x)))]
  [(contains-name-e (if e_1 e_2 e_3) x)
   ,(or (term (contains-name-e e_1 x))
        (term (contains-name-e e_2 x))
        (term (contains-name-e e_3 x)))]
  [(contains-name-e x x)
   #t]
  [(contains-name-e (mval string_var) x)
   ,(equal? (~a (term x)) (term string_var))]
  [(contains-name-e (pcall op e_1 e_2) x)
   ,(or (term (contains-name-e e_1 x))
        (term (contains-name-e e_2 x)))]
  [(contains-name-e _ _)
   #f])

(test-equal (term (contains-name-e 1 var1)) #f)
(test-equal (term (contains-name-e (mval "func") f)) #f)
(test-equal (term (contains-name-e (mval "f") f)) #t)
(test-equal (term (contains-name-e t t)) #t)
(test-equal (term (contains-name-e test t)) #f)
(test-equal (term (contains-name-e (seq true func) func)) #t)
(test-equal (term (contains-name-e (seq (seq nothing "func") 1.1) func)) #f)
(test-equal (term (contains-name-e (if nothing func 1.1) func)) #t)
(test-equal (term (contains-name-e (evalg (mval "t")) t)) #t)
(test-equal (term (contains-name-e (mcall func test) var)) #f)
(test-equal (term (contains-name-e (mcall add 1 var) var)) #t)
(test-equal (term (contains-name-e (mcall var) var)) #t)
(test-equal (term (contains-name-e (mcall tmp tmp tmp) tmp)) #t)
(test-equal (term (contains-name-e (pcall + 1 (mcall var)) var)) #t)
(test-equal (term (contains-name-e (pcall * 1 1.1) x)) #f)
(test-equal (term (contains-name-e (mdef "test" () 1) x)) #f)
(test-equal (term (contains-name-e (mdef "tst" ((:: y Bool) (:: x String)) 1) x)) #t)
(test-equal (term (contains-name-e (mdef "f" () (pcall + 1 x)) x)) #t)
(test-equal (term (contains-name-e ,g-return1 g)) #t)
(test-equal (term (contains-name-e (mdef "g" () (mcall (mval "g"))) g)) #t)
(test-equal (term (contains-name-e (mdef "g" ((:: f Any) (:: h Any))
                                         (mcall (mval "h") (mcall f))) x)) #f)
(test-equal (term (contains-name-e ,id-fInt x)) #t)

;; Determines whether the given name is used in the given method table
(define-metafunction WA-opt
  contains-name-MT : MT x -> boolean
  [(contains-name-MT ∅ x)
   #f]
  [(contains-name-MT (md • MT) x)
   ,(or (term (contains-name-e md x)) (term (contains-name-MT MT x)))])

(test-equal (term (contains-name-MT ∅ name)) #f)
(test-equal (term (contains-name-MT ((mdef "f" ((:: x Int64)) (evalg var)) • ∅) var)) #t)
(test-equal (term (contains-name-MT ((mdef "f" () (pcall + 1 x))
                                     • ((mdef "g" () (mcall (mval "g"))) • ∅)) var)) #f)
(test-equal (term (contains-name-MT (,g-return1 • ((mdef "tst" ((:: y Bool) (:: test String)) 1)
                                           • ((mdef "test" () 1) • ∅))) test)) #t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Typing Judgment Definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Defines the typing relation on World Age expressions
(define-judgment-form WA-opt
  #:mode (⊢ I I O)
  #:contract (⊢ Γ e σ)
  ; Γ ⊢ x :: (mtag "x"), where x ∉ Γ
  [(where undeclared-var (lookup Γ x))
   ----------------------------------- "T-Method-Var"
   (⊢ Γ x (mtag ,(~a (term x))))]
  ; Γ ⊢ x :: σ, where (x :: τ) ∈ Γ
  [(where σ (lookup Γ x))
   ---------------------- "T-Var"
   (⊢ Γ x σ)]
  ; Γ ⊢ v :: (typeof v)
  [------------------- "T-Val"
   (⊢ Γ v (typeof v))]
  ; Γ ⊢ e1;e2 :: σ, where e2 :: σ
  [(⊢ Γ e_2 σ_2)
   ------------------------ "T-Seq"
   (⊢ Γ (seq e_1 e_2) σ_2)]
  ; Γ ⊢ 𝛿(e...) :: τ
  [(⊢ Γ e σ) ...
   (where σ_res (res-type-primop op σ ...))
   ---------------------------------------- "T-Primop"
   (⊢ Γ (pcall op e ...) σ_res)]
  ; Γ ⊢ m(...) = e :: (mtag "m") 
  [----------------------------------------------------- "T-MD"
   (⊢ Γ (mdef mname ((:: x τ_arg) ...) e) (mtag mname))]
  ; Γ ⊢ (|e|) :: σ, where e :: σ
  [(⊢ Γ e σ)
   ------------------ "T-EvalGlobal"
   (⊢ Γ (evalg e) σ)]
  )

(test-equal (judgment-holds (⊢ () 1 Int64)) #true)
(test-equal (judgment-holds (⊢ () (evalg m) (mtag "m"))) #true)
(test-equal (judgment-holds (⊢ ((x String) (y Bool) (y Float64)) (seq 4 y) Bool)) #true)
(test-equal (judgment-holds (⊢ ((b Bool)) (pcall && b true) Bool)) #true)
(test-equal (judgment-holds (⊢ ((x String) (y Float64)) (pcall + x 1) Float64)) #false)
(test-equal (judgment-holds (⊢ () (mdef "test" () 1) (mtag "test"))) #true)

;; ==================================================
;; Optimization Judgment for Expression
;; ==================================================

;; Determines if the optimized expression is a valid optimization
(define-judgment-form WA-opt
  #:mode (~~> I I I I)
  #:contract (~~> Γ Φ (evalt MT e) (evalt MT e))
  ; Γ ⊢ Φ (|v|)_MT ~~> (|v|)_MT' where v != m
  [(where #f (is-mval v))
   -------------------------------------- "OE-Val"
   (~~> Γ Φ (evalt MT v) (evalt MT_P v))]
  ; Γ ⊢ Φ (|m|)_MT ~~> (|m|)_MT'
  [(where #t (inMTdomWrap MT mname))
   ------------------------------------------------------------ "OE-ValFun"
   (~~> Γ Φ (evalt MT (mval mname)) (evalt MT_P (mval mname)))]
  ; Γ ⊢ Φ (|x|)_MT ~~> (|x|)_MT'
  [-------------------------------------- "OE-Var"
   (~~> Γ Φ (evalt MT x) (evalt MT_P x))]
  ; Γ ⊢ Φ (|(|x|)|)_MT ~~> (|(|x|)|)_MT'
  [------------------------------------------------------ "OE-Global"
   (~~> Γ Φ (evalt MT (evalg e)) (evalt MT_P (evalg e)))]
  ; Γ ⊢ Φ (|(|x|)_MT_L|)_MT ~~> (|(|x|)_MT_L|)_MT'
  [---------------------------------------------------------------- "OE-Local"
   (~~> Γ Φ (evalt MT (evalt MT_L e)) (evalt MT_P (evalt MT_L e)))]
  ; Γ ⊢ Φ (|md|)_MT ~~> (|md|)_MT'
  [---------------------------------------- "OE-MD"
   (~~> Γ Φ (evalt MT md) (evalt MT_P md))]
  ; Γ ⊢ Φ (|e1;e2|)_MT ~~> (|e1';e2'|)_MT
  [(~~> Γ Φ (evalt MT e_1) (evalt MT_P e_1P))
   (~~> Γ Φ (evalt MT e_2) (evalt MT_P e_2P))
   ------------------------------------------ "OE-Seq"
   (~~> Γ Φ (evalt MT (seq e_1 e_2))
          (evalt MT_P (seq e_1P e_2P)))]
  ; Γ ⊢ Φ (|𝛿(e...)|)_MT ~~> (|𝛿(e'...)|)_MT
  [(~~> Γ Φ (evalt MT e) (evalt MT_P e_P)) ...
   ------------------------------------------- "OE-Primop"
   (~~> Γ Φ (evalt MT (pcall op e ...))
          (evalt MT_P (pcall op e_P ...)))]
  ; Γ ⊢ Φ (|m(e...)|)_MT -> (|m(e'...)|)_MT
  [(~~> Γ Φ (evalt MT e_arg) (evalt MT_P e_argP))
   (~~> Γ Φ (evalt MT e) (evalt MT_P e_P)) ...
   ---------------------------------------------- "OE-Call"
   (~~> Γ Φ (evalt MT (mcall e_arg e ...))
          (evalt MT_P (mcall e_argP e_P ...)))]
  ; Γ ⊢ Φ (|m(nv...)|)_MT ~~> (|nothing; e_body|)_MT' where is is mval
  [(where (σ ...) (typeof-nv-tuple Γ (nv ...)))
   (where (mdef mname ((:: x _) ...) e_mbody)
          (getmd MT mname (σ ...)))
   (where e_b (subst-n e_mbody (x nv) ...))
   (~~> Γ Φ (evalt MT e_b) (evalt MT_P e_P))
   ----------------------------------------------- "OE-Inline"
   (~~> Γ Φ (evalt MT (mcall (mval mname) nv ...))
          (evalt MT_P (seq nothing e_P)))]
  ; Γ ⊢ Φ (|m(e...)|)_MT ~~> (|m_direct(e'...)|)_MT' where m_direct is a singleton method
  [(~~> Γ Φ (evalt MT e) (evalt MT_P e_P)) ...
   (⊢ Γ e_P σ) ...
   (where mname_opt (get-opt-method Φ (mdef mname (σ ...))))
   (where #t ,(equal? (term mname_P) (term mname_opt)))
   --------------------------------------------------------- "OE-Specialize"
   (~~> Γ Φ (evalt MT (mcall (mval mname) e ...))
          (evalt MT_P (mcall (mval mname_P) e_P ...)))]
  ; Convert variable to mval
  [(where mname ,(~a (term x_mname)))
   (where undeclared-var (lookup Γ x_mname))
   (~~> Γ Φ (evalt MT (mcall (mval mname) e ...)) (evalt MT_P e_p))
   ---------------------------------------------------------------- "OE-MName"
    (~~> Γ Φ (evalt MT (mcall x_mname e ...)) (evalt MT_P e_p))]
  )

(define addxy-intNum (term (mdef "add" ((:: x Int64) (:: y Number)) (pcall + x y))))
(define MT-addintNum (term (,addxy-intNum • ∅)))
(define MT-addintint-addintNum (term ((mdef "add_P" ((:: x Int64) (:: y Int64)) (pcall + x y))
                                          • ,MT-addintNum)))
(test-equal (judgment-holds (~~> ((x Int64)) () (evalt ∅ x) (evalt ∅ x))) #t)
(test-equal (judgment-holds (~~> () () (evalt ∅ (evalg 1.1)) (evalt ∅ (evalg 1.1)))) #t)
(test-equal (judgment-holds (~~> () () (evalt ∅ (evalt ∅ true))
                                 (evalt (,addxy-intNum • ∅) (evalt ∅ true)))) #t)
(test-equal (judgment-holds (~~> () () (evalt ∅ (evalt ∅ true))
                                 (evalt (,addxy-intNum • ∅) (evalt (,addxy-intNum • ∅) true)))) #f)
(test-equal (judgment-holds (~~> () () (evalt ∅ (evalg 1.1)) (evalt ∅ (evalg 1.1)))) #t)
(test-equal (judgment-holds (~~> ((x Int64)) () (evalt ∅ x) (evalt ∅ x))) #t)
(test-equal (judgment-holds (~~> () () (evalt (,id-fInt • ∅) (mval "func"))
                                 (evalt (,id-fInt • (,addxy-intNum • ∅)) (mval "func")))) #t)
(test-equal (judgment-holds (~~> () () (evalt ∅ (mval "func")) (evalt ∅ (mval "func")))) #f)
(test-equal (judgment-holds (~~> () () (evalt ∅ ,addxy-intNum) (evalt ∅ ,addxy-intNum))) #t)
(test-equal (judgment-holds (~~> () () (evalt (,id-fInt • ∅) y)
                                    (evalt (,id-fInt • ∅) y))) #true)
(test-equal (judgment-holds (~~> () () (evalt ((mdef "func" () 3) • ∅) (mcall (mval "func")))
                                    (evalt ((mdef "func" () 3) • ∅) (seq nothing 3)))) #true)
(test-equal (judgment-holds (~~> () () (evalt ((mdef "func" () 3) • ∅) (seq 1 (mcall (mval "func"))))
                                 (evalt ((mdef "func" () 3) • ∅) (seq 1 (seq nothing 3))))) #true)
(test-equal (judgment-holds (~~> ((y Int64)) (((mdef "add" (Int64 Int64)) "add_P"))
                                 (evalt ,MT-addintNum (mcall (mval "add") 1 (pcall + y y)))
                                 (evalt ,MT-addintint-addintNum
                                        (mcall (mval "add_P") 1 (pcall + y y))))) #true)
(test-equal (judgment-holds (~~> ((y Int64)) (((mdef "add" (Int64 Bool)) "add_P"))
                                 (evalt ,MT-addintNum (mcall (mval "add") 1 (pcall + y y)))
                                 (evalt ,MT-addintint-addintNum
                                        (mcall (mval "add_P") 1 (pcall + y y))))) #false)

;; ==================================================
;; Optimization Judgment for Method Definition
;; ==================================================

;; Determines if the optimized method definition is a valid optimization
(define-judgment-form WA-opt
  #:mode (md~~> I I I I I)
  #:contract (md~~> Φ MT MT e e)
  [(where e_P (subst-n e_Pbody (x_P x) ...))
   (~~> ((x τ) ...) Φ (evalt MT e) (evalt MT_P e_P))
   ----------------------------------------------------- "OD-MD"
   (md~~> Φ MT MT_P (mdef mname ((:: x τ) ...) e)
          (mdef mname ((:: x_P τ) ...) e_Pbody))]
  )
(define func-return1 (term (mdef "func" () 1)))
(define new-call-func-withy (term (mdef "new" ((:: y Int64)) (mcall func y))))
(test-equal (judgment-holds (md~~> () (,id-fInt • (,func-return1 • ∅))
                                   (,id-fInt • (,func-return1 • ∅))
                                   ,new-call-func-withy
                                   (mdef "new" ((:: x Int64)) (seq nothing x)))) #true)
(test-equal (judgment-holds (md~~> () ((mdef "func" ((:: x Int64)) 1) • (,id-fInt • ∅))
                                   (,id-fInt • ∅) ,new-call-func-withy
                                   (mdef "new" ((:: x Int64))(seq nothing 1)))) #true)


;; ==================================================
;; Optimization Judgment for Method Table
;; ==================================================

;; -------------------- Helpers

;; Determines if the fourth method table is a valid optimization of the third.
;; This determination is made by assuming the methods of the third and fourth
;; tables are evaluated in the context of the first and second tables respectively
(define-metafunction WA-opt
  related-mt-acc : Φ MT MT MT MT -> boolean
  [(related-mt-acc Φ MT_orig1 MT_orig2 ∅ ∅) #t]
  [(related-mt-acc Φ MT_orig1 MT_orig2 (md • MT) ∅) #f]
  [(related-mt-acc Φ MT_orig1 MT_orig2 ∅ (md • MT)) #t]
  [(related-mt-acc Φ MT_orig1 MT_orig2 (md_1 • MT_1) (md_2 • MT_2))
   (related-mt-acc Φ MT_orig1 MT_orig2 MT_1 MT_2)
   (side-condition (judgment-holds (md~~> Φ MT_orig1 MT_orig2 md_1 md_2)))]
  [(related-mt-acc _ _ _ _ _) #f]
  )

;; Determines if the given name does not exist in the given table
(define-metafunction WA-opt
  not-contain-name : MT mname -> boolean
  [(not-contain-name (md • MT_rest) mname)
   ,(and (not (term (contains-name-e md ,(string->symbol (term mname)))))
         (term (not-contain-name MT_rest mname)))]
  [(not-contain-name ∅ mname) #t]
  )

;; Determines if there are no names in the second table that are in the first
(define-metafunction WA-opt
  no-repeat-names : e MT MT -> boolean
  [(no-repeat-names e MT_orig ((mdef mname _ _) • MT_rest))
   ,(and (not (term (contains-name-e e ,(string->symbol (term mname)))))
         (term (not-contain-name MT_orig mname))
         (term (no-repeat-names e MT_orig MT_rest)))]
  [(no-repeat-names e MT_orig ∅) #t]
  )

;; -------------------- Main Rule

;; Determines if the optimized method table is a valid optimization
(define-judgment-form WA-opt
  #:mode (mt~~> I I I I)
  #:contract (mt~~> Φ e MT MT)
  [(where N_Len (length MT))
   (where N_PLen (length MT_P))
   (where #t ,(<= (term N_Len) (term N_PLen)))
   (where N_lenDiff ,(- (term N_PLen) (term N_Len)))
   (where #t (related-mt-acc Φ MT MT_P MT (drop N_lenDiff MT_P)))
   (where #t (no-repeat-names e MT (take N_lenDiff MT_P)))
   (where #t ,(andmap
               (λ (sig-mname-pair) (judgment-holds (wd~~> Φ MT MT_P ,sig-mname-pair)))
               (term Φ)))
   -------------------------------------------------------------- "OT-MethodTable"
   (mt~~> Φ e MT MT_P)]
  )

(test-equal (judgment-holds (mt~~> () 1 ∅ ∅)) #t)
(test-equal (judgment-holds (mt~~> () true (,id-fInt • ∅) ∅)) #f)
(test-equal (judgment-holds (mt~~> () 1 ∅ (,new-call-func-withy • ∅))) #t)
(test-equal (judgment-holds (mt~~> () false (,id-fInt
                               •(,func-return1
                                 • (,new-call-func-withy • ∅)))
                              (,id-fInt
                               •(,func-return1
                                 • ((mdef "new" ((:: x Int64)) (seq nothing x)) • ∅))))) #t)

;; Determines if the optimized method table is a valid optimization
(define-judgment-form WA-opt
  #:mode (wd~~> I I I I)
  #:contract (wd~~> Φ MT MT (sig-σ mname))
  [(where (mdef mname ((:: x τ) ...) e_body)
          (getmd MT mname (σ ...)))
   (where (mdef mname_P ((:: x_P τ_P) ...) e_Pbody)
          (getmd MT_P mname_P (σ ...)))
   (~~> ((x σ) ...) Φ (evalt MT e_body)
        (evalt MT_P (subst-n e_Pbody (x_P x) ...)))
   ------------------------------------------------- "OT-MethodTable"
   (wd~~> Φ MT MT_P ((mdef mname (σ ...)) mname_P))]
  )

;; ==================================================
;; Optimization Reduction Helpers
;; ==================================================

;; -------------------- Typing

;; Gets the type of the given expression
(define-metafunction WA-opt
  get-type :  Γ e -> maybe-τ
  [(get-type Γ e) τ
   (where (⊢ _ _ τ)
          ,(let ((type-derivation (build-derivations (⊢ Γ e τ))))
             (if (cons? type-derivation)
                 (derivation-term (first type-derivation)) (term type-err))))]
  [(get-type _ _) type-err]
  )

;; Gets the types of the given expressions
(define-metafunction WA-opt
  get-types :  Γ e ... -> (maybe-τ ...)
  [(get-types Γ e ...) ((get-type Γ e) ...)]
  )

;; -------------------- Direct Call

;; Determines if the direct call env contains the given name
(define-metafunction WA-opt
  contains-name-Φ : Φ string -> boolean
  [(contains-name-Φ (_ ... (sig-σ string) _ ...) string)
   #t]
  [(contains-name-Φ ((sig-σ string_mname) ...) string_arg)
   #f]
  )

;; Generates a name that is not in the method table or direct call env
(define-metafunction WA-opt
  gen-name : MT Φ -> string
  [(gen-name MT Φ)
   ,(~a (term x_gen))
   (where x_gen ,(gensym))
   (where #f (contains-name-MT MT x_gen))
   (where #f (contains-name-Φ Φ ,(~a (term x_gen))))])

;; -------------------- Inlining

;; Gets the inline count valued paired to the given signature in the inline env
(define-metafunction WA-opt
  get-inline-count : Δ sig-τ -> natural
  [(get-inline-count (_ ... (sig-τ N_count) _ ...) sig-τ)
   N_count]
  [(get-inline-count _ _)
   0]
  )

;; Updates the given signature with the given value in the inline env
(define-metafunction WA-opt
  update-inline-count : Δ sig-τ natural -> Δ
  [(update-inline-count (any_begin ... (sig-τ _) any_end ...) sig-τ N)
   (any_begin ... (sig-τ N) any_end ...)]
  [(update-inline-count (any_list ...) sig-τ N)
   ((sig-τ N) any_list ...)]
  )

;; Updates the given signature with a value of 1 greater than then current in the inline env
(define-metafunction WA-opt
  increment-inline-count : Δ sig-τ -> Δ
  [(increment-inline-count Δ sig-τ)
  (update-inline-count Δ sig-τ ,(+ (term (get-inline-count Δ sig-τ)) 1))])

;; Gets the signature and optimized method name of the callee of the given method call
(define-metafunction WA-opt
  get-opt-name-and-sig : Γ Φ MT mc -> (< maybe-mname md >) or nothing
  [(get-opt-name-and-sig Γ Φ MT (mcall (mval mname) e ...))
   (< maybe-mname (mdef mname ((:: x σ) ...) e_body) >)
   (where #f ,(andmap (λ (expr) (term (is-nv ,expr))) (term (e ...))))
   (where #f (contains-name-Φ Φ ,(~a (term mname))))
   (where (σ ...) (get-types Γ e ...))
   (where (mdef mname ((:: x _) ...) e_body) (getmd MT mname (σ ...)))
   (where maybe-mname (get-opt-method Φ (mdef mname (σ ...))))]
  [(get-opt-name-and-sig _ _ _ _) nothing])


;; ==================================================
;; Expression Optimization
;; ==================================================

;; < Γ Δ Φ (|X[e]|)_MT > --> < Γ Δ' Φ' (|X[e']|)_MT' >
(define ->optimize
  (reduction-relation 
   WA-opt
   #:domain st-opt
   ; < Γ Δ Φ (|X[m(nv...)]|)_MT > --> < Γ Δ' Φ (|X[nothing;e]|)_MT >
   ; where e is is m body
   [--> (< Γ Δ Φ (evalt MT (in-hole E (mcall (mval mname) nv ...))) >)
        (< Γ Δ_P Φ (evalt MT (in-hole E (seq nothing e))) >)
        (where (σ ...) (typeof-nv-tuple Γ (nv ...)))
        (where (mdef mname ((:: x τ) ...) e_mbody) (getmd MT mname (σ ...)))
        (where sig-τ (mdef mname (τ ...)))
        (where N_count (get-inline-count Δ sig-τ))
        (side-condition (< (term N_count) MAX_INLINE_COUNT))
        (where Δ_P (increment-inline-count Δ sig-τ))
        (where e (subst-n e_mbody (x nv) ...))
        OE-Inline]
   ; Convert variable to mval
   [--> (< Γ Δ Φ (evalt MT (in-hole E (mcall x_mname e ...))) >)
        (< Γ Δ Φ (evalt MT (in-hole E (mcall (mval mname) e ...))) >)
        (where mname ,(~a (term x_mname)))
        (where undeclared-var (lookup Γ x_mname))
        OE-MName]
   ; < Γ Δ Φ (|X[m(e...)]|)_MT > --> < Γ Δ Φ (|X[m_direct(e...)]|)_MT >
   ; where (m(τ...) m_direct) ∈ Φ
   [--> (< Γ Δ Φ (evalt MT (in-hole E (mcall (mval mname) e ...))) >)
        (< Γ Δ Φ (evalt MT (in-hole E (mcall (mval mname_opt) e ...))) >)
        (where mc (mcall (mval mname) e ...))
        (where (< mname_opt _ >) (get-opt-name-and-sig Γ Φ MT mc))
        OE-Direct-Existing]
   ; < Γ Δ Φ (|X[m(e...)]|)_MT > --> < Γ Δ Φ' (|X[m_direct(e...)]|)_MT >
   ; where (m(τ...) m_direct) ∉ Φ
   [--> (< Γ Δ Φ (evalt MT (in-hole E (mcall (mval mname) e ...))) >)
        (< Γ Δ Φ_P (evalt MT_P (in-hole E (mcall (mval mname_opt) e ...))) >)
        (where mc (mcall (mval mname) e ...))
        (where (< nothing (mdef mname ((:: x σ) ...) e_body) >)
               (get-opt-name-and-sig Γ Φ MT mc))
        (where mname_opt (gen-name MT Φ))
        (where md_opt (mdef mname_opt ((:: x σ) ...) e_body))
        (where MT_P (md_opt • MT))
        (where (any_optpair ...) Φ)
        (where Φ_P (((mdef mname (σ ...)) mname_opt) any_optpair ...))
        OE-Direct-New]
))

;; Generates the optimized method table
(define-metafunction WA-opt
  generate-mtopt : natural L MT md MT -> MT
  [(generate-mtopt N_MTlen L MT md MT_P) MT_PP
   (where MT_0toL-1 (drop ,(- (term N_MTlen) (term L)) MT))
   (where MT_0toL (md • MT_0toL-1))
   (where MT_L+1toN (take ,(- (term N_MTlen) (term L) 1) MT))
   (where N_MTPlen (length MT_P))
   (where MT_N+1toK (take ,(- (term N_MTPlen) (term N_MTlen)) MT_P))
   (where MT_PP (append MT_N+1toK (append MT_L+1toN MT_0toL)))])


;; ==================================================
;; Method Table Optimization
;; ==================================================

;; (< Φ MT L >) (< Φ' MT' L' >)
(define ->optimize-mt
  (reduction-relation 
   WA-opt
   #:domain st-mtopt
   [--> (< Φ MT L >) (< Φ_P MT_PP L_P >)
        (where N_MTlen (length MT))
        (side-condition (< (term L) (term N_MTlen)))
        (where (mdef mname ((:: x τ) ...) e_body) (get-element L MT))
        (where ((< _ _ Φ_P (evalt MT_P e_bodyP) >) _ ...)
               ,(apply-reduction-relation*
                 ->optimize
                 (term (< ((x τ) ...) () Φ (evalt MT e_body) >))))
        (where md_opt (mdef mname ((:: x τ) ...) e_bodyP))
        (where MT_PP (generate-mtopt N_MTlen L MT md_opt MT_P))
        (where L_P ,(+ 1 (term L)))
        OE-Mt]
   ))

;; Optimizes the given method table
(define-metafunction WA-opt
  opt-mt : MT -> ((< Φ MT_opt L >) ...)
  [(opt-mt MT)
   ,(apply-reduction-relation*
            ->optimize-mt
            (term (< () MT 0 >)))])

;; Optimizes the given expression
(define-metafunction WA-opt
  opt-e : Γ MT e -> (< Φ MT e >)
  [(opt-e Γ MT_in e_in)
   (< Φ_out MT_out e_out >)
   (where ((< Φ MT_opt _ >) _ ...) (opt-mt MT_in))
   (where ((< Γ_out Δ_out Φ_out (evalt MT_out e_out) >) _ ...)
          ,(apply-reduction-relation*
            ->optimize
            (term (< Γ () Φ (evalt MT_opt e_in) >))))]
  )

;; ==================================================
;; Optimization Reduction/Judgment Correspondence
;; ==================================================

; Determines if the optimzaton of the given expression a
; valid optimizaton given the optimization judgments
(define-metafunction WA-opt
  valid-optimization : Γ MT e -> boolean
  [(valid-optimization Γ MT_in e_in)
   ,(and (judgment-holds (mt~~> Φ_out e_in MT_in MT_out))
         (judgment-holds (~~> Γ Φ_out (evalt MT_in e_in) (evalt MT_out e_out))))
   (where (< Φ_out MT_out e_out >) (opt-e Γ MT_in e_in))]
  [(valid-optimization _ _ _) #f])

;;;;;;;;;;;;;;;
;; Optimizer
;;;;;;;;;;;;;;;

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
        (< MT_g (in-hole C (evalg (in-hole X (evalt MT_gP (mcall (mval mname) v ...))))) >)
        (where ((< _ MT_gP _ >) _ ...) (opt-mt MT_g))
        E-CallGlobal]
   ; <MTg, C[(| X[m(v...)] |)_MT]> --> <MTg, C[(| X[e[x...:=v...]] |)_MT]>
   [--> (< MT_g (in-hole C (evalt MT (in-hole X (mcall (mval mname) v ...)))) >)
        (< MT_g (in-hole C (evalt MT (in-hole X (subst-n e (x v) ...)))) >)
        (where (σ ...) (typeof-tuple (v ...)))
        (where (mdef mname ((:: x _) ...) e) (getmd MT mname (σ ...)))
        E-CallLocal]
))

;; Runs program normally while possible but optimized
(define-metafunction WA-full
  run-normal-opt : p -> (st ...)
  [(run-normal-opt p) 
   ,(apply-reduction-relation* ->step-opt (term (< ∅ p >)))]
)

;; Runs program to normally then runs program in error reduction
(define-metafunction WA-full
  run-opt : p -> (stf ...)
  [(run-opt p)
   ; for every end state of normal execution, try step to an error
   ; (if the state st is good, (run-error st) will simply return the same (st) back))
   (flatten ((run-error st) ...))
   ; run program normally
   (where (st ...) (run-normal-opt p))]
)

;; Evaluates a program in the empty table
;; and returns only the result
;; (throwing away the resulting global table)
(define-metafunction WA-full
  run-to-r-opt : p -> r
  [(run-to-r-opt p)
   r
   (where (( < MT r >)) (run-opt p))]
)
