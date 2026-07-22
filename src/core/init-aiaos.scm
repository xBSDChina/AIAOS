#!/usr/local/bin/csi -s
;; ================================================================
;; AIAOS Framework - Main Initialization Script
;; ================================================================
;; This is the entry point for the complete AIAOS system.
;; Usage: csi -s init-aiaos.scm [command]
;; Commands: init, start, stop, status, run-chain, create-task, execute-task, dashboard
;; ================================================================

(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.file)
(import chicken.json)
(import chicken.pathname)
(import chicken.process)
(import chicken.getopt)
(import chicken.condition)

;; Ensure we're in the correct directory
(define WORKING-DIR (make-pathname (get-environment-variable "HOME") "aiaos"))
(current-directory WORKING-DIR)

;; Load modules
(require-extension (chicken.file))
(require-extension (chicken.process))
(require-extension (chicken.string))

;; Load core modules (assume they are in the same directory)
(define (load-module! name)
  (let ((path (make-pathname WORKING-DIR (string-append name ".scm"))))
    (if (file-exists? path)
        (begin
          (load path)
          #t)
        (begin
          (display "ERROR: Module not found: ") (display path) (newline)
          #f))))

;; Load all modules
(load-module! "aiaos-core")
(load-module! "omnicode")
(load-module! "llm-bridge-chicken")
(load-module! "web-dashboard")

;; Compatibility aliases
(define aiaos-status aiaos-get-overall-status)
(define aiaos-create-task omnicode-create-task)
(define aiaos-execute-task omnicode-execute-task)
(define aiaos-list-tasks omnicode-list-tasks)
(define (aiaos-run-chain) (aiaos-execute-instruction 'chain))

;; Dashboard start function wrapper
(define (web-start-dashboard cfg)
  (let ((port (or (alist-ref 'port cfg) 8080))
        (home (or (get-environment-variable "HOME") "/home/aiaos"))
        (web-dir (string-append (or (get-environment-variable "HOME") "/home/aiaos") "/aiaos/web"))
        (handler (string-append (or (get-environment-variable "HOME") "/home/aiaos") "/aiaos/web/aiaos-web-handler.scm")))
    ;; Ensure web directory exists
    (system (string-append "mkdir -p " web-dir))
    ;; Start netcat listener in background
    (display (string-append "Starting dashboard on port " (number->string port) " with handler " handler "\n"))
    (let ((cmd (string-append "nohup nc -l " (number->string port) " -e " handler " > " home "/aiaos/logs/web-dashboard.log 2>&1 &")))
      (system cmd)
      (display "Dashboard started.\n")))

;; ================================================================
;; Command Handling
;; ================================================================

(define (print-usage)
  (display "AIAOS Framework - Enterprise System\n")
  (display "Usage: csi -s init-aiaos.scm [command] [options]\n\n")
  (display "Commands:\n")
  (display "  init                - Initialize framework directories and config\n")
  (display "  status              - Show system status\n")
  (display "  start               - Start all services (omnicode, dashboard)\n")
  (display "  stop                - Stop all services\n")
  (display "  run-chain           - Execute full L0-L9 function chain\n")
  (display "  create-task TYPE DESC [METADATA_JSON]\n")
  (display "                      - Create a new task\n")
  (display "  execute-task ID     - Execute a task by ID\n")
  (display "  list-tasks [STATUS] - List tasks (optional filter by status)\n")
  (display "  dashboard [--port N] - Start web dashboard\n")
  (display "  llm-chat PROMPT     - Send chat to LLM\n")
  (display "  shell               - Drop into interactive Scheme shell\n")
  (newline)
  (display "Examples:\n")
  (display "  csi -s init-aiaos.scm init\n")
  (display "  csi -s init-aiaos.scm create-task development \"Build API\" '{\"priority\": 1}'\n")
  (display "  csi -s init-aiaos.scm execute-task task-123\n")
  (display "  csi -s init-aiaos.scm dashboard --port 8080\n"))

(define (cmd-init)
  (display "Initializing AIAOS...\n")
  (aiaos-init)
  (omnicode-init)
  (display "Initialization complete.\n")
  (display "Run: csi -s init-aiaos.scm dashboard --port 8080\n")
  (newline)
  (let ((status (aiaos-get-overall-status)))
    (display "System Status:\n")
    (display "  Status: ") (display (alist-ref 'status status)) (newline)
    (display "  Functions: ") (display (alist-ref 'functions status)) (newline)
    (display "  Tasks: ") (display (alist-ref 'tasks status)) (newline)
    (display "  Components: ") (display (alist-ref 'components status)) (newline)))

(define (cmd-status)
  (let ((status (aiaos-get-overall-status)))
    (display "=== AIAOS Status ===\n")
    (display "Status: ") (display (alist-ref 'status status)) (newline)
    (display "Uptime: ") (display (alist-ref 'uptime status)) (newline)
    (display "Functions: ") (display (alist-ref 'functions status)) (newline)
    (display "Tasks: ") (display (alist-ref 'tasks status)) (newline)
    (display "Components: ") (display (alist-ref 'components status)) (newline)
    (display "LLM Providers: ") (display (alist-ref 'llm-providers status)) (newline)
    (display "Version: ") (display (alist-ref 'version status)) (newline)))

(define (cmd-run-chain)
  (display "Executing L0-L9 function chain...\n")
  (let ((result (aiaos-run-chain)))
    (display "Chain execution completed.\n")
    (display "Results:\n")
    (for-each (lambda (r)
                (display "  ") (display (car r)) (display ": ")
                (display (cdr r)) (newline))
              result)))

(define (cmd-create-task type desc . metadata-arg)
  (let ((metadata (if (null? metadata-arg) '() (car metadata-arg))))
    (let ((task (aiaos-create-task type desc metadata)))
      (display "Task created: ") (display (alist-ref 'id task)) (newline)
      task)))

(define (cmd-execute-task task-id)
  (display "Executing task: ") (display task-id) (newline)
  (let ((result (aiaos-execute-task task-id)))
    (display "Result: ") (display (scm->json result)) (newline)))

(define (cmd-list-tasks . args)
  (let ((status-filter (if (null? args) #f (car args)))
        (tasks (if status-filter
                   (aiaos-list-tasks `((status . ,status-filter)))
                   (aiaos-list-tasks))))
    (display "Tasks (" (number->string (length tasks)) "):\n")
    (for-each (lambda (t)
                (display "  ID: ") (display (alist-ref 'id t)) (newline)
                (display "    Type: ") (display (alist-ref 'type t)) (newline)
                (display "    Status: ") (display (alist-ref 'status t)) (newline)
                (display "    Desc: ") (display (alist-ref 'description t)) (newline)
                (display "    Created: ") (display (alist-ref 'created-at t)) (newline)
                (newline))
              tasks)))

(define (cmd-llm-chat prompt)
  (display "LLM Chat: " prompt "\n")
  (let ((result (llm-chat prompt `((temperature . 0.7) (max-tokens . 1000)))))
    (display "Response:\n")
    (if (alist-ref 'error result #f)
        (begin
          (display "  ERROR: ") (display (alist-ref 'message result)) (newline))
        (let ((content (alist-ref 'content (alist-ref 'choices result '()) "")))
          (display content) (newline)))))

(define (cmd-dashboard . args)
  (let ((port (if (null? args) 8080
                  (let ((arg (car args)))
                    (if (and (string=? arg "--port") (>= (length args) 2))
                        (string->number (cadr args))
                        8080)))))
    (display "Starting dashboard on port " (number->string port) "\n")
    (web-start-dashboard `((port . ,port)))
    ;; Keep running
    (display "Dashboard running. Press Ctrl+C to stop.\n")
    (while #t (sleep 10))))

;; ================================================================
;; Main Entry
;; ================================================================

(define (main)
  (let ((args (command-line-arguments)))
    (if (or (null? args) (member (car args) '("-h" "--help" "help")))
        (print-usage)
        (case (string->symbol (car args))
          ((init) (cmd-init))
          ((status) (cmd-status))
          ((run-chain) (cmd-run-chain))
          ((create-task)
           (if (>= (length args) 3)
               (cmd-create-task (cadr args) (caddr args) (if (>= (length args) 4) (json->scm (cadddr args)) '()))
               (print-usage)))
          ((execute-task)
           (if (>= (length args) 2)
               (cmd-execute-task (cadr args))
               (print-usage)))
          ((list-tasks) (apply cmd-list-tasks (cdr args)))
          ((llm-chat)
           (if (>= (length args) 2)
               (cmd-llm-chat (cadr args))
               (print-usage)))
          ((dashboard) (apply cmd-dashboard (cdr args)))
          ((shell)
           (display "Dropping into interactive Scheme shell...\n")
           (read-eval-print-loop))
          (else (print-usage))))))

(main)
