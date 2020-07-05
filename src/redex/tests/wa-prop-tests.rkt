#lang racket
(require redex)

(require "../core/wa-surface.rkt")   ; import surface language
(require "../core/wa-full.rkt")      ; import language semantics
(require "../wa-examples.rkt")       ; import examples

(provide (all-defined-out)) ; export all definitions
  
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;; Language Semantics Properties
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;; ==================================================
;; Determinism
;; ==================================================

(test-equal (judgment-holds (p-deterministic ,p-simple-3)) #t)
(test-equal (judgment-holds (p-deterministic ,p-+bad-2))   #t)

(redex-check WA-full p (judgment-holds (p-deterministic p)) #:attempts 10000)

;; ==================================================
;; Correctness of optimization
;; ==================================================

; TODO
