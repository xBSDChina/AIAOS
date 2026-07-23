#!/usr/local/bin/csi -s
;; ================================================================
;; AIAOS Web Request Handler - for use with: nc -l 8080 -e this.scm
;; ================================================================
;; This is a single-request-per-execution handler.
;; netcat spawns a new process for each connection,
;; so state is managed through shared files or in-memory caches.
;; ================================================================

(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.json)
(import chicken.pathname)
(import chicken.process)
(import chicken.srfi-1)
(import chicken.srfi-13)

;; Load core modules (assume they are in standard load path)
(require-extension (chicken.file))
(require-extension (chicken.process))
(require-extension (chicken.string))

;; For this standalone handler, we'll inline minimal necessary functions
;; rather than loading full aiaos-core to reduce overhead

(define HOME-DIR (or (get-environment-variable "HOME") "/home/aiaos"))
(define AIAOS-HOME (make-pathname HOME-DIR "aiaos"))
(define DATA-DIR (make-pathname AIAOS-HOME "data"))
(define STATE-FILE (make-pathname DATA-DIR "state.json"))

(define (current-timestamp)
  (let ((now (current-seconds)))
    (string-append
      (number->string (quotient now 86400)) "-"
      (number->string (modulo (quotient now 3600) 24)) "-"
      (number->string (modulo (quotient now 60) 60)) "-"
      (number->string (modulo now 60)))))

