;;; Common dev settings

;; ======================================================================
;; LSP Support with Eglot (built into Emacs 29+)
;; ======================================================================

(use-package eglot
  :commands eglot
  :config
  ;; Increase timeout for large projects
  (setq eglot-connect-timeout 60)
  ;; Don't auto-shutdown language server
  (setq eglot-autoshutdown t)
  ;; Don't highlight current symbol
  (setq eglot-ignored-server-capabilities '(:documentHighlightProvider)))

;; ======================================================================
;; Completion
;; ======================================================================

;; Simple completion UI
(use-package corfu
  :custom
  (corfu-auto t)                ;; Enable auto-completion
  (corfu-auto-prefix 2)         ;; Complete after typing 2 chars
  (corfu-preview-current nil)   ;; Don't preview current selection
  :init
  (global-corfu-mode))

;; ======================================================================
;; Syntax Checking
;; ======================================================================

;; Use Flymake (built-in, used by Eglot)
(use-package flymake
  :straight (:type built-in)
  :hook (prog-mode . flymake-mode)
  :bind
  (("M-n" . flymake-goto-next-error)
   ("M-p" . flymake-goto-prev-error)))

;; ======================================================================
;; Common Development Tools
;; ======================================================================

;; Syntax highlighting for various config files
(use-package yaml-mode
  :mode ("\\.yml\\'" "\\.yaml\\'"))

(use-package json-mode
  :mode "\\.json\\'")

(use-package markdown-mode
  :mode (("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode)))

(use-package toml-mode
  :mode (("\\.toml\\'" . toml-mode)
         ("Cargo\\.lock\\'" . toml-mode)
         ("poetry\\.lock\\'" . toml-mode)
         ("Pipfile\\'" . toml-mode)))

;; Git gutter to show changes in fringe
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (magit-post-refresh . diff-hl-magit-post-refresh)))

;; ======================================================================
;; Compilation settings
;; ======================================================================

;; Improve compilation buffer
(use-package compile
  :straight (:type built-in)
  :config
  (setq compilation-scroll-output t)        ;; Auto-scroll
  (setq compilation-ask-about-save nil))    ;; Save without asking

;; Helper for getting project root
(defun get-project-root ()
  "Get the current project root directory."
  (when-let ((project (project-current)))
    (project-root project)))

(provide 'dev-common)
