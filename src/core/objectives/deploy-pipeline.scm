;;; MIT License
;;; Copyright (C) 2025 AIAOS Framework contributors
;;;
;;; deploy-pipeline.scm — Enterprise Product Deploy Pipeline
;;; Handles packaging, versioning, and deployment of products.

(require-extension chicken.io chicken.string chicken.time chicken.process srfi-1 json)
(import chicken.base)

(define DEPLOY-BASE "/home/aiaos/deploy")
(define PRODUCTS-DIR (string-append DEPLOY-BASE "/products"))
(define REPORTS-DIR (string-append DEPLOY-BASE "/reports"))
(define VERSION-FILE (string-append DEPLOY-BASE "/VERSION"))
(define PRODUCT-INDEX (string-append DEPLOY-BASE "/product-index.json"))

;; Version Management
(define (read-version)
  (if (file-exists? VERSION-FILE)
      (string-trim (call-with-input-file VERSION-FILE (lambda (in) (read-string #f in))))
      "0.1.0"))

(define (write-version ver)
  (call-with-output-file VERSION-FILE (lambda (out) (display ver out))))

(define (bump-version ver)
  (let* ((parts (string-split ver "."))
         (major (or (and (pair? parts) (string->number (car parts))) 0))
         (minor (or (and (pair? (cdr parts)) (string->number (cadr parts))) 0))
         (patch (or (and (pair? (cddr parts)) (string->number (caddr parts))) 0)))
    (string-append (number->string major) "." (number->string minor) "." (number->string (+ patch 1)))))

(define (next-version)
  (bump-version (read-version)))

;; Product Packaging
(define (package-product product-id source-files)
  (let ((ver (next-version))
        (target-dir (string-append PRODUCTS-DIR "/" product-id))
        (timestamp (current-seconds)))
    (system (string-append "mkdir -p " target-dir))
    (for-each (lambda (src)
                (let ((base (car (string-split (or (car (string-split src "/")) src) "/"))))
                  (system (string-append "cp " src " " target-dir "/" base))))
              source-files)
    (write-version ver)
    (list (cons 'product-id product-id)
          (cons 'version ver)
          (cons 'timestamp timestamp)
          (cons 'files source-files)
          (cons 'deploy-path target-dir))))

;; Manifest Generation
(define (write-manifest product-id metadata)
  (let ((path (string-append PRODUCTS-DIR "/" product-id ".manifest.json")))
    (call-with-output-file path (lambda (out) (write-json metadata out)))
    path))

(define (update-product-index product-id metadata)
  (let* ((existing (if (file-exists? PRODUCT-INDEX)
                       (call-with-input-file PRODUCT-INDEX (lambda (in) (json-read in)))
                       '()))
         (products (if (vector? existing) (vector->list existing) (if (list? existing) existing '())))
         (updated (cons (list (cons 'product-id product-id) (cons 'metadata metadata)) products)))
    (call-with-output-file PRODUCT-INDEX (lambda (out) (write-json (list->vector updated) out)))))

;; Deployment
(define (deploy-product product-id source-files)
  (let* ((metadata (package-product product-id source-files))
         (manifest-path (write-manifest product-id metadata)))
    (update-product-index product-id metadata)
    (system (string-append "mkdir -p " REPORTS-DIR))
    (let ((report-path (string-append REPORTS-DIR "/" product-id "-deploy.scm")))
      (call-with-output-file report-path
        (lambda (out)
          (display ";;; Deploy Report: " out) (display product-id out) (newline out)
          (display ";;; Version: " out) (display (assoc-ref (car metadata) 'version) out) (newline out)
          (display ";;; Timestamp: " out) (display (assoc-ref (car metadata) 'timestamp) out) (newline out))))
    metadata))

;; Query
(define (list-deployed-products)
  (if (file-exists? PRODUCTS-DIR)
      (glob (string-append PRODUCTS-DIR "/*"))
      '()))

(define (product-exists? product-id)
  (file-exists? (string-append PRODUCTS-DIR "/" product-id)))

(define (deploy-summary)
  (let* ((ver (read-version))
         (products (list-deployed-products)))
    (list (cons 'version ver)
          (cons 'product-count (length products))
          (cons 'deploy-base DEPLOY-BASE))))