(define (read-json-file path)
  (if (file-exists? path)
      (condition-case
          (json->scm (call-with-input-file path read-string))
        (ex () '()))
      '()))

(define (json-response code data)
  (let ((json (scm->json data)))
    (display (string-append "HTTP/1.1 " (number->string code) " OK\r\n") (current-output-port))
    (display "Content-Type: application/json\r\n" (current-output-port))
    (display (string-append "Content-Length: " (number->string (string-length json)) "\r\n") (current-output-port))
    (display "Connection: close\r\n\r\n" (current-output-port))
    (display json (current-output-port)))

(define (html-response content)
  (display "HTTP/1.1 200 OK\r\n" (current-output-port))
  (display "Content-Type: text/html; charset=utf-8\r\n" (current-output-port))
  (display (string-append "Content-Length: " (number->string (string-length content)) "\r\n") (current-output-port))
  (display "Connection: close\r\n\r\n" (current-output-port))
  (display content (current-output-port))

(define (file-response filepath)
  (if (and (file-exists? filepath) (file-readable? filepath))
      (let ((content (call-with-input-file filepath read-string))
            (ext (pathname-extension filepath))
            (ct (cond ((string=? ext "css") "text/css")
                      ((string=? ext "js") "application/javascript")
                      ((string=? ext "html") "text/html")
                      (else "text/plain"))))
        (display "HTTP/1.1 200 OK\r\n" (current-output-port))
        (display (string-append "Content-Type: " ct "\r\n") (current-output-port))
        (display (string-append "Content-Length: " (number->string (string-length content)) "\r\n") (current-output-port))
        (display "Connection: close\r\n\r\n" (current-output-port))
        (display content (current-output-port)))
      (json-response 404 `((error . #t) (message . "File not found"))))

(define (read-http-request)
  "Parse HTTP request from stdin"
  (let ((request-line (read-line)))
    (if (eof-object? request-line)
        #f
        (let ((parts (string-split request-line #\space)))
          (if (>= (length parts) 3)
              (let ((method (car parts))
                    (path (cadr parts))
                    (version (caddr parts))
                    (headers (read-headers))
                    (body (read-body headers)))
                (list method path headers body))
              #f)))))

(define (read-headers)
  (let loop ((headers '()))
    (let ((line (read-line)))
      (if (or (eof-object? line) (string=? line ""))
          (reverse headers)
          (loop (cons line headers)))))

(define (read-body headers)
  (let ((cl-header (find (lambda (h) (string-prefix? "Content-Length:" h)) headers)))
    (if cl-header
        (let ((len (string->number (string-trim (substring cl-header 15)))))
          (if len
              (read-string len (current-input-port))
              ""))
        "")))

(define (parse-query path)
  (let ((idx (string-index path #\?)))
    (if idx
        (let ((query (substring path (+ idx 1))))
          (let ((pairs (string-split query #\&)))
            (map (lambda (pair)
                   (let ((kv (string-split pair #\=)))
                     (if (= (length kv) 2)
                         (cons (car kv) (url-decode (cadr kv)))
                         (cons (car kv) ""))))
                 pairs)))
        '())))

(define (url-decode str)
  (list->string
    (let loop ((chars (string->list str)) (out '()))
      (if (null? chars)
          (reverse out)
          (let ((c (car chars)))
            (loop (cdr chars)
                  (if (char=? c #\%)
                      (let ((hex (string (cadr chars) (caddr chars))))
                        (append (cons (integer->char (string->number hex 16)) out) (cdddr chars)))
                      (cons c out))))))))

(define (load-state)
  (if (file-exists? STATE-FILE)
      (read-json-file STATE-FILE)
      '((functions . ())
        (tasks . ())
        (components . ())
        (started-at . 0))))

(define (get-system-status)
  (let ((state (load-state)))
    `((status . "operational")
      (functions . ,(length (alist-ref 'functions state)))
      (tasks . ,(length (alist-ref 'tasks state)))
      (components . ,(length (alist-ref 'components state)))
      (version . "1.0.0")
      (uptime . ,(- (current-seconds) (alist-ref 'started-at state 0))))))

(define (get-tasks . args)
  (let ((state (load-state))
        (tasks (alist-ref 'tasks state '())))
    (if (null? args) tasks (take tasks (car args)))))

(define (get-functions)
  (alist-ref 'functions (load-state) '()))

(define (get-components)
  (alist-ref 'components (load-state) '()))

(define (get-metrics)
  (let ((state (load-state))
        (tasks (alist-ref 'tasks state '())))
    `((timestamp . ,(current-timestamp))
      (uptime . ,(- (current-seconds) (alist-ref 'started-at state 0)))
      (functions . ,(length (alist-ref 'functions state)))
      (tasks-total . ,(length tasks))
      (tasks-pending . ,(count (lambda (t) (string=? (alist-ref 'status t) "pending")) tasks))
      (tasks-running . ,(count (lambda (t) (string=? (alist-ref 'status t) "running")) tasks))
      (tasks-completed . ,(count (lambda (t) (string=? (alist-ref 'status t) "completed")) tasks))
      (tasks-failed . ,(count (lambda (t) (string=? (alist-ref 'status t) "failed")) tasks)))))

;; ================================================================
;; Main Request Router
;; ================================================================

(let ((req (read-http-request)))
  (if req
      (let ((method (car req))
            (path (cadr req))
            (headers (caddr req))
            (body (cadddr req)))
        (web-log "INFO" method path)

        (cond
          ;; Health
          ((and (string=? method "GET") (string=? path "/health"))
           (json-response 200 `((status . "operational") (timestamp . ,(current-seconds)))))

          ;; API Status
          ((and (string=? method "GET") (string=? path "/api/status"))
           (json-response 200 (get-system-status)))

          ;; API Functions
          ((and (string=? method "GET") (string=? path "/api/functions"))
           (json-response 200 (get-functions)))

          ;; API Tasks
          ((and (string=? method "GET") (string-prefix? "/api/tasks" path))
           (let* ((query-params (parse-query path))
                  (limit (or (string->number (alist-ref 'limit query-params)) 10)))
             (json-response 200 (get-tasks limit))))

          ;; API Components
          ((and (string=? method "GET") (string=? path "/api/components"))
           (json-response 200 (get-components)))

          ;; API Metrics
          ((and (string=? method "GET") (string=? path "/api/metrics"))
           (json-response 200 (get-metrics)))

          ;; API LLM Chat (proxy to LLM bridge)
          ((and (string=? method "POST") (string=? path "/api/llm/chat"))
           (let ((payload (json->scm body)))
             (json-response 200 `((note . "LLM chat proxy not implemented in handler yet")))))

          ;; Dashboard HTML
          ((and (string=? method "GET") (or (string=? path "/") (string=? path "/index.html")))
           (let ((html-path (make-pathname AIAOS-HOME "web" "dashboard.html")))
             (if (file-exists? html-path)
                 (file-response html-path)
                 (html-response "<!DOCTYPE html><html><body><h1>AIAOS Dashboard</h1><p>Please run (web-start-dashboard) in main process to generate assets.</p></body></html>"))))

          ;; Static files
          ((and (string=? method "GET") (string-prefix? "/static/" path))
           (let ((static-path (make-pathname AIAOS-HOME "web" (substring path 8))))
             (file-response static-path)))

          (else
           (json-response 404 `((error . #t) (message . "Not found"))))
        ))
      (begin
        (display "HTTP/1.1 400 Bad Request\r\n\r\n")
        (display "Invalid request")))

) ;; end

(define (web-log level . msgs)
  (let ((ts (current-timestamp)))
    (with-output-to-file (make-pathname (or (get-environment-variable "HOME") "/tmp") "web-handler.log")
      (lambda ()
        (display "[" ts "] [" level "] ")
        (for-each (lambda (m) (display m) (display " ")) msgs)
        (newline))
      append:)))
