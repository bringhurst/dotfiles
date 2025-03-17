;;; Shell script dev config

(require 'dev-common)

;; ======================================================================
;; Shell Mode Configuration
;; ======================================================================

;; Improve shell script mode
(use-package sh-script
  :straight (:type built-in)
  :mode (("\\.sh\\'" . sh-mode)
         ("\\.bash\\'" . sh-mode)
         ("\\.zsh\\'" . sh-mode))
  :hook (sh-mode . (lambda ()
                     ;; Default to bash for shell scripts
                     (sh-set-shell "bash")
                     ;; Start Eglot if bash-language-server is available
                     (when (executable-find "bash-language-server")
                       (eglot-ensure))))
  :config
  ;; Indentation settings
  (setq sh-basic-offset 2
        sh-indentation 2))

;; ======================================================================
;; Shellcheck Integration
;; ======================================================================

;; Use shellcheck for shell scripts
(use-package flymake-shellcheck
  :hook (sh-mode . flymake-shellcheck-load)
  :config
  ;; Only use shellcheck with bash
  (setq flymake-shellcheck-types '("sh" "bash")))

;; Add Eglot language server configuration for Bash
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(sh-mode . ("bash-language-server" "start"))))

;; ======================================================================
;; Shell Script Utilities
;; ======================================================================

(defun shell-check-script ()
  "Run shellcheck on the current script."
  (interactive)
  (let ((filename (buffer-file-name)))
    (compile (format "shellcheck -f gcc %s" (shell-quote-argument filename)))))

(defun shell-run-script ()
  "Run the current shell script."
  (interactive)
  (let ((filename (buffer-file-name)))
    (compile (format "bash %s" (shell-quote-argument filename)))))

(defun shell-make-executable ()
  "Make the current shell script executable."
  (interactive)
  (let ((filename (buffer-file-name)))
    (shell-command (format "chmod +x %s" (shell-quote-argument filename)))
    (revert-buffer nil t)
    (message "Made %s executable" (file-name-nondirectory filename))))

;; Key bindings for Shell script development
(with-eval-after-load 'sh-script
  (define-key sh-mode-map (kbd "C-c p c") 'shell-check-script)
  (define-key sh-mode-map (kbd "C-c p r") 'shell-run-script)
  (define-key sh-mode-map (kbd "C-c p x") 'shell-make-executable))

(provide 'dev-shell)
