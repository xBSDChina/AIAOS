;; ================================================================
;; AIAOS Enterprise Dashboard - Single Request HTTP Handler
;; ================================================================
;; Intended to be used with: nc -l 8080 -e aiaos-web-handler.scm
;; This script handles ONE HTTP request and exits.
;; For continuous service, a wrapper loops around nc -l.
;; ================================================================

(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.file)
(import chicken.json)
(import chicken.process)
(import chicken.condition)
(import chicken.srfi-1)
(import chicken.srfi-13)

;; ================================================================
;; Paths (read from environment or defaults)
;; ================================================================

(define HOME-DIR (or (get-environment-variable "HOME") "/home/aiaos"))
(define AIAOS-HOME (make-pathname HOME-DIR "aiaos"))
(define DATA-DIR (make-pathname AIAOS-HOME "data"))
(define STATE-FILE (make-pathname DATA-DIR "state.json"))
(define WEB-DIR (make-pathname AIAOS-HOME "web"))

;; ================================================================
;; Logging
;; ================================================================

(define (log level . msgs)
  (let ((logfile (make-pathname AIAOS-HOME "logs" "web-handler.log")))
    (ensure-directory-exists (pathname-directory logfile))
    (with-output-to-file logfile
      (lambda ()
        (display "[" (current-timestamp) "] [" level "] ")
        (for-each (lambda (m) (display m) (display " ")) msgs)
        (newline))
      append:)))

