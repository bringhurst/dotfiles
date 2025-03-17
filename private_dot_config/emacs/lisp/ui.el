;;; UI config

;; ======================================================================
;; Theme and Visual Settings
;; ======================================================================

;; A clean, modern theme
(use-package doom-themes
  :config
  (load-theme 'doom-one t))

;; Better mode line
(use-package doom-modeline
  :init (doom-modeline-mode 1))

;; Display line numbers in programming modes
(add-hook 'prog-mode-hook 'display-line-numbers-mode)

;; Highlight current line
(global-hl-line-mode t)

;; Font settings (uncomment and adjust if needed)
;; (when (find-font (font-spec :name "JetBrains Mono"))
;;   (set-face-attribute 'default nil :font "JetBrains Mono" :height 120))

;; ======================================================================
;; Icons (optional but useful for file types)
;; ======================================================================

(use-package all-the-icons
  :if (display-graphic-p))

(provide 'ui)
