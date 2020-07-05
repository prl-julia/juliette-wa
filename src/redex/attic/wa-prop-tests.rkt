#lang racket
(require redex)

(require "wa-surface.rkt")   ; import surface language
(require "wa-full.rkt")      ; import language semantics
(require "wa-examples.rkt")  ; import examples
(require "wa-optimizer.rkt") ; import language with optimization

(provide (all-defined-out)) ; export all definitions
  
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Language Semantics Properties
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Determinism
;; ==================================================

(test-equal (judgment-holds (p-deterministic ,p-simple-3)) #t)
(test-equal (judgment-holds (p-deterministic ,p-+bad-2))   #t)

;(redex-check WA-full p (judgment-holds (p-deterministic p)) #:attempts 10000)

;; ==================================================
;; Correctness of optimization
;; ==================================================

(test-equal (judgment-holds (optimization-correct ,p-simple-3)) #t)
(test-equal (judgment-holds (optimization-correct ,p3-1))       #t)
(test-equal (judgment-holds (optimization-correct ,p3-2))       #t)

;(redex-check WA-opt p (judgment-holds (optimization-correct p)) #:attempts 20000)