(define (ensure-directory-exists dir)
  (unless (directory-exists? dir)
    (create-directory dir #t)))

(define (current-timestamp)
  (let ((now (current-seconds)))
    (string-append
      (number->string (quotient now 86400)) "-"
      (number->string (modulo (quotient now 3600) 24)) "-"
      (number->string (modulo (quotient now 60) 60)) "-"
      (number->string (modulo now 60)))))

;; ================================================================
;; Utility Functions (if not in imported modules)
;; ================================================================

(define (take n lst)
  (if (or (<= n 0) (null? lst)) '()
      (cons (car lst) (take (- n 1) (cdr lst)))))

(define (count pred lst)
  (let loop ((lst lst) (n 0))
    (if (null? lst) n
        (loop (cdr lst) (if (pred (car lst)) (+ n 1) n)))))

(define (string-prefix? prefix str)
  (let ((plen (string-length prefix))
        (slen (string-length str)))
    (and (<= plen slen)
         (string=? prefix (substring str 0 plen)))))

(define (string-suffix? suffix str)
  (let ((slen (string-length str))
        (sulen (string-length suffix)))
    (and (<= sulen slen)
         (string=? suffix (substring str (- slen sulen) slen)))))

(define (string-index str ch)
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond ((>= i len) #f)
            ((char=? (string-ref str i) ch) i)
            (else (loop (+ i 1))))))

(define (alist-ref key alist . default)
  (let ((pair (find (lambda (p) (equal? (car p) key)) alist)))
    (if pair (cdr pair) (if (null? default) #f (car default)))))

(define (find pred lst)
  (cond ((null? lst) #f)
        ((pred (car lst)) (car lst))
        (else (find pred (cdr lst)))))

;; ================================================================
;; JSON Helpers
;; ================================================================

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
  (display content (current-output-port)))

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
      (json-response 404 `((error . #t) (message . "File not found")))))

;; ================================================================
;; State & Data Loading
;; ================================================================

(define (load-state)
  (if (file-exists? STATE-FILE)
      (condition-case
          (json->scm (call-with-input-file STATE-FILE read-string))
        (ex (e)
          (log "ERROR" "Failed to parse state:" e)
          '((functions . ()) (tasks . ()) (components . ()) (started-at . 0))))
      '((functions . ()) (tasks . ()) (components . ()) (started-at . 0))))

(define (get-system-status)
  (let ((state (load-state)))
    `((status . "operational")
      (functions . ,(length (alist-ref 'functions state '())))
      (tasks . ,(length (alist-ref 'tasks state '())))
      (components . ,(length (alist-ref 'components state '())))
      (version . "1.0.0")
      (uptime . ,(- (current-seconds) (alist-ref 'started-at state 0))))))

(define (get-tasks . limit-arg)
  (let ((limit (if (null? limit-arg) 10 (car limit-arg)))
        (tasks (alist-ref 'tasks (load-state) '())))
    (take tasks limit)))

(define (get-functions)
  (alist-ref 'functions (load-state) '()))

(define (get-components)
  (alist-ref 'components (load-state) '()))

(define (get-metrics)
  (let ((state (load-state))
        (tasks (alist-ref 'tasks state '())))
    `((timestamp . ,(current-timestamp))
      (uptime . ,(- (current-seconds) (alist-ref 'started-at state 0)))
      (functions . ,(length (alist-ref 'functions state '())))
      (components . ,(length (alist-ref 'components state '())))
      (total-tasks . ,(length tasks))
      (status-breakdown . ,(list
                             (cons "pending" (count (lambda (t) (string=? (alist-ref 'status t) "pending")) tasks))
                             (cons "running" (count (lambda (t) (string=? (alist-ref 'status t) "running")) tasks))
                             (cons "completed" (count (lambda (t) (string=? (alist-ref 'status t) "completed")) tasks))
                             (cons "failed" (count (lambda (t) (string=? (alist-ref 'status t) "failed")) tasks)))))))

;; ================================================================
;; HTTP Parsing
;; ================================================================

(define (read-request)
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
  (let ((cl (find (lambda (h) (string-prefix? "Content-Length:" h)) headers)))
    (if cl
        (let ((len (string->number (string-trim (substring cl 15)))))
          (if len
              (read-string len (current-input-port))
              ""))
        "")))

(define (parse-query path)
  (let ((idx (string-index path #\?)))
    (if idx
        (let ((query (substring path (+ idx 1) (string-length path))))
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

(define (string-index str ch)
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond ((>= i len) #f)
            ((char=? (string-ref str i) ch) i)
            (else (loop (+ i 1))))))

(define (current-seconds)
  (let ((t (seconds)))
    (inexact->exact (floor t))))

;; ================================================================
;; Main Handler
;; ================================================================

(define (handle-request method path headers body)
  (log "DEBUG" method path)

  (cond
    ((and (string=? method "GET") (string=? path "/health"))
     (json-response 200 `((status . "operational") (timestamp . ,(current-seconds)))))

    ((and (string=? method "GET") (string=? path "/api/status"))
     (json-response 200 (get-system-status)))

    ((and (string=? method "GET") (string=? path "/api/functions"))
     (json-response 200 (get-functions)))

    ((and (string=? method "GET") (string-prefix? "/api/tasks" path))
     (let* ((query (if (string-index path #\?) (substring path (+ (string-index path #\?) 1)) ""))
            (params (parse-query query))
            (limit (or (string->number (alist-ref 'limit params)) 10)))
       (json-response 200 (get-tasks limit))))

    ((and (string=? method "GET") (string=? path "/api/components"))
     (json-response 200 (get-components)))

    ((and (string=? method "GET") (string=? path "/api/metrics"))
     (json-response 200 (get-metrics)))

    ((and (string=? method "GET") (or (string=? path "/") (string=? path "/index.html")))
     (let ((html (make-pathname WEB-DIR "dashboard.html")))
       (if (file-exists? html)
           (file-response html)
           (html-response "<!DOCTYPE html><html><body><h1>AIAOS Dashboard</h1><p>Dashboard not generated yet. Run aiaos dashboard init.</p></body></html>"))))

    ((and (string=? method "GET") (string-prefix? "/static/" path))
     (let ((static-file (make-pathname WEB-DIR (substring path 8))))
       (file-response static-file)))

    (else
     (json-response 404 `((error . #t) (message . "Not found"))))
  ))

;; ================================================================
;; Entry Point (called by netcat -e)
;; ================================================================

(let ((req (read-request)))
  (if req
      (let ((method (car req))
            (path (cadr req))
            (headers (caddr req))
            (body (cadddr req)))
        (condition-case
            (handle-request method path headers body)
          (ex (e)
            (log "ERROR" "Request failed:" e)
            (json-response 500 `((error . #t) (message . ,(string-append "Server error: " (->string e)))))))
      (begin
        (display "HTTP/1.1 400 Bad Request\r\n\r\n")
        (display "Invalid HTTP request")))

) ;; end module
