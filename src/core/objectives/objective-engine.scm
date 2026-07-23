;;; objective-engine.scm

(import chicken.base)
(import chicken.condition)
(import chicken.process)
(import chicken.process-context)
(import chicken.string)
(import chicken.io)
(import chicken.time)
(require-extension json)
(require-extension srfi-1)
(require-extension srfi-69)
(require-extension srfi-18)


;; =============================================================================
;; Utilities
(define (timestamp)
  (let* ((now (seconds-since-epoch))
         (secs (modulo now 60))
         (mins (modulo (quotient now 60) 60))
         (hours (modulo (quotient now 3600) 24)))
    (string-append (number->string hours) ":" (number->string mins) ":" (number->string secs) "Z")))
;; =============================================================================

