#!/usr/bin/env csi -s
;; aiaos-llm.scm - Main Entry Point for AIAOS LLM Interface
;; This is the main script that orchestrates the LLM-driven AIAOS system on VM_D

(import chicken.process)
(require-extension srfi-1)
(require-extension srfi-18)
(require-extension srfi-69)

;; Load all modules in order
(import "llm-config.scm")
(import "conversation.scm")
(import "scheme-executor.scm")
(import "task-manager.scm")
(import "interactive-loop.scm")
(import "llm-bridge.scm")

;; Re-export for convenience
(module-export-all)

;; ============================================================================
;; Command Line Arguments
;; ============================================================================

(define (show-help)
  (display "AIAOS LLM Interface - Enterprise AI Agent on Chicken Scheme\n")
  (newline)
  (display "Usage: csi -s aiaos-llm.scm [OPTIONS]\n")
  (newline)
  (display "Modes:\n")
  (display "  (default)          Interactive REPL (prompt for tasks)\n")
  (display "  --daemon           Run as daemon, poll task queue periodically\n")
  (display "  --queue=PATH       Read tasks from file PATH, process them\n")
  (display "  --port=N           Run HTTP server on port N (experimental)\n")
  (newline)
  (display "Options:\n")
  (display "  --poll=N           Poll interval in seconds (default: 30)\n")
  (display "  --log=FILE         Log file path (default: ~/aiaos/chicken/llm/aiaos.log)\n")
  (display "  --debug            Enable verbose debugging output\n")
  (display "  --help             Show this message\n")
  (newline)
  (display "Environment Variables:\n")
  (display "  OPENROUTER_API_KEY    API key for OpenRouter (required unless using local LLM)\n")
  (display "  AIAOS_LLM_MOCK       Set 'true' to use mock LLM responses (testing)\n")
  (display "  LLM_PROVIDER         'openrouter' (default) or 'local'\n")
  (display "  LLM_MODEL            Model name (default: step-3.5-flash)\n")
  (newline))

;; Parse command line arguments into alist
(define (parse-args args)
  (let loop ((args args) (opts '()))
    (if (null? args)
      opts
      (let ((arg (car args))
            (rest (cdr args)))
        (cond
          ((string=? arg "--help") (show-help) (exit 0))
          ((string=? arg "--daemon") (loop rest (acons 'mode 'daemon opts)))
          ((string-prefix? "--poll=" arg)
           (loop rest (acons 'poll-interval (string->number (substring arg 7 (string-length arg))) opts)))
          ((string-prefix? "--queue=" arg)
           (loop rest (acons 'mode 'queue (acons 'queue-path (substring arg 8 (string-length arg)) opts))))
          ((string=? arg "--queue") ; shorthand
           (if (null? rest) (error "Missing queue path") (loop (cdr rest) (acons 'mode 'queue (acons 'queue-path (car rest) opts)))))
          ((string-prefix? "--port=" arg)
           (loop rest (acons 'mode 'http (acons 'port (string->number (substring arg 7 (string-length arg))) opts))))
          ((string=? arg "--debug")
           (loop rest (acons 'debug #t opts)))
          ((string=? arg "--log=")
           (loop (cdr rest) (acons 'log-file (car rest) opts)))
          (else (loop rest (acons 'arg arg opts))))))))

;; ============================================================================
;; Logging Setup
;; ============================================================================

(define *log-port* #f)

(define (init-logging log-file debug?)
  (let ((path (or log-file
                  (string-append
                    (or (get-environment-variable "HOME") "/tmp")
                    "/aiaos/chicken/llm/aiaos.log"))))
    (unless (directory-exists? (pathname-directory path))
      (create-directory (pathname-directory path) #t))
    (set! *log-port* (open-output-file path))
    ;; Redirect log! output to file as well as stdout
    (log! (string-append "=== AIAOS LLM Interface Starting === (log: " path ")")
          debug?)
    #t))

(define (log! msg . debug?)
  "Log message to file and stdout (if debug)."
  (let ((timestamp (seconds->string (current-seconds))))
    (if *log-port*
        (begin
          (display "[" timestamp "] " *log-port*)
          (display msg *log-port*)
          (newline *log-port*)
          (flush-output *log-port*)))
    (when (and (not (null? debug?)) (car debug?))
      (display "[" timestamp "] ")
      (display msg)
      (newline))))

;; ============================================================================
;; Bootstrap: Create missing directories
;; ============================================================================

(define (bootstrap!)
  "Create necessary directory structure"
  (let ((home (or (get-environment-variable "HOME") "/home/aiaos"))
        (dirs (list "aiaos/chicken/llm"
                    "aiaos/chicken/llm/state"
                    "aiaos/chicken/llm/tasks"
                    "aiaos/chicken/llm/conversations")))
    (for-each
      (lambda (d)
        (let ((path (string-append home "/" d)))
          (unless (directory-exists? path)
            (create-directory path #t))))
      dirs)
    (log! "Bootstrap complete")))

;; ============================================================================
;; Main Entry
;; ============================================================================

(define (main)
  (let* ((args (command-line-arguments))
         (opts (parse-args args))
         (debug? (cdr (assoc 'debug opts)))
         (log-file (cdr (assoc 'log-file opts))))

    ;; Initialize
    (bootstrap!)
    (init-logging log-file debug?)
    (log! (string-append "Command line: " (string-intersperse args " ")))

    ;; Extract options with defaults
    (let ((mode (or (cdr (assoc 'mode opts)) 'repl))
          (poll-interval (or (cdr (assoc 'poll-interval opts)) 30))
          (queue-path (cdr (assoc 'queue-path opts)))
          (http-port (cdr (assoc 'port opts)))
          (log-path (cdr (assoc 'log-file opts))))

      ;; Start system with chosen mode
      (system-init! (list (cons 'mode mode)
                          (cons 'poll-interval poll-interval)
                          (cons 'queue-path queue-path)
                          (cons 'port http-port))))))

;; Run if executed as script
(cond-expand
  (module)
  (else (main)))

;; ============================================================================
;; Exports
;; ============================================================================

(module-export
  main
  show-help
  init-logging
  bootstrap!)

(module-export-all)
