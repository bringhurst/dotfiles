;;; Package management and basic settings

;; ======================================================================
;; Package Management with straight.el
;; ======================================================================

;; Bootstrap straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Install use-package
(straight-use-package 'use-package)
(setq straight-use-package-by-default t)

;; ======================================================================
;; Essential Settings
;; ======================================================================

;; Use UTF-8 by default
(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)

;; Indentation
(setq-default indent-tabs-mode nil  ;; Use spaces, not tabs
              tab-width 4)          ;; Default tab width

;; Autosave and backups
(setq create-lockfiles nil           ;; No lock files
      make-backup-files nil          ;; No backup files
      auto-save-default nil)         ;; No auto-save files

;; Better editor behavior
(delete-selection-mode t)            ;; Replace selection when typing
(global-auto-revert-mode t)          ;; Auto-refresh buffers
(electric-pair-mode t)               ;; Auto-pair brackets
(show-paren-mode t)                  ;; Highlight matching parentheses
(setq-default cursor-type 'bar)      ;; Use a bar cursor

;; Performance improvements
(setq read-process-output-max (* 1024 1024))  ;; 1MB for process reading

;; ======================================================================
;; Project Management
;; ======================================================================

;; Built-in project.el for project management
(use-package project
  :straight (:type built-in)
  :config
  ;; Custom project detection functions
  (defun project-try-all (dir)
    "Detect project root with common project markers."
    (let ((markers '("CMakeLists.txt" "build.gradle" "pyproject.toml" 
                     "setup.py" "pom.xml" "Makefile" "WORKSPACE")))
      (catch 'found
        (dolist (marker markers)
          (let ((root (locate-dominating-file dir marker)))
            (when root (throw 'found (cons 'transient root))))))))
  
  (add-to-list 'project-find-functions #'project-try-all))

;; ======================================================================
;; Version Control
;; ======================================================================

;; Git integration
(use-package magit
  :bind ("C-x g" . magit-status))

;; ======================================================================
;; Essential packages
;; ======================================================================

;; Better help for keybindings
(use-package which-key
  :config (which-key-mode))

;; Modern completion framework - minimal setup
(use-package vertico
  :init (vertico-mode))

;; Enhanced minibuffer commands
(use-package consult
  :bind (("C-x b" . consult-buffer)        ;; Buffer switching
         ("C-c s" . consult-ripgrep)       ;; Project search
         ("C-c f" . consult-find)))        ;; File finding

;; ======================================================================
;; Keybindings
;; ======================================================================

;; Global keybindings
(global-set-key (kbd "C-c r") (lambda () 
                                (interactive)
                                (load-file 
                                 (expand-file-name "init.el" user-emacs-directory))))

(provide 'base)
