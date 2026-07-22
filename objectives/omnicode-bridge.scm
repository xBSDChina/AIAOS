;;; omnicode-bridge.scm
;;; AIAOS ↔ OmniCode Integration Bridge
;;; Compiled with: chicken-csc omnicode-bridge.scm -o omnicode-bridge
;;; Provides: generate_code, plan_task, sync_status

(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.process)
(import chicken.process-context)
(import chicken.condition)
(import chicken.time)
(require-extension srfi-13)
(require-extension json)
(require-extension srfi-13)
(require-extension srfi-18)

(define OMNICODE-URL "http://localhost:8769")
(define ENDPOINT (string-append OMNICODE-URL "/api/v1/codegen"))
(define BRIDGE-LOG "/home/aiaos/aiaos/logs/omnicode-bridge.log")
(define STATUS-FILE "/home/aiaos/aiaos/status/omniCode.json")

(define (ts)
  (let* ((now (current-seconds))
         (s (modulo now 60)) (m (modulo (quotient now 60) 60))
         (h (modulo (quotient now 3600) 24)) (d (quotient now 86400)))
    (string-append (number->string (+ 1970 (quotient d 365))) "-"
      (number->string (+ 1 (quotient (modulo d 365) 30))) "-"
      (number->string (+ 1 (modulo d 30))) "T"
      (number->string h) ":" (number->string m) ":" (number->string s) "Z")))

(define (log! msg)
  (let ((e (string-append "[" (ts) "] [OMNICODE-BRIDGE] " msg)))
    (display e) (newline)
    (condition-case (with-output-to-file BRIDGE-LOG (lambda () (display e) (newline)) append:) (ex () (void)))))

(define (shell cmd)
  (with-input-from-pipe cmd
    (lambda ()
      (let loop ((l '()) (ln (read-line)))
        (if (eof-object? ln) (string-intersperse (reverse l) "\n") (loop (cons ln l) (read-line)))))))

(define (health-check)
  (let* ((cmd (string-append "curl -s -o /dev/null -w \"%{http_code}\" " OMNICODE-URL " 2>/dev/null"))
         (result (shell cmd)))
    (log! (string-append "Health check: HTTP " (string-trim result)))))

(define (generate task-id task-name task-layer)
  (let* ((payload (string-append
                    "{\"action\":\"generate\",\"payload\":{"
                    "\"task_id\":\"" task-id "\",\"task_name\":\"" task-name "\","
                    "\"layer\":\"" task-layer "\","
                    "\"language\":\"chicken-scheme\",\"timestamp\":\"" (ts) "\"}}"))
         (cmd (string-append "curl -s -X POST " ENDPOINT " -H 'Content-Type: application/json' -d '"
                payload "' 2>/dev/null"))
         (result (shell cmd)))
    (log! (string-append "Generate: " task-id " → " (substring (or result "") 0 (min 200 (string-length (or result ""))))))
    result))

(define (plan payload)
  (let* ((full-payload (string-append
                         "{\"action\":\"plan\",\"payload\":" payload ",\"timestamp\":\"" (ts) "\"}"))
         (cmd (string-append "curl -s -X POST " ENDPOINT " -H 'Content-Type: application/json' -d '"
                full-payload "' 2>/dev/null"))
         (result (shell cmd)))
    (log! (string-append "Plan: " (substring (or result "") 0 (min 200 (string-length (or result ""))))))
    result))

(define (sync-status)
  (let* ((chains (condition-case (read-file "/home/aiaos/aiaos/status/task_chain.json") (ex () "{}")))
         (objectives (condition-case (read-file "/home/aiaos/aiaos/status/task_objectives.json") (ex () "{}")))
         (payload (string-append
                    "{\"action\":\"sync\",\"payload\":{\"source\":\"objective-engine\","
                    "\"task_chains\":" chains ",\"objectives\":" objectives "}}"))
         (cmd (string-append "curl -s -X POST " ENDPOINT " -H 'Content-Type: application/json' -d '"
                payload "' 2>/dev/null"))
         (result (shell cmd)))
    (log! (string-append "Sync: " (substring (or result "") 0 (min 200 (string-length (or result ""))))))))

(define (write-status)
  (let ((status (string-append
                  "{\"status\":\"active\",\"last_sync\":\"" (ts) "\","
                  "\"endpoint\":\"" ENDPOINT "\",\"version\":\"2.0.0\"}")))
    (condition-case (with-output-to-file STATUS-FILE (lambda () (display status))) (ex () (void)))
    (display status) (newline)))

(define (show-help)
  (display "OmniCode Bridge v2.0.0
Usage: omnicode-bridge <command>

Commands:
  health       Check omniCode health
  sync         Sync chains and objectives
  generate <id> <name> <layer>  Generate code for task
  plan <json>  Submit planning payload
  status       Write status file
  cron         Full bridge cycle
  help         Show this
"))

(let ((args (command-line-arguments)))
  (if (null? args) (begin (health-check) (sync-status) (write-status))
    (case (string->symbol (car args))
      ((health) (health-check))
      ((sync) (sync-status) (write-status))
      ((generate) (if (>= (length args) 4)
                    (let ((result (generate (cadr args) (caddr args) (cadddr args))))
                      (display (or result "No result")))
                    (display "Usage: omnicode-bridge generate <id> <name> <layer>\n")))
      ((plan) (if (>= (length args) 2)
                (let ((result (plan (cadr args)))) (display (or result "No result")))
                (display "Usage: omnicode-bridge plan '<json>'\n")))
      ((status) (write-status))
      ((cron) (health-check) (sync-status) (write-status))
      ((help) (show-help))
      (else (show-help)))))
