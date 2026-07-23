#!/usr/bin/env csi -s

;; Task Objective Setting Component - Runner
;; Imports objectives, expands to subtasks, writes chain file, and submits to Claw2EE.

(require-extension chicken.io)
(require-extension chicken.file)
(require-extension chicken.time)
(require-extension chicken.string)
(require-extension json)
(require-extension srfi-1)

;; Simple assoc-ref for alists
(define (assoc-ref alist key)
  (let ((p (assoc key alist)))
    (if p (cdr p) #f)))

;; Logging
(define (log-info . args)
  (let ((ts (seconds->string (current-seconds) "%Y-%m-%d %H:%M:%S")))
    (display "[INFO] ") (display ts) (display " ")
    (for-each (lambda (a) (display a) (display " ")) args)
    (newline) (flush-output)))

(define (log-err . args)
  (let ((ts (seconds->string (current-seconds) "%Y-%m-%d %H:%M:%S")))
    (display "[ERR] ") (display ts) (display " ")
    (for-each (lambda (a) (display a) (display " ")) args)
    (newline) (flush-output)))

;; Load claw2ee bridge (fixed port)
(load "/home/aiaos/aiaos/objectives/claw2ee-bridge.scm")
(define bridge-submit submit-chain) ; capture

;; Load objectives from store
(define (load-objectives)
  (let ((path "/home/aiaos/aiaos/objectives/objective-store.json")))
    (if (file-exists? path)
        (call-with-input-file path
          (lambda (in)
            (let* ((raw (json-read in))
                   (objs (assoc-ref raw 'objectives)))
              (if objs
                  (begin (log-info "Loaded" (length objs) "objectives") objs)
                  (begin (log-err "Missing 'objectives' in store" path) '()))))
        (begin (log-err "Objective store not found:" path) '()))))

;; Expand objective into 4 subtasks (PLAN, IMPL, TEST, AUDIT)
(define (expand-objective obj)
  (let* ((id (assoc-ref obj 'id))
         (title (assoc-ref obj 'title))
         (desc (assoc-ref obj 'description))
         (level (or (assoc-ref obj 'level) 1))
         (pri-str (or (assoc-ref obj 'priority) "medium"))
         (pri (string->symbol pri-str))
         (omni (or (assoc-ref obj 'omniScore) 500))
         (subsys (or (assoc-ref obj 'subsystem) "aiaos"))
         (port (assoc-ref obj 'port))
         (endpoints (or (assoc-ref obj 'endpoints) '()))
         (plan-id (string-append id "-PLAN"))
         (impl-id (string-append id "-IMPL"))
         (test-id (string-append id "-TEST"))
         (audit-id (string-append id "-AUDIT")))
    (list
      (list (cons 'id plan-id) (cons 'level level) (cons 'title (string-append "PLAN: " title))
            (cons 'description (string-append "Strategic planning for: " desc))
            (cons 'priority 'critical) (cons 'omniScore 900) (cons 'subsystem subsys)
            (cons 'status 'pending) (cons 'dependencies '()) (cons 'parent id))
      (list (cons 'id impl-id) (cons 'level level) (cons 'title (string-append "IMPL: " title))
            (cons 'description (string-append "Implement " title "."))
            (cons 'priority (case pri ((critical) 'high) ((high) 'medium) (else 'low)))
            (cons 'omniScore omni) (cons 'subsystem subsys) (cons 'status 'pending)
            (cons 'dependencies (list plan-id)) (cons 'parent id))
      (list (cons 'id test-id) (cons 'level level) (cons 'title (string-append "TEST: " title))
            (cons 'description (string-append "Test " title))
            (cons 'priority 'high) (cons 'omniScore (if (> omni 500) omni (+ omni 100)))
            (cons 'subsystem subsys) (cons 'status 'pending)
            (cons 'dependencies (list impl-id)) (cons 'parent id))
      (list (cons 'id audit-id) (cons 'level level) (cons 'title (string-append "AUDIT: " title))
            (cons 'description (string-append "Enterprise audit for " title))
            (cons 'priority 'critical) (cons 'omniScore 1000) (cons 'subsystem subsys)
            (cons 'status 'pending) (cons 'dependencies (list test-id)) (cons 'parent id)))))

(define (expand-all objectives)
  (apply append (map expand-objective objectives)))

;; Write task chain to file for monitoring
(define (write-task-chain tasks)
  (call-with-output-file "/home/aiaos/aiaos/status/task_chain.json"
    (lambda (out) (write-json (list (cons 'tasks tasks)) out))))

;; Main
(let* ((objectives (load-objectives))
       (tasks (if (null? objectives) '() (expand-all objectives))))
  (if (null? tasks)
      (log-err "No tasks generated; aborting")
      (begin
        (log-info "Generated" (length tasks) "tasks from" (length objectives) "objectives")
        (write-task-chain tasks)
        (log-info "Wrote task_chain.json")
        (let ((res (bridge-submit tasks)))
          (if res
              (log-info "Successfully submitted tasks to Claw2EE")
              (log-err "Claw2EE submission failed"))))))
