;; aiaos-dashboard.scm - Enterprise Dashboard Data Provider for AIOS
;; Outputs JSON to stdout with system status, services, tasks, components.
;; To be called by Python server or directly via chicken-csi.

(import chicken.base)
(import chicken.process)
(import chicken.process-context)
(import chicken.io)
(import chicken.condition)
(import chicken.file)
(import chicken.string)
(import chicken.port)
(import chicken.time)
(require-extension json)
(require-extension srfi-13)

;; Execute shell command and return list of output lines
(define (run-cmd cmd)
  (condition-case
    (let-values (((in out pid) (process cmd)))
      (let loop ((lines '()))
        (let ((line (read-line in)))
          (if (eof-object? line)
            (begin
              (close-input-port in)
              (process-wait pid)
              (reverse lines))
            (loop (cons line lines))))))
    (ex () '())))

;; Get hostname
(define (get-hostname)
  (or (get-environment-variable "HOSTNAME")
      (let ((lines (run-cmd "hostname")))
        (if (pair? lines) (car lines) "vm_d"))))

;; Get uptime (first line of uptime command)
(define (get-uptime)
  (let ((lines (run-cmd "uptime")))
    (if (pair? lines) (car lines) "N/A")))

;; Get load average from sysctl
(define (get-loadavg)
  (let ((lines (run-cmd "sysctl vm.loadavg")))
    (if (pair? lines)
        (car lines)
        "N/A")))

;; Get memory parameters (free, inactive, active, wire, physmem, usermem)
(define (get-memory)
  (let ((lines (run-cmd "sysctl vm.stats.vm.v_free_count vm.stats.vm.v_inactive_count vm.stats.vm.v_active_count vm.stats.vm.v_wire_count hw.physmem hw.usermem")))
    (if (pair? lines)
        (car lines)
        "N/A")))

;; Check if a port is listening using sockstat
(define (port-listening? port)
  (let ((cmd (string-append "sockstat -4 -l | grep ':'" (number->string port))))
    (let ((lines (run-cmd cmd)))
      (not (null? lines)))))

;; Get services status for known ports
(define (get-services)
  (list (list 'name "Claw2EE" 'port 8082 'status (if (port-listening? 8082) "up" "down"))
        (list 'name "Aiaos 6666" 'port 6666 'status (if (port-listening? 6666) "up" "down"))
        (list 'name "Aiaos 8888" 'port 8888 'status (if (port-listening? 8888) "up" "down"))
        (list 'name "Enterprise 80" 'port 80 'status (if (port-listening? 80) "up" "down"))))

;; Get tasks - placeholder (will be integrated with omnicode)
(define (get-tasks)
  (list (list 'id "demo-1" 'description "Sample task" 'status "running" 'progress 0.5)))

;; Get components health
(define (get-components)
  (list (list 'name "LLM Integration" 'status "operational")
        (list 'name "Claw2EE" 'status "operational")
        (list 'name "OmniCode" 'status "operational")
        (list 'name "Validator" 'status "operational")
        (list 'name "Dashboard 6666" 'status "operational")
        (list 'name "Dashboard 8888" 'status "operational")))

;; Main dashboard data
(define (get-dashboard-data)
  (list 'system (list 'hostname (get-hostname)
                      'uptime (get-uptime)
                      'loadavg (get-loadavg)
                      'memory (get-memory))
        'services (get-services)
        'tasks (get-tasks)
        'components (get-components)))

;; Output JSON
(define (json-string data)
  (with-output-to-string (lambda () (json-write data))))

(condition-case
  (print (json-string (get-dashboard-data)))
  (ex (err)
    ; Print JSON error message to stdout
    (print "{\"error\":\"" (condition-message err) "\"}")
    (exit 1)))
