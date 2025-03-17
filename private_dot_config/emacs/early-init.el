;;; Early initialization

;; Increase garbage collection threshold during startup
(setq gc-cons-threshold (* 64 1000 1000))  ;; 64MB

;; Disable package.el at startup (we use straight.el)
(setq package-enable-at-startup nil)

;; Remove UI elements early to avoid flickering
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; Disable startup screen
(setq inhibit-startup-message t)
