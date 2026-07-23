;;; product-closed-loop.scm — Enterprise Closed-Loop Orchestrator
;;; Provides CLI: run <pid> <objective> and status
;;; Integrates: product-lifecycle, deploy-pipeline, brains, claw2ee-bridge, omnicode-bridge

(require-extension chicken.io chicken.string chicken.time chicken.file json)
(import chicken.port chicken.condition)

;; Paths
(define DEPLOY-BASE "/home/aiaos/deploy")
(define LOG-DIR (string-append DEPLOY-BASE "/logs"))
(define CLOSED-LOOP-LOG (string-append LOG-DIR "/closed-loop.log"))

;; Logging (append to file)
(define (closed-loop-log msg)
  (let ((e (string-append "[" (ts) "] [CLOSED-LOOP] " msg)))
    (display e) (newline)
    (call-with-output-file CLOSED-LOOP-LOG
      (lambda (out) (display e out) (newline out))
      #:append #t)))

;; Load all component modules (order matters: lifecycle -> deploy -> brains -> bridges)
(load "/home/aiaos/aiaos/objectives/product-lifecycle.scm")
(load "/home/aiaos/aiaos/objectives/deploy-pipeline.scm")
(load "/home/aiaos/aiaos/objectives/brains.scm")
(load "/home/aiaos/aiaos/objectives/claw2ee-bridge.scm")
(load "/home/aiaos/aiaos/objectives/omnicode-bridge.scm")

;; Safe execution with automatic Brains error analysis
(define (safe-exec thunk stage pid)
  (condition-case
      (let ((result (thunk)))
        (if result
            (begin (log! (string-append "Stage " (symbol->string stage) " succeeded")) #t)
            (begin (log! (string-append "Stage " (symbol->string stage) " returned false")) #f)))
    (ex (err)
      (let ((msg (with-output-to-string (lambda () (display err)))))
        (log! (string-append "Stage " (symbol->string stage) " failed: " msg))
        (brains-analyze (string-append pid "-" (symbol->string stage))
                        (string-append "Stage " (symbol->string stage) " error: " msg))
        #f))))

;; Alias logger
(define (log! msg) (closed-loop-log msg))

;; Core closed-loop
(define (run-closed-loop pid objective)
  (log! (string-append "=== Start Closed-Loop: " pid " ==="))
  (ensure-stage-dirs!)
  (log! "1/6 PLAN") (safe-exec (lambda () (execute-planning pid objective)) 'plan pid)
  (log! "2/6 DESIGN") (safe-exec (lambda () (execute-design pid)) 'design pid)
  (log! "3/6 IMPL")
  (let ((files (safe-exec (lambda () (execute-implementation pid)) 'impl pid)))
    (if files
        (begin
          (log! "4/6 TEST") (safe-exec (lambda () (execute-testing pid files)) 'test pid)
          (log! "5/6 AUDIT") (safe-exec (lambda () (execute-audit pid)) 'audit pid)
          (log! "6/6 DEPLOY") (safe-exec (lambda () (execute-deployment pid files)) 'deploy pid))
        (begin
          (log! "IMPL failed, aborting remaining stages")
          (brains-analyze (string-append pid "-IMPL") "IMPL stage failed, aborting"))))
  ;; Write manifest
  (let ((summary (list (cons 'product-id pid)
                       (cons 'status 'complete)
                       (cons 'timestamp (ts))
                       (cons 'deploy-path (string-append PRODUCTS-DIR "/" pid)))))
    (call-with-output-file (product-manifest pid) (lambda (out) (write summary out))))
  (log! (string-append "Closed-Loop Complete: " pid))
  (log! (string-append "FINISHED " pid))
  #t)

;; CLI wrappers
(define (run pid objective)
  (run-closed-loop pid objective))

(define (status)
  (display "=== Closed-Loop Status ===\n")
  (let ((products (list-products)))
    (for-each (lambda (p) (display (string-append "  Product: " p "\n"))) products)
    (display (string-append "Total products: " (number->string (length products)) "\n"))))

;; Main dispatcher
(define (main)
  (let ((args (command-line-arguments)))
    (cond
     ((and (>= (length args) 3) (string=? (car args) "run"))
      (run (cadr args) (caddr args)))
     ((and (>= (length args) 1) (string=? (car args) "status"))
      (status))
     (else
      (display "Usage: chicken-csi -s product-closed-loop.scm run <pid> <objective>\n")
      (display "       chicken-csi -s product-closed-loop.scm status\n")))))

;; Auto-run when executed directly
(let ((args (command-line-arguments)))
  (when (and (pair? args) (member (car args) '("run" "status")))
    (main)))

;;; End of product-closed-loop.scm