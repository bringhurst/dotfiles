;;; Main init file

;; Set custom file location
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;; Add lisp directory to load path
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; Load configurations
(require 'base)       ;; Package management and basic settings
(require 'ui)         ;; User interface
(require 'dev-common) ;; Common development settings
(require 'dev-cpp)    ;; C++ support
(require 'dev-python) ;; Python support
(require 'dev-java)   ;; Java support
(require 'dev-shell)  ;; Shell/Bash support

;; Load custom file if it exists
(when (file-exists-p custom-file)
  (load custom-file))

;; Reset GC threshold to reasonable value after startup
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 4 1000 1000))  ;; 4MB
            (message "Emacs loaded in %s with %d garbage collections."
                     (format "%.2f seconds"
                             (float-time
                              (time-subtract after-init-time before-init-time)))
                     gcs-done)))
