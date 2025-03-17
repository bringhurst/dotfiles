;;; Python dev config

(require 'dev-common)

;; ======================================================================
;; Python Mode and LSP Support
;; ======================================================================

;; Python mode configuration
(use-package python
  :straight (:type built-in)
  :hook (python-mode . eglot-ensure)
  :config
  ;; Use Python 3 by default
  (setq python-shell-interpreter "python3")
  
  ;; Don't ask about safe local variables
  (setq enable-local-variables :all)
  
  ;; Virtual environment support
  (setq python-shell-virtualenv-root nil))

;; Configure Eglot for Python
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(python-mode . ("pyright-langserver" "--stdio"))))

;; ======================================================================
;; Python Environment Detection
;; ======================================================================

;; Auto-detect and use project virtual environments
(defun detect-python-venv ()
  "Detect and activate Python virtual environment."
  (when-let* ((project-root (get-project-root))
              (venv-path (or
                          ;; poetry venv
                          (when (file-exists-p (expand-file-name "poetry.lock" project-root))
                            (expand-file-name ".venv" project-root))
                          ;; standard venv directory
                          (when (file-exists-p (expand-file-name "venv" project-root))
                            (expand-file-name "venv" project-root))
                          ;; pipenv
                          (when (file-exists-p (expand-file-name "Pipfile" project-root))
                            (string-trim (shell-command-to-string "pipenv --venv"))))))
    (setq-local python-shell-virtualenv-root venv-path)))

(add-hook 'python-mode-hook #'detect-python-venv)

;; ======================================================================
;; Python Project Commands
;; ======================================================================

(defun python-run-current-file ()
  "Run the current Python file."
  (interactive)
  (compile (concat python-shell-interpreter " " (buffer-file-name))))

(defun python-run-tests ()
  "Run Python tests for the current project."
  (interactive)
  (let ((default-directory (get-project-root)))
    (compile (cond
              ;; pytest
              ((file-exists-p (expand-file-name "pytest.ini" default-directory))
               "python -m pytest")
              ;; unittest
              (t "python -m unittest discover")))))

(defun poetry-run-command (cmd)
  "Run a command using Poetry."
  (let ((default-directory (get-project-root)))
    (compile (format "poetry run %s" cmd))))

(defun python-lint ()
  "Run linter on the current project."
  (interactive)
  (let ((default-directory (get-project-root)))
    (compile (cond
              ;; flake8
              ((file-exists-p (expand-file-name ".flake8" default-directory))
               "flake8 .")
              ;; pylint
              ((file-exists-p (expand-file-name ".pylintrc" default-directory))
               "pylint --recursive=y .")
              ;; default
              (t "python -m flake8 .")))))

;; Key bindings for Python development
(with-eval-after-load 'python
  (define-key python-mode-map (kbd "C-c p r") 'python-run-current-file)
  (define-key python-mode-map (kbd "C-c p t") 'python-run-tests)
  (define-key python-mode-map (kbd "C-c p l") 'python-lint))

(provide 'dev-python)
