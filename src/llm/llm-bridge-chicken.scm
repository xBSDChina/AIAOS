(((((
;; ============================================================================
;; LLM Interaction Bridge - Chicken Scheme
;; Enterprise-grade interface for LLM API calls using Chicken Scheme
;; ============================================================================

(require-extension regex)
(require-extension posix)
(require-extension srfi-13)
(require-extension utf8)
(require-extension base64)
(require-extension (only (chicken http-client) http-get http-post))
(require-extension (only (chicken string) string-placeholder))

;; ---------------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------------

(define *llm-api-endpoint* "https://api.stepfun.com/v1/chat/completions")
(define *llm-api-key* (or (get-environment-variable "LLM_API_KEY") "YOUR_API_KEY_HERE"))
(define *default-model* "step-3.5-flash")
(define *temperature* 0.7)
(define *max-tokens* 4096)

;; ---------------------------------------------------------------------------
;; Types and Data Structures
;; ---------------------------------------------------------------------------

;; Message: (list (list role content))
;; role: 'system | 'user | 'assistant
(define (make-message role content) (list role content))
(define (message-role msg) (car msg))
(define (message-content msg) (cadr msg))

;; Chat history is a list of messages
(define (append-message history role content)
  (append history (list (make-message role content))))

;; ---------------------------------------------------------------------------
;; Serialization (JSON)
;; ---------------------------------------------------------------------------

(define (json-escape-string str)
  (let ((out (open-output-string)))
    (for-each
      (lambda (ch)
        (cond
          ((char=? ch #\") (display "\\\"" out))
          ((char=? ch #\\) (display "\\\\" out))
          ((char=? ch #\newline) (display "\\n" out))
          ((char=? ch #\return) (display "\\r" out))
          ((char=? ch #\tab) (display "\\t" out))
          (else (write-char ch out))))
      (string->list str))
    (get-output-string out)))

(define (json-value->string val)
  (cond
    ((string? val) (string-append "\"" (json-escape-string val) "\""))
    ((number? val) (number->string val))
    ((boolean? val) (if val "true" "false"))
    ((list? val) (string-append "[" (string-join (map json-value->string val) ",") "]"))
    ((hash-table? val)
     (let ((pairs '()))
       (hash-table-for-each
         (lambda (k v) (set! pairs (cons (string-append (json-escape-string (symbol->string k)) ":" (json-value->string v)) pairs)))
         val)
       (string-append "{" (string-join (reverse pairs) ",") "}")))
    (else "\"null\"")))

;; Construct LLM request payload
(define (make-llm-payload messages #!key (model *default-model*) (temperature *temperature*) (max-tokens *max-tokens*))
  (let ((payload (make-hash-table)))
    (hash-table-set! payload 'model model)
    (hash-table-set! payload 'messages (map (lambda (msg)
                                              (let ((h (make-hash-table)))
                                                (hash-table-set! h 'role (->string (message-role msg)))
                                                (hash-table-set! h 'content (message-content msg))
                                                h))
                                            messages))
    (hash-table-set! payload 'temperature temperature)
    (hash-table-set! payload 'max_tokens max-tokens)
    (hash-table->string payload)))

;; ---------------------------------------------------------------------------
;; HTTP Request
;; ---------------------------------------------------------------------------

(define (llm-chat-completion messages)
  (let ((payload (make-llm-payload messages))
        (headers (list (string-append "Authorization: Bearer " *llm-api-key*)
                       "Content-Type: application/json")))
    (handle-exceptions ex
        (begin
          (print "❌ LLM request failed: " ex)
          #f)
      (let ((response (http-post *llm-api-endpoint*
                                 payload
                                 #:headers headers
                                 #:read-response-body #t)))
        (if (and response (string? response) (> (string-length response) 0))
            (extract-assistant-content response)
            (begin
              (print "❌ Empty or invalid response")
              #f))))))

(define (extract-assistant-content json-response)
  ;; Simplified extraction; ideally use proper JSON parser
  (let ((match (regexp-matches "\"content\"\\s*:\\s*\"([^\"]+)\"" json-response)))
    (if match
        (regexp-substitute/global #f "\\\\([^\"\\\\]+)\\\\|n" (cadar match) 'pre 'post)
        "⚠️ Could not extract content")))

;; ---------------------------------------------------------------------------
;; High-Level Interface
;; ---------------------------------------------------------------------------

(define (llm-chat system-prompt user-prompt #!key (history '()))
  (let* ((messages (if history history '()))
         (messages (if system-prompt (append-message messages 'system system-prompt) messages))
         (messages (append-message messages 'user user-prompt)))
    (llm-chat-completion messages)))

(define (llm-complete prompt #!key (context ""))
  (llm-chat "You are an enterprise AI assistant specialized in Chicken Scheme programming and systems design." prompt))

;; ---------------------------------------------------------------------------
;; Convenience Helpers
;; ---------------------------------------------------------------------------

(define (llm-code-generation task-description language #!key (constraints ""))
  (let ((prompt (string-append
                  "Generate production-ready " language " code for the following task:\n\n"
                  task-description "\n\n"
                  "Constraints:\n"
                  "- Use enterprise-grade error handling\n"
                  "- Include comprehensive comments\n"
                  "- Follow best practices and idiomatic style\n"
                  "- Ensure all dependencies are declared\n"
                  "- Add usage examples\n\n"
                  constraints)))
    (llm-complete prompt)))

(define (llm-audit-report component #!key (checkpoints '("L4" "L5" "L6" "L7")))
  (let ((prompt (string-append
                  "Conduct a G-HICS-AM audit readiness assessment for the following component:\n\n"
                  "Component: " component "\n\n"
                  "Check audit compliance for: " (string-join checkpoints ", ") "\n\n"
                  "Provide a structured report with findings and recommendations.")))
    (llm-complete prompt)))

;; ---------------------------------------------------------------------------
;; Example Usage (comment out or remove for production)
;; ---------------------------------------------------------------------------

#|
(print "Testing LLM bridge...")
(let ((response (llm-complete "Explain Chicken Scheme's matchable egg in one paragraph.")))
  (if response
      (print "LLM Response: " response)
      (print "No response")))
|#
)))))