;;; claw2ee-bridge.scm
;;; AIAOS ↔ Claw2EE Integration Bridge
;;; Compiled with: chicken-csc claw2ee-bridge.scm -o claw2ee-bridge
;;; Provides: submit_chain, check_audit, sync_status, get_layer_progress

(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.process)
(import chicken.process-context)
(import chicken.condition)
(require-extension json)
(require-extension srfi-18)

(define CLAW2EE-URL "http://localhost:8082")
(define ENDPOINT (string-append CLAW2EE-URL "/api/v1/tools/ghics_am_status"))
(define BRIDGE-LOG "/home/aiaos/aiaos/logs/claw2ee-bridge.log")
(define STATUS-FILE "/home/aiaos/aiaos/status/claw2ee.json")

(define (ts)
  (let* ((now (current-seconds))
         (s (modulo now 60)) (m (modulo (quotient now 60) 60))
         (h (modulo (quotient now 3600) 24)) (d (quotient now 86400)))
    (string-append (number->string (+ 1970 (quotient d 365))) "-"
      (number->string (+ 1 (quotient (modulo d 365) 30))) "-"
      (number->string (+ 1 (modulo d 30))) "T"
      (number->string h) ":" (number->string m) ":" (number->string s) "Z")))

(define (log! msg)
  (let ((e (string-append "[" (ts) "] [CLAW2EE-BRIDGE] " msg)))
    (display e) (newline)
    (condition-case (with-output-to-file BRIDGE-LOG (lambda () (display e) (newline)) append:) (ex () (void)))))

(define (shell cmd)
  (with-input-from-pipe cmd
    (lambda () (let loop ((l '()) (ln (read-line)))
                 (if (eof-object? ln) (string-intersperse (reverse l) "\n") (loop (cons ln l) (read-line)))))))

;; =============================================================================
;; Actions
;; =============================================================================

(define (health-check)
  (let* ((cmd (string-append "curl -s -o /dev/null -w \"%{http_code}\" " CLAW2EE-URL))
         (result (shell cmd)))
    (log! (string-append "Health check: HTTP " (string-trim result)))))

(define (sync-status)
  (let* ((active (condition-case (read-file "/home/aiaos/aiaos/status/heartbeat.json") (ex () "{}")))
         (objectives (condition-case (read-file "/home/aiaos/aiaos/status/task_objectives.json") (ex () "{}")))
         (payload (string-append
                    "{\"action\":\"sync\",\"payload\":{\"source\":\"objective-engine\","
                    "\"heartbeat\":" active ",\"objectives\":" objectives ",\"timestamp\":\"" (ts) "\"}}"))
         (cmd (string-append "curl -s -X POST " ENDPOINT " -H 'Content-Type: application/json' -d '"
                payload "'"))
         (result (shell cmd)))
    (log! (string-append "Sync result: " (substring result 0 (min 200 (string-length result)))))))

(define (submit-chain chain-id chain-json)
  (let* ((payload (string-append
                    "{\"action\":\"submit_chain\",\"payload\":{\"chain_id\":\"" chain-id "\","
                    "\"chain\":" chain-json ",\"timestamp\":\"" (ts) "\"}}"))
         (cmd (string-append "curl -s -X POST " ENDPOINT " -H 'Content-Type: application/json' -d '"
                payload "'"))
         (result (shell cmd)))
    (log! (string-append "Chain submit: " chain-id " → " (substring result 0 (min 100 (string-length result)))))))

(define (check-audit)
  (let* ((payload (string-append "{\"action\":\"check_audit\",\"payload\":{\"timestamp\":\"" (ts) "\"}}"))
         (cmd (string-append "curl -s -X POST " ENDPOINT " -H 'Content-Type: application/json' -d '"
                payload "'"))
         (result (shell cmd)))
    (log! (string-append "Audit check: " (substring result 0 (min 200 (string-length result)))))
    result))

(define (write-status)
  (let ((status (string-append
                  "{\"status\":\"active\",\"last_sync\":\"" (ts) "\","
                  "\"endpoint\":\"" ENDPOINT "\",\"version\":\"2.0.0\"}")))
    (condition-case (with-output-to-file STATUS-FILE (lambda () (display status))) (ex () (void)))
    (display status) (newline)))

(define (show-help)
  (display "Claw2EE Bridge v2.0.0
Usage: claw2ee-bridge <command>

Commands:
  health       Check claw2ee health
  sync         Sync objectives and heartbeat
  submit <id>  Submit chain ID (reads from stdin)
  audit        Check latest audit
  status       Write status file
  cron         Full bridge cycle
  help         Show this
"))

(let ((args (command-line-arguments)))
  (if (null? args) (begin (health-check) (sync-status) (write-status))
    (case (string->symbol (car args))
      ((health) (health-check))
      ((sync) (sync-status) (write-status))
      ((submit) (if (>= (length args) 2)
                  (let ((chain (read-string #f)))
                    (if chain (submit-chain (cadr args) chain) (display "No chain on stdin")))
                  (display "Usage: claw2ee-bridge submit <chain-id> < chain.json")))
      ((audit) (display (check-audit)))
      ((status) (write-status))
      ((cron) (health-check) (sync-status) (write-status))
      ((help) (show-help))
      (else (show-help)))))
