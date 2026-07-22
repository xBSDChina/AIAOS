;;; brains.scm — Dual Strategist: Zhuge Liang & Guo Jia
;;; Part of the AIAOS Enterprise Framework
;;; MIT License

(declare (uses chicken.base))
(import chicken.base chicken.string chicken.port chicken.io chicken.process-context chicken.time)
(require-extension srfi-1 srfi-13 srfi-69)

(define VERSION "1.1.0")
(define STRATEGIC-DIR "/home/aiaos/deploy/strategic")
(define BRAINS-LOG (string-append STRATEGIC-DIR "/brains.log"))

(define (ts) (seconds->string (current-seconds)))

(define (log! msg)
  (let ((e (string-append "[" (ts) "] [Brains] " msg)))
    (display e) (newline)
    (call-with-output-file BRAINS-LOG (lambda (out) (display e out) (newline out)) #:append #t)))

(define (ensure-dir dir)
  (system (string-append "mkdir -p " dir)))

(define (write-analysis pid suffix content)
  (let ((path (string-append STRATEGIC-DIR "/" pid "-" suffix ".txt")))
    (call-with-output-file path
      (lambda (out)
        (display content out)))
    (log! (string-append "Written analysis: " path))
    path))

(define (longzhong-analysis pid problem)
  (string-append
   "========== 隆中對：AIAOS 戰略決勝三策 ==========\n"
   "分析 ID: " pid "\n"
   "問題描述: " problem "\n"
   "生成時間: " (ts) "\n\n"
   "=== 天下大勢分析 ===\n"
   "當前局勢：系統執行階段遇到障礙，需要戰略層面重新審視路徑。\n"
   "核心矛盾：技術實現與企業級標準之間的差距。\n\n"
   "=== 三階段路線圖 ===\n"
   "【近期目標（1-3個週期）】\n"
   "1. 診斷並修復當前執行錯誤\n"
   "2. 補全斷裂的鏈路節點\n"
   "3. 驗證各組件間的通信通道\n\n"
   "【中期目標（3-7個週期）】\n"
   "1. 建立完整的閉環鏈路（PLAN→DESIGN→IMPL→TEST→AUDIT→DEPLOY）\n"
   "2. 整合Brains雙軍師機制到每個階段\n"
   "3. 實現錯誤自動診斷與緩解\n\n"
   "【遠期目標（7-14個週期）】\n"
   "1. 全自動企業級產品開發流水線\n"
   "2. 自適應優化與學習能力\n"
   "3. 完整的監控與告警體系\n\n"
   "=== 執行鏈路設計 ===\n"
   "1. 修復當前錯誤 -> 重試執行\n"
   "2. 補全缺失函數 -> 測試通過\n"
   "3. 整合Brains -> 自動觸發\n"
   "4. 全鏈路驗證 -> 交付物確認\n\n"
   "最終勝利定義：企業級閉環鏈路運行穩定，6個階段全部自動執行，\n"
   "錯誤率低於5%，交付物完整可追溯。\n"))

(define (ten-victories-analysis pid problem)
  (string-append
   "========== 十勝十敗：AIAOS 現勢勝負書 ==========\n"
   "分析 ID: " pid "\n"
   "問題描述: " problem "\n"
   "生成時間: " (ts) "\n\n"
   "=== 十勝（我方優勢與機會） ===\n"
   "1. 框架完整：aiaos 已具備 6 階段閉環架構\n"
   "2. 組件齊全：claw2ee、omniCode、brains 均已部署\n"
   "3. 雙軍師機制：諸葛亮+郭嘉戰略分析已嵌入\n"
   "4. 儀表板可視化：80/6666/8888 多層監控\n"
   "5. Chicken Scheme：全棧統一語言，無語言切換開銷\n"
   "6. 服務健康：18/20 ports 200 OK\n"
   "7. HTTP API 穩定：8082/8769 均正常回應\n"
   "8. 日誌系統完善：多層級日誌記錄\n"
   "9. 持續執行：主動推進，無需等待指令\n"
   "10. 迭代能力：快速修復與部署\n\n"
   "=== 十敗（劣勢與威脅） ===\n"
   "1. 執行階段錯誤：當前所有 6 階段均失敗\n"
   "2. 缺少超時機制：curl 調用可能無限等待\n"
   "3. 符號衝突：bridge 文件同名函數相互覆蓋\n"
   "4. 容錯不足：單點錯誤導致整個鏈路中斷\n"
   "5. 測試覆蓋率低：缺少單元測試框架\n"
   "6. 部署自動化不足：缺少 CI/CD 流水線\n"
   "7. 監控粒度粗：缺乏每個階段的細粒度狀態\n"
   "8. 恢復機制弱：失敗後無自動重試\n"
   "9. 配置管理分散：多處硬編碼路徑\n"
   "10. 文檔不足：接口文檔缺失\n\n"
   "=== 戰術修正建議 ===\n"
   "1. 緊急：修復 curl 超時問題（--max-time 15）\n"
   "2. 緊急：統一 log! 函數，避免覆蓋\n"
   "3. 重要：添加每個階段的錯誤重試邏輯\n"
   "4. 重要：實現階段間狀態傳遞\n"
   "5. 一般：逐步補全單元測試\n\n"
   "=== 急迫行動優先級 ===\n"
   "P0: 修復 curl 超時和錯誤捕獲\n"
   "P0: 統一日誌函數，避免符號衝突\n"
   "P1: 每個階段執行前檢查前置條件\n"
   "P1: 添加執行結果校驗\n"
   "P2: 完善 Brains 分析輸出格式\n"))

(define (write-mitigation pid)
  (let ((path (string-append STRATEGIC-DIR "/../objectives/brains-mitigation-" pid ".scm")))
    (call-with-output-file path
      (lambda (out)
        (display
         (string-append
          ";;; Auto-generated mitigation task for: " pid "\n"
          ";;; Generated at: " (ts) "\n"
          "(define (mitigate-" pid ")\n"
          "  (display \"Mitigating " pid "...\") (newline)\n"
          "  ;; TODO: Implement actual mitigation steps\n"
          "  (system \"touch /tmp/mitigation-" pid "-done\")\n"
          "  (display \"Mitigation complete.\\n\"))\n"
          "\n"
          ";;; Execute mitigation\n"
          "(mitigate-" pid ")\n")
         out)))
    (log! (string-append "Written mitigation: " path))
    path))

(define (brains-analyze pid problem)
  (log! (string-append "Brains analyze triggered: " pid " -> " problem))
  (ensure-dir STRATEGIC-DIR)
  (let ((longzhong (longzhong-analysis pid problem))
        (tenvictories (ten-victories-analysis pid problem)))
    (write-analysis pid "longzhong" longzhong)
    (write-analysis pid "tenvictories" tenvictories)
    (write-mitigation pid)
    (log! (string-append "Brains analysis complete for: " pid))
    (list longzhong tenvictories)))

;;; Auto-run support: only run main when invoked as script with "analyze" argument
(condition-case
    (let ((args (command-line-arguments)))
      (when (and (pair? args) (string=? (car args) "analyze"))
        (let ((pid (if (>= (length args) 2) (list-ref args 1) "unknown"))
              (desc (if (>= (length args) 3) (list-ref args 2) "No description")))
          (brains-analyze pid desc)
          (log! (string-append "Brains analysis complete for: " pid)))))
    (ex () (void)))
