;;; aiaos-core.scm - AIAOS Framework Core (Chicken Scheme 5.4.0)
;;; Complete L0-L9 layer implementation replacing Python aiaos-core.py
;;; Provides unified execute_instruction interface for EPD-CLC pipeline bridge

(module aiaos-core (
  aiaos-init
  aiaos-all-layers-ready?
  aiaos-get-layer-names
  aiaos-get-layer-statuses
  aiaos-execute-instruction
  aiaos-trigger-runtime
  aiaos-get-overall-status
)
(import chicken.base)
(import chicken.string)
(import chicken.io)
(import chicken.json)
(import chicken.time)
(require-extension json)
(require-extension srfi-1)
(require-extension srfi-69)
(require-extension srfi-18)

;; =============================================================================
;; Layer Modules Loading
;; =============================================================================

;; Dynamic loading of layer modules
(define (load-layer-module layer-num)
  (let ((module-name (string->symbol (string-append "layer" (number->string layer-num)))))
    (eval module-name (current-module))
    (cond
      ((module-defined? module-name) module-name)
      (else #f))))

;; Lazy load all layer modules on init
(define layer-modules '())
(define layer-names
  '((0 "Execute" "layer0")
    (1 "Isolate" "layer1")
    (2 "Calibrate" "layer2")
    (3 "Resilience" "layer3")
    (4 "Persistence" "layer4")
    (5 "Autonomy" "layer5")
    (6 "Healing" "layer6")
    (7 "Scheduling" "layer7")
    (8 "Compatibility" "layer8")
    (9 "Interaction" "layer9")))

;; =============================================================================
;; Timestamp Helpers
;; =============================================================================

(define (timestamp)
  (let* ((now (current-seconds))
         (iso (seconds->string now)))
    iso))

;; =============================================================================
;; Core API Implementation
;; =============================================================================

;; Initialize core and load all layers
(define (aiaos-init)
  (set! layer-modules '())
  (display "[AIAOS] Initializing core (Chicken Scheme)...\n")
  (for-each
    (lambda (layer-info)
      (let* ((num (car layer-info))
             (name (cadr layer-info))
             (modname (caddr layer-info))
             (mod (load-layer-module num)))
        (if mod
            (begin
              (set! layer-modules (acons num mod layer-modules))
              (display (string-append "[AIAOS] Layer " (number->string num) " (" name ") loaded\n"))
              (if (module-bound? mod 'init)
                  ((module-ref mod 'init))))
            (display (string-append "[AIAOS] WARNING: Layer " (number->string num) " module missing\n")))))
    layer-names)
  (display "[AIAOS] Core initialization complete.\n")
  #t)

;; Check if all layers are loaded and operational
(define (aiaos-all-layers-ready?)
  (and (not (null? layer-modules))
       (= (length layer-modules) 10)))

;; Get layer names (for bridge compatibility)
(define (aiaos-get-layer-names)
  (map (lambda (info)
         `((layer . ,(car info))
           (name . ,(cadr info))
           (description . ,(caddr info))))
       layer-names))

;; Get status of all layers
(define (aiaos-get-layer-statuses)
  (map
    (lambda (layer-info)
      (let* ((num (car layer-info))
             (mod (assoc-ref layer-modules num)))
        `((layer . ,num)
          (name . ,(cadr layer-info))
          (status . ,(if mod
                         (if (module-bound? mod 'check-status)
                             (assq-ref (module-ref mod 'check-status) 'status)
                             "unknown")
                         "missing"))
          (operational . ,(if mod #t #f)))))
    layer-names))

;; -----------------------------------------------------------------------------
;; Execution Engine - sequential layer processing (as in Python version)
;; -----------------------------------------------------------------------------

;; Execute instruction through full 10-layer pipeline.
;; instruction: alist with task data (id, type, etc.)
;; Returns: alist with layer outputs (layer0, layer1, ... layer9)
(define (aiaos-execute-instruction instruction)
  (let ((instruction-id (or (assq-ref instruction 'id) "unknown"))
        (instruction-type (or (assq-ref instruction 'type) "generic")))
    
    (display (string-append "[AIAOS] execute_instruction: " instruction-id " type=" instruction-type "\n"))
    
    ;; L0: Execute - executes the raw task
    (let* ((l0 (assoc-ref layer-modules 0))
           (l0-result (if l0 (module-ref l0 'process-tasks `(,instruction)) '())))
      
      ;; L1: Isolate - apply isolation to L0 results
      (let* ((l1 (assoc-ref layer-modules 1))
             (l1-input l0-result)
             (l1-result (if l1 (module-ref l1 'process-tasks l1-input) '())))
        
        ;; L2: Calibrate
        (let* ((l2 (assoc-ref layer-modules 2))
               (l2-input l1-result)
               (l2-result (if l2 (module-ref l2 'process-tasks l2-input) '())))
          
          (let loop ((layer-num 3) (prev-result l2-result) (layer-outputs `((layer0 . ,l0-result) (layer1 . ,l1-result) (layer2 . ,l2-result))))
            (if (>= layer-num 10)
                (begin
                  (display "[AIAOS] Pipeline complete.\n")
                  layer-outputs)
                (let* ((layer (assoc-ref layer-modules layer-num))
                       (result (if layer (module-ref layer 'process-tasks prev-result) '())))
                  (loop (+ layer-num 1) result (acons (string->symbol (string-append "layer" (number->string layer-num))) result layer-outputs))))))))))

;; Trigger runtime - simply wraps execute_instruction
(define (aiaos-trigger-runtime task)
  (aiaos-execute-instruction task))

;; Get overall framework status
(define (aiaos-get-overall-status)
  (let ((statuses (aiaos-get-layer-statuses)))
    `((framework . "aiaos")
      (implementation . "Chicken Scheme 5.4.0")
      (layers . 10)
      (operational . ,(aiaos-all-layers-ready?))
      (timestamp . ,(timestamp))
      (layers-status . ,statuses)))

;; =============================================================================
;; Self-test / Bootstrap
;; =============================================================================

(define (self-test)
  (display "=== AIAOS Core Self-Test ===\n")
  (aiaos-init)
  (if (aiaos-all-layers-ready?)
      (begin
        (display "All layers loaded.\n")
        (let ((sample-task `((id . "test-001") (type . "demo") (complexity . 0.6) (entropy . 0.4))))
          (let ((result (aiaos-execute-instruction sample-task)))
            (display "Execution result: ") (display result) (newline)
            #t)))
      (begin
        (display "ERROR: Not all layers loaded.\n")
        #f)))

;; Auto-run self-test on load (optional)
;(self-test)

) ;; end module aiaos-core

;; =============================================================================
;; Module Export
;; =============================================================================

(export aiaos-init
        aiaos-all-layers-ready?
        aiaos-get-layer-names
        aiaos-get-layer-statuses
        aiaos-execute-instruction
        aiaos-trigger-runtime
        aiaos-get-overall-status)

;; EOF
