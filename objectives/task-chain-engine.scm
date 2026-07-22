;;; task-chain-engine.scm
;;; AIAOS Task Chain Execution Engine — 任务链路执行引擎
;;; Compiled with: chicken-csc task-chain-engine.scm -o task-chain-engine
;;; Routes objectives through claw2ee and omniCode, executes task chains.

(import chicken.base)
(import chicken.time)
(import chicken.condition)
(import chicken.condition)
(import chicken.time)
(import chicken.process)
(import chicken.file)
(import chicken.process-context)
(import chicken.string)
(import chicken.io)
(require-extension json)
(require-extension srfi-18)
(require-extension srfi-1)
(require-extension srfi-18)

;; =============================================================================
;; Configuration
;; =============================================================================

(define AIAOS-HOME "/home/aiaos/aiaos")
(define OBJECTIVES-DIR (string-append AIAOS-HOME "/objectives"))
(define STATUS-DIR (string-append AIAOS-HOME "/status"))
(define TASKS-DIR (string-append AIAOS-HOME "/tasks"))
(define LOG-DIR (string-append AIAOS-HOME "/logs"))
(define TASK-CHAIN-FILE (string-append STATUS-DIR "/task_chain.json"))
(define TASK-CHAIN-STATUS (string-append STATUS-DIR "/task_chain_status.json"))
(define ENGINE-LOG (string-append LOG-DIR "/task-chain-engine.log"))

;; =============================================================================
;; Utilities
;; =============================================================================

(define (timestamp)
  (let* ((now (current-seconds))
         (secs (modulo now 60))
         (mins (modulo (quotient now 60) 60))
         (hours (modulo (quotient now 3600) 24))
         (days (quotient now 86400)))
    (string-append
      (number->string (+ 1970 (quotient days 365))) "-"
      (number->string (+ 1 (quotient (modulo days 365) 30))) "-"
      (number->string (+ 1 (modulo days 30))) "T"
      (number->string hours) ":"
      (number->string mins) ":"
      (number->string secs) "Z")))

(define (log! msg)
  (let ((entry (string-append "[" (timestamp) "] [ENGINE] " msg)))
    (display entry) (newline)
    (condition-case
      (with-output-to-file ENGINE-LOG
        (lambda () (display entry) (newline))
        append:)
      (ex () (void)))))

