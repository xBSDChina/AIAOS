#!/usr/bin/chicken-csi -s
(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.process)
(import chicken.process-context)
(import chicken.condition)
(require-extension json)
(require-extension srfi-18)

(define AIAOS-HOME "/home/aiaos/aiaos")
(define OBJECTIVES-DIR (string-append AIAOS-HOME "/objectives"))
(define STATUS-DIR (string-append AIAOS-HOME "/status"))
(define LOG-DIR (string-append AIAOS-HOME "/logs"))
(define CRON-LOG (string-append LOG-DIR "/cron-objective.log"))

(define (ts)
  (let* ((now (current-seconds))
         (s (modulo now 60)) (m (modulo (quotient now 60) 60))
         (h (modulo (quotient now 3600) 24)) (d (quotient now 86400)))
    (string-append (number->string (+ 1970 (quotient d 365))) "-"
      (number->string (+ 1 (quotient (modulo d 365) 30))) "-"
      (number->string (+ 1 (modulo d 30))) "T"
      (number->string h) ":" (number->string m) ":" (number->string s) "Z")))

(define (log! msg)
  (let ((e (string-append "[" (ts) "] [CRON-OBJECTIVE] " msg)))
    (display e) (newline)
    (condition-case
      (with-output-to-file CRON-LOG (lambda () (display e) (newline)) append:)
      (ex () (void)))))

(define (shell cmd)
  (with-input-from-pipe cmd
    (lambda () (let loop ((l '()) (ln (read-line)))
                 (if (eof-object? ln) (string-intersperse (reverse l) "\n") (loop (cons ln l) (read-line)))))))

(define (ensure-dir dir)
  (condition-case (system (string-append "mkdir -p " dir)) (ex () #f)))

(define (file-exists? path)
  (condition-case (begin (with-input-from-file path (lambda () #t)) #t) (ex () #f)))

(define (read-file path)
  (condition-case (with-input-from-file path (lambda () (read-string #f))) (ex () #f)))

(define (run-phase name cmd)
  (log! (string-append ">>> Phase: " name))
  (let ((result (shell cmd)))
    (if result
      (begin
        (log! (string-append "  Result: " (substring result 0 (min 200 (string-length result)))))
        #t)
      (begin
        (log! "  No output (may have succeeded)")
        #t))))

(define (full-cron-cycle)
  (log! "================================================")
  (log! "AIAOS Objective-Driven CRON Cycle Starting")
  (log! "================================================")
  
  (ensure-dir OBJECTIVES-DIR)
  (ensure-dir STATUS-DIR)
  (ensure-dir LOG-DIR)
  
  (let* ((engine-bin (string-append OBJECTIVES-DIR "/objective-engine")))
    (if (file-exists? engine-bin)
      (run-phase "Objective Engine" (string-append engine-bin " cron 2>&1"))
      (run-phase "Objective Engine (CSI)" (string-append "/usr/local/bin/chicken-csi -s " OBJECTIVES-DIR "/objective-engine.scm cron 2>&1"))))
  
  (let* ((chain-bin (string-append OBJECTIVES-DIR "/task-chain-engine")))
    (if (file-exists? chain-bin)
      (run-phase "Task Chain Engine" (string-append chain-bin " cron 2>&1"))
      (run-phase "Task Chain Engine (CSI)" (string-append "/usr/local/bin/chicken-csi -s " OBJECTIVES-DIR "/task-chain-engine.scm cron 2>&1"))))
  
  (let* ((claw-bin (string-append OBJECTIVES-DIR "/claw2ee-bridge")))
    (if (file-exists? claw-bin)
      (run-phase "Claw2EE Bridge" (string-append claw-bin " cron 2>&1"))
      (run-phase "Claw2EE Bridge (CSI)" (string-append "/usr/local/bin/chicken-csi -s " OBJECTIVES-DIR "/claw2ee-bridge.scm cron 2>&1"))))
  
  (let* ((omni-bin (string-append OBJECTIVES-DIR "/omnicode-bridge")))
    (if (file-exists? omni-bin)
      (run-phase "OmniCode Bridge" (string-append omni-bin " cron 2>&1"))
      (run-phase "OmniCode Bridge (CSI)" (string-append "/usr/local/bin/chicken-csi -s " OBJECTIVES-DIR "/omnicode-bridge.scm cron 2>&1"))))
  
  (let* ((now (current-seconds))
         (summary (string-append "{\"cron_cycle\":\"objective-driven\",\"timestamp\":\"" (ts) "\",\"phases\":[\"objective-engine\",\"task-chain-engine\",\"claw2ee-bridge\",\"omnicode-bridge\"],\"cycle_seconds\":" (number->string (- (current-seconds) now)) "}")))
    (condition-case (with-output-to-file (string-append STATUS-DIR "/cron-cycle.json") (lambda () (display summary))) (ex () (void))))
  
  (log! "================================================")
  (log! "AIAOS Objective-Driven CRON Cycle Complete")
  (log! "================================================"))

(define (show-help)
  (display "AIAOS Objective-Driven CRON Handler v2.0.0
Usage: cron-objective [command]

Commands:
  cron         Full objective-driven cron cycle (default)
  phases       List all phases
  help         Show this
"))

(let ((args (command-line-arguments)))
  (if (or (null? args) (string=? (car args) "cron"))
    (full-cron-cycle)
    (case (string->symbol (car args))
      ((cron) (full-cron-cycle))
      ((phases) (display "Objective-Driven CRON Phases:\n  1. objective-engine\n  2. task-chain-engine\n  3. claw2ee-bridge\n  4. omnicode-bridge\n"))
      ((help) (show-help))
      (else (show-help)))))
