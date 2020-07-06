#lang racket
(require redex)

(provide (all-defined-out)) ; export all definitions

;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Surface Language
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Grammar
;; ==================================================

(define-language WA ; World Age
  
;; -------------------- Main definitions
  
  ;; expression
  [e ::=
     v           ; value
     x           ; variable
     (seq e e)   ; sequence e1;e2
     (if e e e)
     mc   ; method call e(e...)
     (pcall op e ...)  ; primop call op(e...)
     md          ; method definition
     (evalg e)   ; global evaluation (|e|)
     ]
  ;; program (expression evaluated in the global context)
  [p ::= (evalg e)]
  ;; method definition mname(x::τ,...) = e
  [md ::= (mdef mname ((:: x τ) ...) e)]
  [mc ::= (mcall e e ...) ]
  
  ;; value
  [v ::=
     real     ; Racket real literal
     string   ; Racket string literal
     bool     ; true/false (as in Julia)
     nothing  ; unit value (as in Julia)
     m        ; method
     ]
  ;; method value
  [m ::= (mval mname)]
  
  ;; type tag
  [σ ::=
     Int64
     Float64
     String
     Bool
     Nothing      ; unit type (as in Julia)
     (mtag mname) ; type tag of method
                  ; (in Julia, it is denoted as typeof(mname))
     ]
  ;; type annotation
  [τ ::=
     σ        ; all type tags are valid annotations
     Number   ; abstract supertype
     Any      ; top type  (like in Julia)
     Bot      ; bottom type (Union{} in Julia)
     ]
  
;; -------------------- Aux
  
  ;; primitive operation
  [op ::= bin-arithop bin-boolop unary-boolop unary-void ==]
  [bin-arithop ::= + - * /]
  [bin-boolop ::= && ||]
  [unary-boolop ::= !]
  [unary-void ::= print @assert]
  ;; boolean value (like in Julia)
  [bool ::= true false]
  
  ;; method name
  [mname ::= string] ;variable-not-otherwise-mentioned
  ;; variable
  [x ::= variable-not-otherwise-mentioned]

  #:binding-forms ; allow for using built-in capture-avoiding subsitution
  (mdef mname ((:: x τ) ...) e #:refers-to (shadow x ...))
)

;; ==================================================
;; Judgments/Functions about Types
;; ==================================================

;; -------------------- Syntactic type equality

(define-metafunction WA
  type-eq : τ τ -> boolean
  [(type-eq τ τ) #t]
  [(type-eq _ _) #f]
)

(test-equal (term (type-eq Int64 Int64)) #t)
(test-equal (term (type-eq Any Any))     #t)

(test-equal (term (type-eq Nothing Any)) #f)
(test-equal (term (type-eq Int64 Bool))  #f)

;; --------------------------------------------------
;; Subtyping
;; --------------------------------------------------

;; -------------------- Nominal types

;; Returns declared supertype of nominal type
(define-metafunction WA
  get-supertype : τ -> τ
  [(get-supertype Int64)   Number]
  [(get-supertype Float64) Number]
  [(get-supertype τ)       Any]
)

(test-equal (term (get-supertype Float64))  (term Number))
(test-equal (term (get-supertype String))   (term Any))
(test-equal (term (get-supertype Nothing))  (term Any))
(test-equal (term (get-supertype Bot))      (term Any))
(test-equal (term (get-supertype Any))      (term Any))

;; -------------------- Subtyping of types

;; τ_1 <: τ_2
;; Subtyping between built-in types
(define-judgment-form WA
  #:contract (<: τ τ)
  #:mode (<: I I)
  ; τ <: Any
  [ ------------ S-Top
     (<: τ Any) ]
  ; Bot <: τ
  [ ---------------- S-Bot
    (<: Bot τ) ]
  ; τ <: τ
  [ ---------- S-Refl
    (<: τ τ) ]
  ; Reductive version of
  ; τ_1 <: τ_2 /\ τ_2 <: τ_3  =>  τ_1 <: τ_3
  ; NOTE all built-in types are nominal,
  ;      so it's safe to use get-supertype on τ_1
  [ (where τ_2 (get-supertype τ_1))
    (where #f  (type-eq τ_1 τ_2))   ; make sure τ_1 != τ_2 to stop recursion
    
    (<: τ_2 τ_3)
   -------------- S-Trans
    (<: τ_1 τ_3) ]
)

(test-equal (judgment-holds (<: Float64 Number))  #t)
(test-equal (judgment-holds (<: Float64 Any))     #t)
(test-equal (judgment-holds (<: Bot Float64))     #t)
(test-equal (judgment-holds (<: String Any))      #t)

(test-equal (judgment-holds (<: String Bool))     #f)
(test-equal (judgment-holds (<: Float64 Nothing)) #f)
(test-equal (judgment-holds (<: Float64 Bot))     #f)

;; -------------------- Subtyping of tuple-types

;; (τ_11, ..., τ_1n) <: (τ_21, ..., τ_21)
(define-judgment-form WA
  #:contract (<:-tuple (τ ...) (τ ...))
  #:mode (<:-tuple I I)
  ; τ_11 <: τ_21 ... τ_1n <: τ_2n  =>  (τ_11,...,τ_1n) <: (τ_21,...,τ_21)
  [        (<: τ_1 τ_2) ...
   ----------------------------------- S-Tuple
   (<:-tuple (τ_1 ..._n) (τ_2 ..._n)) ]
  ; NOTE _n makes sure the length is the same
)

(test-equal (judgment-holds (<:-tuple () ())) #t)
(test-equal (judgment-holds (<:-tuple (Int64) (Int64))) #t)
(test-equal (judgment-holds (<:-tuple (Int64 Bool) (Any Bool))) #t)

(test-equal (judgment-holds (<:-tuple (Int64) (Any Bool))) #f)

;; --------------------------------------------------
;; Type Equivalence
;; --------------------------------------------------

;; -------------------- Equivalence of types

;; τ_1 == τ_2
(define-judgment-form WA
  #:contract (== τ τ)
  #:mode (== I I)
  ; τ_1 <: τ_2  /\ τ_2 <: τ_1  =>  τ_1 == τ_3
  [  (<: τ_1 τ_2)
     (<: τ_2 τ_1)
   --------------- Eq-Sub
    (== τ_1 τ_2) ]
)

(test-equal (judgment-holds (== Float64 Float64)) #t)

(test-equal (judgment-holds (== Float64 Number))  #f)
(test-equal (judgment-holds (== Number Float64))  #f)

;; -------------------- Equivalence of tuple-types

;; (τ_11, ..., τ_1n) == (τ_21, ..., τ_21)
(define-judgment-form WA
  #:contract (==-tuple (τ ...) (τ ...))
  #:mode (==-tuple I I)
  ; τ_11 == τ_21 ... τ_1n == τ_2n  =>  (τ_11,...,τ_1n) == (τ_21,...,τ_21)
  [        (== τ_1 τ_2) ...
   ----------------------------------- Eq-Tuple
   (==-tuple (τ_1 ..._n) (τ_2 ..._n)) ]
)

(test-equal (judgment-holds (==-tuple () ())) #t)
(test-equal (judgment-holds (==-tuple (Int64) (Int64))) #t)

(test-equal (judgment-holds (==-tuple (Int64) (Float64))) #f)
(test-equal (judgment-holds (==-tuple (Int64) (Int64 Int64))) #f)

;; ==================================================
;; Judgments/Functions about Expressions
;; ==================================================

;; -------------------- Syntactic expression equality

(define-metafunction WA
  expr-eq : e e -> boolean
  [(expr-eq e e) #t]
  [(expr-eq _ _) #f]
)