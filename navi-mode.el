;; * navi-mode.el --- major-mode for easy buffer-navigation
;; ** Copyright

;; Copyright (C) 2013 Thorsten Jolitz

;; Maintainer: Thorsten Jolitz <tjolitz AT gmail DOT com>
;; Version: 0.9
;; Keywords: occur

;; ** Licence

;; This file is not part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;; ** Commentary

;; This file implements extensions for occur-mode.
;;
;; ** Installation
;;
;; ** Usage
;;
;; ** Compatibility:

;; * Requires

(require 'outshine)

;; * Mode Definitions

(define-derived-mode navi-mode
  occur-mode "Navi"
  "Major mode for easy buffer-navigation.
In this mode (derived from `occur-mode') you can easily navigate
in an associated original-buffer via one-key commands in the
navi-buffer. You can alter the displayed document structure in
the navi-buffer by sending one-key commands that execute
predefined occur searches in the original buffer. `navi-mode' is
especially useful in buffers with outline structure, e.g. buffers
with `outline-minor-mode' activated and `outshine' extensions
loaded.
\\{navi-mode-map}"
  (set (make-local-variable 'revert-buffer-function) 'navi-revert-function)
  (setq case-fold-search nil))
 
;; * Variables
;; ** Consts
;; ** Vars

(defvar navi-mode-version 0.9
  "Version number of `navi-mode.el'")

(defvar navi "navi"
  "Symbol that holds pairs of buffer-marker names in its plist.
Keys are buffernames as keyword-symbols, values are markers that
point to original-buffers")

;; ** Hooks
;; ** Fonts
;; ** Customs
;; *** Custom Groups 
;; *** Custom Vars
;; * Defuns
;; ** Functions

;; (defun navi-mode-hook-function ()
;;   "Function to be run after `navi-mode' is loaded."
;;   (add-to-list 'occur-hook 'occur-rename-buffer))

(defun navi-make-buffer-key (&optional buf)
  "Return the (current) buffer-name or string BUF as interned keyword-symbol"
  (let ((buf-name
         (file-name-sans-extension
          (car (split-string (or buf (buffer-name)) "[*]" 'OMIT-NULLS)))))
  (intern (concat ":" buf-name))))

(defun navi-make-marker-name (&optional buf)
  "Return marker-name by expansion of (current) buffer-name or string BUF."
  (let ((buf-name
         (file-name-sans-extension
          (car (split-string (or buf (buffer-name)) "[*]" 'OMIT-NULLS)))))
  (concat buf-name "-marker")))

(defun navi-get-twin-buffer-markers ()
  "Return list with two markers pointing to buffer-twins or nil.
CAR of the return-list is always the marker pointing to
 current-buffer, CDR the marker pointing to its twin-buffer."
  (let* ((curr-buf-split
          (split-string (buffer-name) "[*:]" 'OMIT-NULLS))
         (is-navi-buffer-p
          (string-equal (car curr-buf-split) "Navi"))
         (twin-of-navi
          (and is-navi-buffer-p
               (get 'navi (navi-make-buffer-key (cadr curr-buf-split)))))
         (self-navi
          (and is-navi-buffer-p
               (get 'navi (navi-make-buffer-key
                           (concat
                            (car curr-buf-split)
                            ":"
                            (cadr curr-buf-split))))))
         (twin-of-orig
          (unless is-navi-buffer-p
            (get 'navi (navi-make-buffer-key
                        (concat "Navi:" (car curr-buf-split))))))
         (self-orig
          (unless is-navi-buffer-p
            (get 'navi (navi-make-buffer-key (car curr-buf-split))))))
    (if is-navi-buffer-p
        (and self-navi twin-of-navi
             (list self-navi twin-of-navi))
      (and self-orig twin-of-orig
           (list self-orig twin-of-orig)))))


;; modified `occur-rename-buffer' from `replace.el'
(defun navi-rename-buffer (&optional unique-p)
  "Rename the current *Occur* buffer to *Navi: original-buffer-name*.
Here `original-buffer-name' is the buffer name where Occur was
originally run. When given the prefix argument, the renaming will
not clobber the existing buffer(s) of that name, but use
`generate-new-buffer-name' instead. You can add this to
`occur-hook' if you always want a separate *Occur* buffer for
each buffer where you invoke `occur'."
  (let ((orig-buffer-name ""))
    (with-current-buffer
        (if (eq major-mode 'occur-mode) (current-buffer) (get-buffer "*Occur*"))
      (setq orig-buffer-name
            (mapconcat
             #'buffer-name
             (car (cddr occur-revert-arguments)) "/"))
      (rename-buffer (concat "*Navi:" orig-buffer-name "*") unique-p)
      ;; make marker for this navi-buffer
      ;; and store it in `navi''s plist
      (put 'navi
           (navi-make-buffer-key)
           (set
            (intern
             (navi-make-marker-name
              (cadr (split-string (buffer-name) "[*:]" 'OMIT-NULLS))))
            (point-marker))))))

(defun navi-show-headers (level &optional NO-PARENT-LEVELS)
  "Show headers of original-buffer up to outline-level LEVEL in navi-buffer.
If NO-PARENT-LEVELS in non-nil, only headers of level LEVEL are shown."
  (let* ((outline-base-string
          (outshine-transform-normalized-outline-regexp-base-to-string))
         (rgxp-string (regexp-quote
                       (outshine-chomp
                       (format
                        "%s" (car (rassoc 1 outline-promotion-headings))))))
        (rgxp (if (not (and level
                          (integer-or-marker-p level)
                          (>= level 1)
                          (<= level 8)))
                     (error "Level must be an integer between 1 and 8")
                   (if NO-PARENT-LEVELS
                       (format
                        "%s" (car (rassoc level outline-promotion-headings)))
                     (concat
                      (dotimes (i (1- level) rgxp-string)
                       (setq rgxp-string
                             (concat rgxp-string
                                     (regexp-quote
                                      outline-base-string)
                                     "?")))
                                     " ")))))
    (message "%s" rgxp)))

(defun navi-clean-up ()
  "Clean up `navi' plist and left-over markers after killing navi-buffer."
  (setq navi-revert-arguments nil))



;; (add-to-list 'occur-hook 'navi-rename-buffer)

;; ** Commands

;; Convenience function copied from whom ??
(defun isearch-occur ()
  "Invoke `occur' from within isearch."
  (interactive)
  (let ((case-fold-search isearch-case-fold-search))
    (occur (if isearch-regexp isearch-string (regexp-quote isearch-string)))))

(defun navi-search-and-switch ()
  "Call `occur' and immediatley switch to `*Navi:original-buffer-name*' buffer"
  (interactive)
  (let ((1st-level-headers
         (regexp-quote
          (outshine-calc-outline-string-at-level 1))))
    (put 'navi (navi-make-buffer-key (buffer-name))
         (set (intern (navi-make-marker-name)) (point-marker)))
    (occur 1st-level-headers)
    (navi-rename-buffer)
    (navi-switch-to-twin-buffer)
    (navi-mode)))

;; (defun navi-quit-and-switch ()
;;   "Quit navi-buffer and immediatley switch back to original-buffer"
;;   (interactive)
;;   (quit-window)
;;   (switch-to-buffer
;;    (marker-buffer original-buffer-marker))
;;   (goto-char
;;    (marker-position original-buffer-marker)) ; necessary?
;;   (set-marker navi-buffer-marker nil)
;;   (set-marker original-buffer-marker nil))

(defun navi-switch-to-twin-buffer ()
  "Switch to associated twin-buffer of current buffer or do nothing."
  (interactive)
  (let* ((marker-list (navi-get-twin-buffer-markers))
         (self-marker (car marker-list))
         (twin-marker (cadr marker-list)))
    (and marker-list
         (move-marker self-marker (point) (marker-buffer self-marker))
         (switch-to-buffer-other-window (marker-buffer twin-marker))
         (goto-char (marker-position twin-marker)))))

;; adapted from 'replace.el'
(defun navi-revert-function (&optional regexp)
  "Handle `revert-buffer' for navi-buffers."
  (interactive)
  (let ((navi-revert-arguments
         (if regexp
            (append
             (list regexp)
             (cdr occur-revert-arguments))
           occur-revert-arguments)))
  (apply 'occur-1 (append navi-revert-arguments (list (buffer-name))))
  (navi-mode)))

;; too much...
;; (defun navi-revert-function (&optional regexp nlines bufs)
;;   "Handle `revert-buffer' for navi-buffers."
;;   (interactive)
;;   (let ((args (if (and regexp bufs)
;;                   (append regexp nlines bufs
;;                           (list (buffer-name)))
;;                 (append occur-revert-arguments
;;                         (list (buffer-name))))))
;;  (apply 'occur-1 args)))

;; TODO use occur-1 (and occur-revert-function) to update navi-buffer

(defun navi-show-headers-level-1 (args)
  "Show headers (up-to) level 1."
  (interactive "p"))

;; * Keybindings

;; example keybinding
;; (define-key navi-mode-map
;;  [down-mouse-3] 'do-hyper-link)


;; Occur mode: new/better keybindings
(global-set-key (kbd "M-s n") 'navi-search-and-switch)
(global-set-key (kbd "M-s s") 'navi-switch-to-twin-buffer)
(global-set-key (kbd "M-s M-s") 'navi-switch-to-twin-buffer) 
(define-key navi-mode-map (kbd "s") 'navi-switch-to-twin-buffer)
(define-key navi-mode-map (kbd "d") 'occur-mode-display-occurrence)
(define-key navi-mode-map (kbd "n") 'occur-next)
(define-key navi-mode-map (kbd "p") 'occur-prev)
(define-key navi-mode-map (kbd "r") 'navi-revert-function)
(define-key navi-mode-map (kbd "q") 'navi-quit-and-switch)
(define-key isearch-mode-map (kbd "M-s i") 'isearch-occur)

;; * Run Hooks and Provide

(provide 'navi-mode)

;; navi-mode.el ends here

