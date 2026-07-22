;;; aiaos-80-dashboard.scm
;;; Chicken Scheme Business Logic for AIAOS Enterprise Dashboard (Port 80)
;;; Generated: 2026-07-17 05:40 UTC
;;; Usage: chicken-csi -s aiaos-80-dashboard.scm -- "GET /api/health"

(import (chicken base))
(import (chicken string))
(import (chicken io))
(import (chicken port))
(import (chicken process))
(import (chicken time))
(import (chicken process-context))
(import (srfi-1))
(import (srfi-13))
(require-extension json)
(require-extension srfi-14)

;; =============================================================================
;; Constants
;; =============================================================================
(define VM_D "192.168.122.150")
(define PROD_DAY 62)
(define CHICKEN_VERSION "5.4.0")
(define FREEBSD_VERSION "15.0")

;; =============================================================================
;; HTTP Utilities
;; =============================================================================
(define (http-ok body content-type)
  (string-append
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: " content-type "\r\n"
    "Access-Control-Allow-Origin: *\r\n"
    "Content-Length: " (number->string (string-length body)) "\r\n"
    "\r\n"
    body))

(define (http-json obj)
  (http-ok (json->string obj) "application/json"))

(define (http-html html)
  (http-ok html "text/html; charset=utf-8"))

(define (http-404)
  (http-ok "{\"error\":\"not found\"}" "application/json"))

;; =============================================================================
;; JSON Helpers
;; =============================================================================
(define (json->string obj)
  (with-output-to-string
    (lambda () (json-write obj))))