(define (read-file path)
  (condition-case
    (with-input-from-file path (lambda () (read-string #f)))
    (ex () #f)))

(define (write-file path content)
  (condition-case
    (with-output-to-file path (lambda () (display content)))
    (ex () (log! (string-append "Cannot write: " path)))))

(define (ensure-dir dir)
  (condition-case (system (string-append "mkdir -p " dir)) (ex () #f)))

(define (shell cmd)
  (with-input-from-pipe cmd
    (lambda ()
      (let loop ((lines '()) (line (read-line)))
        (if (eof-object? line)
          (string-intersperse (reverse lines) "\n")
          (loop (cons line lines) (read-line)))))))

(define (json-escape s)
  (let loop ((i 0) (result '()))
    (if (>= i (string-length s))
      (list->string (reverse result))
      (let ((c (string-ref s i)))
        (case c
          ((#\") (loop (+ i 1) (append '(#\\ #\") result)))
          ((#\\) (loop (+ i 1) (append '(#\\ #\\) result)))
          ((#\newline) (loop (+ i 1) (append '(#\\ #\n) result)))
          ((#\return) (loop (+ i 1) (append '(#\\ #\r) result)))
          ((#\tab) (loop (+ i 1) (append '(#\\ #\t) result)))
          (else (loop (+ i 1) (cons c result))))))))

;; =============================================================================
;; Task Chain Loading
;; =============================================================================

(define (load-task-chains)
  (let ((content (read-file TASK-CHAIN-FILE)))
    (if content
      (condition-case
        (let ((tmpf (open-output-file "/tmp/task-chain-parse.json"))) (display content tmpf) (close-output-port tmpf) (with-input-from-file "/tmp/task-chain-parse.json" json-read))
        (ex () (log! "Cannot parse task_chain.json") #f))
      (begin (log! "task_chain.json not found") #f))))

(define (load-status-file path)
  (let ((content (read-file path)))
    (if content
      (condition-case (let ((tmpf (open-output-file "/tmp/task-chain-parse.json"))) (display content tmpf) (close-output-port tmpf) (with-input-from-file "/tmp/task-chain-parse.json" json-read))
        (ex () #f))
      #f)))

;; =============================================================================
;; Execution Pipeline
;; =============================================================================

(define (execute-chain chain)
  "Execute a single task chain through claw2ee/omniCode."
  (let* ((id (let ((v (assoc 'id chain))) (if v (cdr v) "unknown")))
         (name (let ((v (assoc 'name chain))) (if v (cdr v) "Unnamed")))
         (desc (let ((v (assoc 'description chain))) (if v (cdr v) "")))
         (priority (let ((v (assoc 'priority chain))) (if v (cdr v) "medium")))
         (nodes (let ((v (assoc 'nodes chain))) (if v (cdr v) '()))))
    
    (log! (string-append "Executing chain: " id " (" name ")"))
    
    ;; Step 1: Submit to claw2ee for planning
    (log! "Step 1: Submitting to claw2ee...")
    (condition-case
      (let* ((payload (string-append
                        "{\"chain_id\":\"" id "\","
                        "\"name\":\"" (json-escape name) "\","
                        "\"description\":\"" (json-escape desc) "\","
                        "\"nodes\":" (list->json (map json-escape nodes)) "}"))
             (result (shell (string-append
                             "curl -s -X POST http://localhost:3004/api/v1/tools/ghics_am_status"
                             " -H 'Content-Type: application/json'"
                             " -d '{\"action\":\"plan_chain\",\"payload\":"
                             payload ",\"source\":\"task-chain-engine\"}'")))
             (result-str (or result "")))
        (log! (string-append "claw2ee plan result: " 
                (substring (json-escape result-str) 0 (min 100 (string-length result-str))))))
      (ex () (log! "claw2ee planning: FAILED")))
    
    ;; Step 2: For each node, submit to omniCode for code generation
    (log! (string-append "Step 2: Processing " (number->string (length nodes)) " nodes"))
    (let loop ((remaining nodes) (idx 1))
      (if (not (null? remaining))
        (let ((node (car remaining)))
          (log! (string-append "  Node " (number->string idx) ": " node))
          (condition-case
            (let* ((payload (string-append
                              "{\"chain_id\":\"" id "\","
                              "\"node_index\":" (number->string idx) ","
                              "\"node_name\":\"" (json-escape node) "\""
                              ",\"scope\":\"objective-chain\"}"))
                   (result (shell (string-append
                                   "curl -s -X POST http://localhost:8765/api/v1/codegen"
                                   " -H 'Content-Type: application/json'"
                                   " -d '{\"action\":\"generate\",\"payload\":"
                                   payload ",\"source\":\"task-chain-engine\"}'")))
                   (result-str (or result "")))
              (log! (string-append "  omniCode node " (number->string idx) ": "
                      (substring (json-escape result-str) 0 (min 80 (string-length result-str))))))
            (ex () (log! (string-append "  omniCode node " (number->string idx) ": FAILED"))))
          (loop (cdr remaining) (+ idx 1)))))
    
    ;; Step 3: Write chain execution record
    (let ((exec-record (string-append
                         "{\"chain_id\":\"" id "\","
                         "\"name\":\"" (json-escape name) "\","
                         "\"status\":\"executed\","
                         "\"nodes_total\":" (number->string (length nodes)) ","
                         "\"executed_at\":\"" (timestamp) "\","
                         "\"source\":\"objective-driven\"}")))
      (write-file (string-append TASKS-DIR "/chain-" id "-" (number->string (current-seconds)) ".json") 
                   exec-record))
    
    (log! (string-append "Chain " id " execution complete"))
    #t))

(define (process-all-chains)
  "Process all pending task chains from objective engine."
  (let* ((chains-data (load-task-chains)))
    (if (not chains-data)
      (begin
        (log! "No task chains available")
        0)
      (let* ((chains (or (let ((v (assoc 'chains chains-data))) (if v (cdr v) #f)) '()))
             (count (length chains))
             (successful 0))
        (if (zero? count)
          (begin (log! "No chains to process") 0)
          (begin
            (log! (string-append "Processing " (number->string count) " task chains"))
            (for-each (lambda (chain-str)
                        (condition-case
                          (let ((chain (with-input-from-string chain-str json-read)))
                            (if (hashtable? chain)
                              (begin
                                (execute-chain chain)
                                (set! successful (+ successful 1)))
                              (log! "Invalid chain entry")))
                          (ex () (log! "Chain processing error"))))
                      chains)
            successful))))))

;; =============================================================================
;; Status Updates
;; =============================================================================

(define (write-engine-status execution-count)
  (let ((status (string-append
                  "{\"status\":\"running\","
                  "\"timestamp\":\"" (timestamp) "\","
                  "\"component\":\"task-chain-engine\","
                  "\"execution_count\":" (number->string execution-count) ","
                  "\"version\":\"2.0.0\"}")))
    (write-file TASK-CHAIN-STATUS status)))

;; =============================================================================
;; Main Entry Points
;; =============================================================================

(define (cron-run)
  "Full cron execution: load objectives → generate chains → execute chains"
  (log! "================================================")
  (log! "Task Chain Engine CRON Run")
  (log! "================================================")
  
  ;; 1. Ensure directories exist
  (ensure-dir STATUS-DIR)
  (ensure-dir TASKS-DIR)
  (ensure-dir OBJECTIVES-DIR)
  
  ;; 2. Verify objective engine has run (chain file exists)
  (if (not (file-exists? TASK-CHAIN-FILE))
    (begin
      (log! "task_chain.json not found — objective engine may not have run yet")
      (log! "Attempting to call objective engine...")
      (condition-case
        (let ((result (shell (string-append
                              "/home/aiaos/aiaos/objectives/objective-engine cron 2>&1"))))
          (log! (or result "objective-engine call: completed")))
        (ex () (log! "objective-engine call: FAILED")))
      (exit 0)))
  
  ;; 3. Process all task chains
  (let ((count (process-all-chains)))
    (write-engine-status count)
    (log! (string-append "Processed " (number->string count) " chains"))
    (log! "Task Chain Engine CRON Complete"))
  (log! "================================================"))

(define (show-help)
  (display "AIAOS Task Chain Engine v2.0.0
Usage: task-chain-engine <command>

Commands:
  cron         Full cron run (main entry point)
  execute      Execute all pending chains
  chain <id>   Execute specific chain by ID
  status       Show engine status
  help         Show this help
"))

(let ((args (command-line-arguments)))
  (if (null? args)
    (cron-run)
    (case (string->symbol (car args))
      ((cron) (cron-run))
      ((execute) (let ((c (process-all-chains)))
                   (display (string-append "Executed " (number->string c) " chains")) (newline)
                   (write-engine-status c)))
      ((status) (display (read-file TASK-CHAIN-STATUS)) (newline))
      ((help) (show-help))
      (else (show-help)))))
