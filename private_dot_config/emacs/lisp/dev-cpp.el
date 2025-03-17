;;; C++ dev config

(require 'dev-common)

;; ======================================================================
;; C++ Mode and LSP Support
;; ======================================================================

;; Use modern C++ mode
(use-package cc-mode
  :straight (:type built-in)
  :hook ((c-mode c++-mode) . (lambda ()
                               ;; Use C++17 by default
                               (setq-local flycheck-clang-language-standard "c++17")
                               ;; Auto-start LSP
                               (eglot-ensure))))

;; Configure Eglot for C++
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((c++-mode c-mode) . ("clangd"
                                      "--header-insertion=never"
                                      "--completion-style=detailed"
                                      "--clang-tidy"))))

;; ======================================================================
;; CMake Support
;; ======================================================================

;; CMake mode for syntax highlighting
(use-package cmake-mode
  :mode ("CMakeLists\\.txt\\'" "\\.cmake\\'"))

;; Ninja mode for syntax highlighting
(use-package ninja-mode
  :mode "\\.ninja\\'")

;; ======================================================================
;; Build Commands
;; ======================================================================

(defun cmake-configure ()
  "Configure CMake project with compile_commands.json."
  (interactive)
  (let* ((default-directory (get-project-root))
         (build-dir (expand-file-name "build" default-directory))
         (compile-commands (expand-file-name "compile_commands.json" default-directory)))
    ;; Create build directory if needed
    (unless (file-exists-p build-dir)
      (make-directory build-dir t))
    ;; Run CMake configuration
    (compile (format "cd %s && cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Debug .." 
                     (shell-quote-argument build-dir)))
    ;; Create symlink to compile_commands.json
    (when (and (file-exists-p (expand-file-name "compile_commands.json" build-dir))
               (not (file-exists-p compile-commands)))
      (make-symbolic-link "build/compile_commands.json" compile-commands))))

(defun cmake-build ()
  "Build the CMake project."
  (interactive)
  (let ((default-directory (get-project-root)))
    (compile "cd build && cmake --build .")))

(defun cmake-test ()
  "Run tests in the CMake project."
  (interactive)
  (let ((default-directory (get-project-root)))
    (compile "cd build && ctest --output-on-failure")))

;; Key bindings for C++ development
(with-eval-after-load 'cc-mode
  (define-key c++-mode-map (kbd "C-c p c") 'cmake-configure)
  (define-key c++-mode-map (kbd "C-c p b") 'cmake-build)
  (define-key c++-mode-map (kbd "C-c p t") 'cmake-test))

(provide 'dev-cpp)
