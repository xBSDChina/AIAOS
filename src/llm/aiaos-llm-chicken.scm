;; aiaos-llm-chicken.scm - Pure Chicken Scheme LLM Integration
;; Reads API keys from /home/aiaos/openclaw.json
;; Generates LLM requests and parses responses

(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.condition)
(import chicken.file)
(import chicken.process-context)
(import chicken.port)
(require-extension json)
(require-extension srfi-1)
(require-extension srfi-13)

(define HOME-DIR (or (get-environment-variable "HOME") "/home/aiaos"))
(define OPENCLAW-CONFIG (string-append HOME-DIR "/openclaw.json"))

;; Helper: convert JSON vector to proper alist/list recursively
(define (json->alist obj)
  (if (vector? obj)
    (let ((lst (vector->list obj)))
      (cond
        ; Empty vector
        ((null? lst) '())
        ; Object: elements are pairs or 2-element vectors
        ((or (pair? (car lst))
             (and (vector? (car lst)) (= (vector-length (car lst)) 2)))
         (map (lambda (pair)
                (if (vector? pair)
                  (cons (vector-ref pair 0) (json->alist (vector-ref pair 1)))
                  (cons (car pair) (json->alist (cdr pair)))))
              lst))
        ; Array: convert each element
        (else
          (map json->alist lst))))
    obj))

(define (read-json-file path)
  (condition-case
    (with-input-from-file path (lambda () (json->alist (json-read))))
    (ex () #f)))

(define (llm-config)
  (if (file-exists? OPENCLAW-CONFIG)
    (read-json-file OPENCLAW-CONFIG)
    #f))

(define (get-providers)
  (let ((config (llm-config)))
    (if config
      (let ((llm (assoc "llm" config)))
        (if llm
          (let ((providers (assoc "providers" (cdr llm))))
            (if providers (cdr providers) '()))
          '()))
      '())))

(define (get-default-provider)
  (let ((config (llm-config)))
    (if config
      (let ((llm (assoc "llm" config)))
        (if llm
          (let ((default (assoc "default_provider" (cdr llm))))
            (if default (cdr default) "openrouter"))
          "openrouter"))
      "openrouter")))

(define (format-request provider model messages)
  (let* ((endpoint (if (string=? provider "openrouter")
                      "https://openrouter.ai/api/v1/chat/completions"
                      (if (string=? provider "moonshot")
                        "https://api.moonshot.cn/v1/chat/completions"
                        (if (string=? provider "nvidia")
                          "https://integrate.api.nvidia.com/v1/chat/completions"
                          "http://localhost:11434/api/chat"))))
         (payload (list 'model model
                        'messages messages
                        'temperature 0.7
                        'max_tokens 2048)))
    (list (cons 'endpoint endpoint)
          (cons 'payload payload)
          (cons 'provider provider))))

(define (parse-response json-string)
  (let ((data (with-input-from-string json-string (lambda () (json->alist (json-read))))))
    (if data
      (let ((choices (assoc "choices" data)))
        (if (and choices (pair? (cdr choices)))
          (let ((choices-list (cdr choices)))
            (if (or (vector? choices-list) (list? choices-list))
              (let* ((choice (if (vector? choices-list) (vector-ref choices-list 0) (car choices-list)))
                     (choice-list (if (vector? choice) (vector->list choice) choice))
                     (message-pair (assoc "message" choice-list)))
                (if message-pair
                  (let ((message (cdr message-pair)))
                    (if message
                      (let ((msg-list (if (vector? message) (vector->list message) message)))
                        (let ((content-pair (assoc "content" msg-list)))
                          (if content-pair (cdr content-pair) "No content")))
                      "No content"))
                  "No content"))
              "Invalid choices format"))
          "No choices"))
      "Parse error")))

(define (llm-chat provider model messages)
  (let* ((config (llm-config))
         (llm-section (if config (assoc "llm" config) #f))
         (providers (if llm-section (assoc "providers" (cdr llm-section)) #f))
         (provider-config (if providers (assoc provider (cdr providers)) #f)))
    (if (not provider-config)
      (list 'error (string-append "Unknown provider: " provider))
      (let* ((api-key (cdr (assoc "api_key" (cdr provider-config))))
             (endpoint-info (format-request provider model messages))
             (endpoint-url (cdr (assoc 'endpoint endpoint-info)))
             (payload (cdr (assoc 'payload endpoint-info)))
             (payload-json (with-output-to-string (lambda () (json-write payload)))))
        (list (cons 'provider provider)
              (cons 'model model)
              (cons 'endpoint endpoint-url)
              (cons 'payload payload-json)
              (cons 'api_key api-key)
              (cons 'curl-command (string-append 
                                    "curl -s -X POST " endpoint-url
                                    " -H 'Content-Type: application/json'"
                                    " -H 'Authorization: Bearer " api-key "'"
                                    " -d '" payload-json "'")))))))
