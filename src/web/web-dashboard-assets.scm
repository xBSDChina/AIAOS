;; web-dashboard-assets.scm - Minimal asset container
;; This file provides placeholder functions for missing dashboard assets.
;; It allows the dashboard to start even without full HTML/CSS assets generated.

(module web-dashboard-assets (get-dashboard-html get-static-assets)
(import chicken.base)
(import chicken.io)

(define (get-dashboard-html)
  ;; Return a minimal HTML page
  (let ((html "<!DOCTYPE html>
<html>
<head>
  <title>AIAOS Dashboard</title>
  <style>body { font-family: monospace; margin: 20px; }</style>
</head>
<body>
  <h1>AIAOS Dashboard</h1>
  <p>Dashboard is running. Use the API endpoints for data.</p>
  <ul>
    <li><a href=\"/api/status\">/api/status</a></li>
    <li><a href=\"/api/functions\">/api/functions</a></li>
    <li><a href=\"/api/tasks\">/api/tasks</a></li>
    <li><a href=\"/api/components\">/api/components</a></li>
    <li><a href=\"/api/metrics\">/api/metrics</a></li>
  </ul>
</body>
</html>"))
    html))

(define (get-static-assets path)
  ;; Return #f for any static file
  #f)

(export get-dashboard-html get-static-assets)
) ;; end module