(define (run-cmd cmd)
  (let ((p (process cmd)))
    (letrec ((read-all (lambda (acc)
      (let ((line (read-line p)))
        (if (eof-object? line)
            (begin (close-input-port p) (apply string-append (reverse acc)))
            (read-all (cons line acc)))))))
      (read-all '()))))

(define (fetch-json url)
  (let ((raw (run-cmd (string-append "curl -s " url))))
    (if (and raw (> (string-length raw) 0))
        (json->alist (json-read (open-input-string raw)))
        #f)))

;; =============================================================================
;; JSON -> Alist converter (json-read returns vectors)
;; =============================================================================
(define (json->alist obj)
  (cond
    ((vector? obj)
     (let ((lst (vector->list obj)))
       (if (and (= (length lst) 1) (pair? (car lst)))
           (car lst)
           lst)))
    ((pair? obj) obj)
    (else obj)))

(define (alist-ref alist key)
  (let ((pair (assoc key alist)))
    (if pair (cdr pair) #f)))

(define (alist-ref-default alist key default)
  (let ((pair (assoc key alist)))
    (if pair (cdr pair) default)))

;; =============================================================================
;; Data Fetching
;; =============================================================================
(define (fetch-dash-status)
  (fetch-json (string-append "http://" VM_D ":8888/api/status")))

(define (fetch-claw2ee-hierarchy)
  (fetch-json (string-append "http://" VM_D ":8082/api/tasks/hierarchy")))

;; =============================================================================
;; API Endpoints
;; =============================================================================
(define (api-health)
  (let* ((dash (fetch-dash-status))
         (health (if dash (alist-ref dash 'health) '()))
         (score (if (and health (pair? health)) (alist-ref-default health 'score 0) 0))
         (online (if (and health (pair? health)) (alist-ref-default health 'online 0) 0))
         (total (if (and health (pair? health)) (alist-ref-default health 'total 0) 0)))
    `((status . ,(if (>= score 80) "healthy" "degraded"))
      (service . "aiaos-enterprise-dashboard")
      (version . "2.0.0")
      (port . 80)
      (vm . ,VM_D)
      (freebsd . ,FREEBSD_VERSION)
      (chicken . ,CHICKEN_VERSION)
      (prod_day . ,PROD_DAY)
      (health_score . ,score)
      (services_online . ,(string-append (number->string online) "/" (number->string total)))
      (timestamp . ,(timestamp-now)))))

(define (api-status)
  (let* ((dash (fetch-dash-status))
         (claw2ee (fetch-claw2ee-hierarchy))
         (health (if dash (alist-ref dash 'health) '()))
         (score (if (and health (pair? health)) (alist-ref-default health 'score 0) 0))
         (online (if (and health (pair? health)) (alist-ref-default health 'online 0) 0))
         (total-count (if (and health (pair? health)) (alist-ref-default health 'total 0) 0))
         (sys-status (if (and health (pair? health)) (alist-ref-default health 'status "unknown") "unknown"))
         (tasks (if dash (alist-ref dash 'tasks) '()))
         (claw2ee-data (if claw2ee (alist-ref claw2ee 'data) '()))
         (claw2ee-stats (if claw2ee-data (alist-ref claw2ee-data 'stats) '()))
         (by-status (if claw2ee-stats (alist-ref claw2ee-stats 'byStatus) '())))
    `((service . "aiaos-enterprise-dashboard")
      (port . 80)
      (vm . ,VM_D)
      (freebsd . ,FREEBSD_VERSION)
      (chicken . ,CHICKEN_VERSION)
      (prod_day . ,PROD_DAY)
      (health_score . ,score)
      (services_online . ,online)
      (services_total . ,total-count)
      (system_status . ,sys-status)
      (tasks_total . ,(if tasks (alist-ref-default tasks 'total 0) 0))
      (tasks_done . ,(if tasks (alist-ref-default tasks 'done 0) 0))
      (tasks_completion_rate . ,(if tasks (alist-ref-default tasks 'completion_rate 0) 0))
      (claw2ee_tasks_total . ,(if claw2ee-stats (alist-ref-default claw2ee-stats 'total 0) 0))
      (claw2ee_tasks_completed . ,(if by-status (alist-ref-default by-status 'completed 0) 0))
      (claw2ee_tasks_in_progress . ,(if by-status (alist-ref-default by-status 'in_progress 0) 0))
      (claw2ee_tasks_pending . ,(if by-status (alist-ref-default by-status 'pending 0) 0))
      (timestamp . ,(timestamp-now)))))

;; =============================================================================
;; Dashboard HTML (Server-Side Rendered)
;; =============================================================================
(define (dashboard-html)
  (string-append
    "<!DOCTYPE html><html lang=\"zh-CN\"><head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"><title>AIAOS Enterprise Dashboard</title><style>"
    "* { margin: 0; padding: 0; box-sizing: border-box; }"
    "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0a0e27; color: #fff; min-height: 100vh; }"
    ".header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; text-align: center; }"
    ".header h1 { font-size: 2em; margin-bottom: 10px; }"
    ".container { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; padding: 20px; max-width: 1600px; margin: 0 auto; }"
    ".card { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 20px; }"
    ".card-header { display: flex; align-items: center; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px solid rgba(255,255,255,0.1); }"
    ".card-icon { width: 40px; height: 40px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 1.5em; margin-right: 12px; }"
    ".card-title { font-size: 1.2em; font-weight: 600; }"
    ".card-subtitle { font-size: 0.8em; opacity: 0.7; }"
    ".card-body { margin-top: 10px; }"
    ".metric { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.05); }"
    ".metric-label { opacity: 0.7; }"
    ".metric-value { font-weight: 600; color: #64ffda; }"
    ".chain-item { padding: 8px; margin: 5px 0; background: rgba(255,255,255,0.05); border-radius: 6px; border-left: 3px solid #667eea; }"
    ".footer { text-align: center; padding: 20px; opacity: 0.6; font-size: 0.8em; }"
    "</style></head><body>"
    "<div class=\"header\"><h1>AIAOS Enterprise Dashboard</h1><div>Chicken Scheme " CHICKEN_VERSION " | FreeBSD " FREEBSD_VERSION " | Production Day: " (number->string PROD_DAY) "</div></div>"
    "<div class=\"container\">"
    "<div class=\"card\"><div class=\"card-header\"><div class=\"card-icon\" style=\"background: linear-gradient(135deg, #667eea, #764ba2);\">Function Chain</div><div><div>L0-L9 Core Layers</div></div></div><div class=\"card-body\"><div class=\"chain-item\">L0: Execute | L1: Isolate | L2: Calibrate</div><div class=\"chain-item\">L3: Resilience | L4: Persistence | L5: Choreograph</div><div class=\"chain-item\">L6: Verify | L7: Decide | L8: Evolve | L9: Terminate</div></div></div>"
    "<div class=\"card\"><div class=\"card-header\"><div class=\"card-icon\" style=\"background: linear-gradient(135deg, #f093fb, #f5576c);\">Task Chain</div><div><div>Claw2EE Integration</div></div></div><div class=\"card-body\"><div class=\"chain-item\">Hierarchy: /api/tasks/hierarchy</div><div class=\"chain-item\">Execute: /api/tasks/execute/:id</div><div class=\"chain-item\">Guidance: /api/tasks/guidance/:id</div></div></div>"
    "<div class=\"card\"><div class=\"card-header\"><div class=\"card-icon\" style=\"background: linear-gradient(135deg, #4facfe, #00f2fe);\">Status Chain</div><div><div>System Health</div></div></div><div class=\"card-body\"><div class=\"metric\"><span>Status</span><span style=\"color:#64ffda\">OPERATIONAL</span></div><div class=\"metric\"><span>FreeBSD</span><span style=\"color:#64ffda\">15.0</span></div><div class=\"metric\"><span>Chicken Scheme</span><span style=\"color:#64ffda\">5.4.0</span></div></div></div>"
    "<div class=\"card\"><div class=\"card-header\"><div class=\"card-icon\" style=\"background: linear-gradient(135deg, #43e97b, #38f9d7);\">Component Chain</div><div><div>Framework Modules</div></div></div><div class=\"card-body\"><div class=\"chain-item\">Claw2EE v2.1 (8082)</div><div class=\"chain-item\">UTE Engine (8097)</div><div class=\"chain-item\">OmniCode Enterprise (8767)</div><div class=\"chain-item\">Enterprise MCP (8070)</div><div class=\"chain-item\">Dashboard (8888)</div></div></div>"
    "<div class=\"card\"><div class=\"card-header\"><div class=\"card-icon\" style=\"background: linear-gradient(135deg, #fa709a, #fee140);\">LLM Integration</div><div><div>Multi-Provider</div></div></div><div class=\"card-body\"><div class=\"chain-item\">NVIDIA NIM (deepseek-v3.1)</div><div class=\"chain-item\">OpenRouter</div><div class=\"chain-item\">Moonshot AI</div><div class=\"chain-item\">Local Ollama</div></div></div>"
    "<div class=\"card\"><div class=\"card-header\"><div class=\"card-icon\" style=\"background: linear-gradient(135deg, #30cfd0, #330867);\">Services</div><div><div>Active Ports</div></div></div><div class=\"card-body\"><div class=\"chain-item\">Port 80: Enterprise Dashboard</div><div class=\"chain-item\">Port 8082: Claw2EE v2.1</div><div class=\"chain-item\">Port 8888: Main Dashboard</div><div class=\"chain-item\">Port 8767: OmniCode</div><div class=\"chain-item\">Port 8070: Enterprise MCP</div><div class=\"chain-item\">Port 8097: UTE Engine</div></div></div>"
    "</div>"
    "<div class=\"footer\"><p>AIAOS Framework v2.0 | Chicken Scheme " CHICKEN_VERSION " | FreeBSD " FREEBSD_VERSION " | Enterprise Grade</p><p>Last Updated: " (timestamp-now) "</p></div>"
    "</body></html>"))

;; =============================================================================
;; Router
;; =============================================================================
(define (route path)
  (cond
    ((string-prefix? "/api/health" path) (api-health))
    ((string-prefix? "/api/status" path) (api-status))
    ((string-prefix? "/api/tasks" path) (api-status))
    ((string-prefix? "/api/components" path) (api-status))
    ((string-prefix? "/api/metrics" path) (api-status))
    ((string-prefix? "/" path) (dashboard-html))
    (else (http-404))))

;; =============================================================================
;; Timestamp
;; =============================================================================
(define (timestamp-now)
  (run-cmd "date -u +%Y-%m-%dT%H:%M:%SZ"))

;; =============================================================================
;; Request Handler
;; =============================================================================
(define (handle-request request-line)
  (let* ((parts (if (string? request-line) (string-split request-line " ") '()))
         (method (if (> (length parts) 0) (list-ref parts 0) "GET"))
         (url (if (> (length parts) 1) (list-ref parts 1) "/"))
         (clean-url (car (string-split url "?"))))
    (cond
      ((string-prefix? "GET" method)
       (display (route clean-url)))
      (else
       (display (http-404))))))

;; =============================================================================
;; Entry Point
;; =============================================================================
(handle-request (list-ref (command-line-arguments) 1))
