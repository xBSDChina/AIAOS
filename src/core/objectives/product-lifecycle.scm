;;; MIT License
;;; Copyright (C) 2025 AIAOS Framework contributors
;;;
;;; product-lifecycle.scm — Enterprise Product Development Lifecycle
;;; Supports 6-stage closed-loop: PLAN → DESIGN → IMPL → TEST → AUDIT → DEPLOY
;;; Integrates claw2ee (port 8082) and omniCode (port 8769) via HTTP APIs

(require-extension chicken.io chicken.string chicken.time chicken.process chicken.file srfi-1 json)
(import chicken.base chicken.port chicken.condition)

;; =============================================================================
;; Stage Definitions (unchanged from original)
;; =============================================================================
(define STAGES
  '((plan . "PLAN") (design . "DESIGN") (impl . "IMPL")
    (test . "TEST") (audit . "AUDIT") (deploy . "DEPLOY")))
(define STAGE-ORDER '(plan design impl test audit deploy))

(define (stage-name stage)
  (let ((p (assoc stage STAGES)))
    (if p (cdr p) (string-upcase (symbol->string stage)))))

(define (stage-index stage)
  (let loop ((lst STAGE-ORDER) (i 0))
    (if (null? lst) -1
      (if (eq? (car lst) stage) i (loop (cdr lst) (+ i 1))))))

(define (next-stage stage)
  (let ((i (stage-index stage)))
    (if (and (>= i 0) (< i (- (length STAGE-ORDER) 1)))
      (list-ref STAGE-ORDER (+ i 1)) #f)))

(define DEPLOY-BASE "/home/aiaos/deploy")
(define PRODUCTS-DIR (string-append DEPLOY-BASE "/products"))
(define REPORTS-DIR (string-append DEPLOY-BASE "/reports"))

(define (stage-dir stage) (string-append DEPLOY-BASE "/stages/" (stage-name stage)))
(define (stage-artifact stage pid)
  (string-append (stage-dir stage) "/" pid "-" (stage-name stage) ".scm"))
(define (product-manifest pid) (string-append PRODUCTS-DIR "/" pid ".manifest.json"))
(define (product-dir pid) (string-append PRODUCTS-DIR "/" pid))
(define (report-dir) REPORTS-DIR)

(define (validate-transition from-stage to-stage pid)
  (let ((fi (stage-index from-stage)) (ti (stage-index to-stage)))
    (and (>= fi 0) (= ti (+ fi 1)) (string? pid) (> (string-length pid) 0))))

(define (ensure-stage-dirs!)
  (for-each (lambda (s) (system (string-append "mkdir -p " (stage-dir s)))) STAGE-ORDER)
  (system (string-append "mkdir -p " PRODUCTS-DIR))
  (system (string-append "mkdir -p " REPORTS-DIR))
  (system (string-append "mkdir -p " DEPLOY-BASE "/logs"))
  (system (string-append "mkdir -p " DEPLOY-BASE "/status")))

(define (list-products)
  (let ((d PRODUCTS-DIR))
    (if (file-exists? d) (glob (string-append d "/*.manifest.json")) '())))

(define (product-status pid)
  (let ((p (product-manifest pid)))
    (if (file-exists? p) (call-with-input-file p (lambda (i) (read-string #f i))) #f)))

;; =============================================================================
;; Utility Functions
;; =============================================================================
(define (ts)
  (let* ((now (current-seconds))
         (s (modulo now 60)) (m (modulo (quotient now 60) 60))
         (h (modulo (quotient now 3600) 24)) (d (quotient now 86400)))
    (string-append (number->string (+ 1970 (quotient d 365))) "-"
      (number->string (+ 1 (quotient (modulo d 365) 30))) "-"
      (number->string (+ 1 (modulo d 30))) "T"
      (number->string h) ":" (number->string m) ":" (number->string s) "Z")))

(define (shell cmd)
  (with-input-from-pipe cmd
    (lambda ()
      (let loop ((l '()) (ln (read-line)))
        (if (eof-object? ln) (string-intersperse (reverse l) "\n") (loop (cons ln l) (read-line)))))))

(define (write-artifact path content)
  (call-with-output-file path (lambda (out) (display content out)))
  (display (string-append "  [Artifact] " path "\n")))

(define (read-artifact path)
  (if (file-exists? path)
      (call-with-input-file path (lambda (in) (read-string #f in)))
      #f))

;; =============================================================================
;; Stage 1: PLAN — Use omniCode to generate a product plan
;; =============================================================================
(define (execute-planning pid objective)
  (display (string-append "  Executing PLAN for " pid " ...\n"))
  (let* ((payload (string-append
                    "{\"action\":\"plan\",\"payload\":{"
                    "\"product_id\":\"" pid "\","
                    "\"objective\":\"" objective "\","
                    "\"language\":\"chicken-scheme\","
                    "\"timestamp\":\"" (ts) "\"}}"))
         (cmd (string-append "curl --max-time 15 -s -X POST http://127.0.0.1:8769/api/v1/codegen "
                "-H 'Content-Type: application/json' -d '" payload "' 2>&1"))
         (result (shell cmd))
         (artifact-path (stage-artifact 'plan pid)))
    (write-artifact artifact-path (or result ";;; No plan generated"))
    (display (string-append "  -> PLAN artifact: " artifact-path "\n"))
    #t))

;; =============================================================================
;; Stage 2: DESIGN — Submit chain to claw2ee, generate design spec
;; =============================================================================
(define (execute-design pid)
  (display (string-append "  Executing DESIGN for " pid " ...\n"))
  (let* ((plan-artifact (read-artifact (stage-artifact 'plan pid)))
         (chain-json (string-append
                       "{\"action\":\"submit_chain\",\"payload\":{"
                       "\"chain_id\":\"" pid "-design\","
                       "\"chain\":{\"product_id\":\"" pid "\","
                       "\"stage\":\"DESIGN\","
                       "\"plan\":\"" (or plan-artifact "") "\","
                       "\"timestamp\":\"" (ts) "\"}}}"))
         (cmd (string-append "curl --max-time 15 -s -X POST http://127.0.0.1:8082/api/v1/tools/ghics_am_status "
                "-H 'Content-Type: application/json' -d '" chain-json "' 2>&1"))
         (result (shell cmd))
         (artifact-path (stage-artifact 'design pid)))
    (write-artifact artifact-path
      (string-append ";;; Design for " pid "\n;;; Generated: " (ts) "\n"
                     ";;; Claw2EE Response: " (or result "no response") "\n"))
    (display (string-append "  -> DESIGN artifact: " artifact-path "\n"))
    #t))

;; =============================================================================
;; Stage 3: IMPL — Generate code files via omniCode
;; =============================================================================
(define (execute-implementation pid)
  (display (string-append "  Executing IMPL for " pid " ...\n"))
  (let* ((design-artifact (read-artifact (stage-artifact 'design pid)))
         (payload (string-append
                    "{\"action\":\"generate\",\"payload\":{"
                    "\"task_id\":\"" pid "\","
                    "\"task_name\":\"product-" pid "\","
                    "\"layer\":\"L3\","
                    "\"language\":\"chicken-scheme\","
                    "\"design\":\"" (or design-artifact "") "\","
                    "\"timestamp\":\"" (ts) "\"}}}"))
         (cmd (string-append "curl --max-time 15 -s -X POST http://127.0.0.1:8769/api/v1/codegen "
                "-H 'Content-Type: application/json' -d '" payload "' 2>&1"))
         (result (shell cmd))
         (impl-dir (stage-dir 'impl))
         (main-file (string-append impl-dir "/" pid "-main.scm")))
    ;; Write the generated code to the main file
    (write-artifact main-file (or result ";;; No code generated\n"))
    ;; Also write to the stage artifact path
    (write-artifact (stage-artifact 'impl pid)
      (string-append ";;; Implementation for " pid "\n;;; Generated: " (ts) "\n\n"
                     (or result ";;; No code generated")))
    (display (string-append "  -> Generated: " main-file "\n"))
    ;; Return list of generated files
    (list main-file)))

;; =============================================================================
;; Stage 4: TEST — Syntax-check generated code files
;; =============================================================================
(define (execute-testing pid files)
  (display (string-append "  Executing TEST for " pid " ...\n"))
  (let ((test-results '()))
    (for-each
      (lambda (f)
        (if (string-suffix? ".scm" f)
            (let* ((cmd (string-append "chicken-csi -s " f " 2>&1"))
                   (result (shell cmd)))
              (set! test-results (cons (list (cons 'file f) (cons 'result result)) test-results))
              (display (string-append "  Test: " f " -> " (substring result 0 (min 60 (string-length result))) "\n")))
            (display (string-append "  Skip (non-scm): " f "\n"))))
      files)
    ;; Write test report
    (let ((report-path (string-append (stage-dir 'test) "/" pid "-test-report.scm")))
      (write-artifact report-path (string-append ";;; Test Report for " pid "\n;;; Date: " (ts) "\n")))
    (display (string-append "  -> Tests: " (number->string (length test-results)) " files checked\n"))
    #t))

;; =============================================================================
;; Stage 5: AUDIT — Call claw2ee audit endpoint
;; =============================================================================
(define (execute-audit pid)
  (display (string-append "  Executing AUDIT for " pid " ...\n"))
  (let* ((payload (string-append
                    "{\"action\":\"check_audit\",\"payload\":{"
                    "\"product_id\":\"" pid "\","
                    "\"timestamp\":\"" (ts) "\"}}}"))
         (cmd (string-append "curl --max-time 15 -s -X POST http://127.0.0.1:8082/api/v1/tools/ghics_am_status "
                "-H 'Content-Type: application/json' -d '" payload "' 2>&1"))
         (result (shell cmd))
         (audit-path (stage-artifact 'audit pid)))
    (write-artifact audit-path
      (string-append ";;; Audit Report for " pid "\n;;; Date: " (ts) "\n"
                     ";;; Claw2EE Response:\n" (or result "No audit response") "\n"))
    (display (string-append "  -> AUDIT artifact: " audit-path "\n"))
    #t))

;; =============================================================================
;; Stage 6: DEPLOY — Package and deploy the product
;; =============================================================================
(define (execute-deployment pid files)
  (display (string-append "  Executing DEPLOY for " pid " ...\n"))
  (let* ((metadata (deploy-product pid files))
         (deploy-path (stage-artifact 'deploy pid)))
    (write-artifact deploy-path
      (string-append ";;; Deploy Report for " pid "\n;;; Date: " (ts) "\n"))
    (display (string-append "  -> Deployed to: " PRODUCTS-DIR "/" pid "\n"))
    #t))

;; =============================================================================
;; End of product-lifecycle.scm
;; =============================================================================