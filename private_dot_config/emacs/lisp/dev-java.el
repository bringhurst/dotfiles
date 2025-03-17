;;; Java dev config

(require 'dev-common)

;; ======================================================================
;; Java Mode and LSP Support
;; ======================================================================

;; Java mode configuration
(use-package java-mode
  :straight (:type built-in)
  :ensure nil
  :hook (java-mode . eglot-ensure))

;; Configure Eglot for Java
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(java-mode . ("jdtls"
                              "--jvm-arg=-Dfile.encoding=UTF-8"
                              ;; Better Gradle support
                              "--jvm-arg=-Dgradle.offline=true"))))

;; ======================================================================
;; Gradle Support
;; ======================================================================

;; Gradle mode for build.gradle files
(use-package gradle-mode
  :mode ("\\.gradle\\'" . gradle-mode))

;; Groovy mode for Gradle files
(use-package groovy-mode
  :mode (("\\.groovy\\'" . groovy-mode)
         ("\\.gradle\\'" . groovy-mode)))

;; ======================================================================
;; Java Project Commands
;; ======================================================================

(defun gradle-command (command)
  "Run a Gradle COMMAND from the project root."
  (interactive "sGradle command: ")
  (let* ((default-directory (get-project-root))
         (gradle-path (cond ((file-exists-p "gradlew") "./gradlew")
                            ((file-exists-p "gradle.bat") "gradle.bat")
                            (t "gradle"))))
    (compile (concat gradle-path " " command))))

(defun gradle-build ()
  "Build the Gradle project."
  (interactive)
  (gradle-command "build"))

(defun gradle-test ()
  "Run tests in the Gradle project."
  (interactive)
  (gradle-command "test"))

(defun gradle-run ()
  "Run the Gradle project."
  (interactive)
  (gradle-command "run"))

(defun gradle-tasks ()
  "List available Gradle tasks."
  (interactive)
  (gradle-command "tasks"))

(defun maven-command (command)
  "Run a Maven COMMAND from the project root."
  (interactive "sMaven command: ")
  (let* ((default-directory (get-project-root))
         (mvn-path (if (file-exists-p "mvnw") "./mvnw" "mvn")))
    (compile (concat mvn-path " " command))))

(defun detect-java-project-type ()
  "Detect whether the project uses Gradle or Maven."
  (let ((root (get-project-root)))
    (cond ((or (file-exists-p (expand-file-name "build.gradle" root))
               (file-exists-p (expand-file-name "settings.gradle" root)))
           'gradle)
          ((file-exists-p (expand-file-name "pom.xml" root))
           'maven)
          (t nil))))

(defun java-compile ()
  "Compile the Java project based on detected build system."
  (interactive)
  (let ((project-type (detect-java-project-type)))
    (cond ((eq project-type 'gradle)
           (gradle-build))
          ((eq project-type 'maven)
           (maven-command "compile"))
          (t (message "No build system detected")))))

(defun java-test ()
  "Run tests for the Java project."
  (interactive)
  (let ((project-type (detect-java-project-type)))
    (cond ((eq project-type 'gradle)
           (gradle-test))
          ((eq project-type 'maven)
           (maven-command "test"))
          (t (message "No build system detected")))))

(defun java-run ()
  "Run the Java project."
  (interactive)
  (let ((project-type (detect-java-project-type)))
    (cond ((eq project-type 'gradle)
           (gradle-run))
          ((eq project-type 'maven)
           (maven-command "exec:java"))
          (t (message "No build system detected")))))

;; Key bindings for Java development
(with-eval-after-load 'cc-mode
  (define-key java-mode-map (kbd "C-c p c") 'java-compile)
  (define-key java-mode-map (kbd "C-c p t") 'java-test)
  (define-key java-mode-map (kbd "C-c p r") 'java-run))

(provide 'dev-java)
