;;; MIT License
;;; Copyright (C) 2025 AIAOS Framework contributors
;;;
;;; product-closed-loop.scm — Enterprise Product Development Closed-Loop
;;; Part 1: Boot, logging, audit, omnicode integration
;;; 6-stage pipeline: PLAN -> DESIGN -> IMPL -> TEST -> AUDIT -> DEPLOY

(require-extension chicken.io chicken.string chicken.time chicken.process chicken.port srfi-1 json)
(import chicken.base)

(define AIAOS-HOME /home/aiaos/aiaos)
(define OBJECTIVES-DIR (string-append AIAOS-HOME /objectives))
(define STATUS-DIR (string-append AIAOS-HOME /status))
(define LOG-DIR (string-append AIAOS-HOME /logs))
(define DEPLOY-BASE /home/aiaos/deploy)
(define CLOSED-LOOP-LOG (string-append LOG-DIR /product-closed-loop.log))

(load (string-append OBJECTIVES-DIR /product-lifecycle.scm))
(load (string-append OBJECTIVES-DIR /deploy-pipeline.scm))
(condition-case (load (string-append OBJECTIVES-DIR /claw2ee-bridge.scm)) (ex () #f))
(condition-case (load (string-append OBJECTIVES-DIR /omnicode-bridge.scm)) (ex () #f))

(define (ts)
  (let* ((now (current-seconds)) (s (modulo now 60)) (m (modulo (quotient now 60) 60))
         (h (modulo (quotient now 3600) 24)) (d (quotient now 86400)))
    (string-append (number->string (+ 1970 (quotient d 365))) -
      (number->string (+ 1 (quotient (modulo d 365) 30))) -
      (number->string (+ 1 (modulo d 30))) T
      (number->string h) : (number->string m) : (number->string s) Z)))

(define (log! msg)
  (let ((e (string-append [ (ts) ] [CLOSED-LOOP]  msg)))
    (display e) (newline)
    (condition-case
      (with-output-to-file CLOSED-LOOP-LOG
        (lambda () (display e) (newline)) append: #t)
      (ex () (void)))))

(define (shell cmd)
  (with-input-from-pipe cmd
    (lambda ()
      (let loop ((l '()) (ln (read-line)))
        (if (eof-object? ln) (string-intersperse (reverse l) n)
          (loop (cons ln l) (read-line)))))))

(define (ensure-dir dir) (condition-case (system (string-append mkdir -p  dir)) (ex () #f)))

(define (submit-audit product-id stage status detail)
  (let* ((payload (string-append "source":"product-closed-loop")))
    (condition-case
      (let ((r (shell (string-append curl  dir)) (ex () #f)))

(define (submit-audit product-id stage status detail)
  (let* ((payload (string-append "product_id":" product-id
                 ")))
    (condition-case
      (let ((r (shell (string-append curl  dir)) (ex () #f)))

(define (submit-audit product-id stage status detail)
  (let* ((payload (string-append "stage":" (stage-name stage) ")))
    (condition-case
      (let ((r (shell (string-append curl  dir)) (ex () #f)))

(define (submit-audit product-id stage status detail)
  (let* ((payload (string-append "status":" status
                 ")))
    (condition-case
      (let ((r (shell (string-append curl  dir)) (ex () #f)))

(define (submit-audit product-id stage status detail)
  (let* ((payload (string-append "detail":" detail ")))
    (condition-case
      (let ((r (shell (string-append curl  dir)) (ex () #f)))

(define (submit-audit product-id stage status detail)
  (let* ((payload (string-append "timestamp": (number->string (current-seconds)) )))
    (condition-case
      (let ((r (shell (string-append curl -s -X POST http://localhost:8082/api/audit/checkpoint -H Content-Type: application/json -d " payload "))))
        (log! (string-append Audit:  (stage-name stage) :  status)) r)
      (ex (msg) (log! (string-append Audit fail:  (condition->string msg))) #f))))

(define (expand-with-omnicode product-id stage)
  (let* ((payload (string-append "source":"product-closed-loop")))
    (condition-case
      (let ((r (shell (string-append curl  (condition->string msg))) #f))))

(define (expand-with-omnicode product-id stage)
  (let* ((payload (string-append "product_id":" product-id
                 ")))
    (condition-case
      (let ((r (shell (string-append curl  (condition->string msg))) #f))))

(define (expand-with-omnicode product-id stage)
  (let* ((payload (string-append "stage":" (stage-name stage) ")))
    (condition-case
      (let ((r (shell (string-append curl -s -X POST http://localhost:8769/api/expand -H Content-Type: application/json -d " payload "))))
        (log! (string-append OmniCode:  (stage-name stage))) r)
      (ex (msg) (log! (string-append OmniCode fail:  (condition->string msg))) #f))))
