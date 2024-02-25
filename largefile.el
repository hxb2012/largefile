;;; largefile.el --- 大文件   -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 1985-1987, 1992-2023 Free Software Foundation, Inc.

;; Maintainer: "洪筱冰" <hxb@localhost.localdomain>
;; URL: https://github.com/hxb2012/largefile
;; Version: 0.1

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <http://www.gnu.org/licenses/>.

;; 最初是从files.el里抄来的

;;; Commentary:

;;; Code:

(defgroup largefile nil
  "skip `insert-file-contents' when open large files")

(defcustom largefile-mode-alist nil
  "Alist of file name patterns vs corresponding major mode functions."
  :type '(alist :key-type regexp :value-type function)
  :group 'largefile)

(defun largefile--create-file-buffer (filename mode)
  (let* ((truename (abbreviate-file-name (file-truename filename)))
         (attributes (file-attributes truename))
         (number (file-attribute-file-identifier attributes))
         (buf (create-file-buffer filename))
         error)
    (with-current-buffer buf
      (setq buffer-file-name (expand-file-name filename))
      (set-buffer-multibyte t)
      (condition-case error
          (let ((inhibit-read-only t))
            (insert-file-contents filename nil 0 32))
        (file-error
         (kill-buffer buf)
         (cond
          ((and (file-exists-p filename) (not (file-readable-p filename)))
           (signal 'file-error (list "File is not readable" filename)))
          (t
           (signal 'file-error error)))))
      (set-buffer-modified-p nil)
      (setq buffer-file-truename truename)
      (setq buffer-file-number number)
      (setq default-directory (file-name-directory buffer-file-name))
      (setq-local backup-inhibited t)
      (setq buffer-read-only t)
      (when view-mode
        (view-mode -1))
      (kill-all-local-variables)
      (unless delay-mode-hooks
        (run-hooks 'change-major-mode-after-body-hook
                   'after-change-major-mode-hook))
      (funcall mode)
      (unless (eq mode major-mode)
        (setq set-auto-mode--last (cons mode major-mode)))
      (when delay-mode-hooks
        (with-demoted-errors "File local-variables error: %s"
          (hack-local-variables 'no-mode)))
      (when (and font-lock-mode
             (boundp 'font-lock-keywords)
             (eq (car font-lock-keywords) t))
        (setq font-lock-keywords (cadr font-lock-keywords))
        (font-lock-mode 1))
      (when (not (eq (get major-mode 'mode-class) 'special))
        (view-mode-enter))
      (run-hooks 'find-file-hook)
      (current-buffer))))

(defun largefile--find-file-noselect-a (filename &optional nowarn rawfile wildcards)
  (setq filename (abbreviate-file-name (expand-file-name filename)))
  (unless rawfile
    (when-let ((mode
                (if (file-name-case-insensitive-p filename)
                    (let ((case-fold-search t))
                      (assoc-default filename largefile-mode-alist 'string-match-p))
                  (or
                   (let ((case-fold-search nil))
                     (assoc-default filename largefile-mode-alist 'string-match-p))
                   (and auto-mode-case-fold
                        (let ((case-fold-search t))
                          (assoc-default filename largefile-mode-alist 'string-match-p)))))))
      (if-let ((buf (get-file-buffer filename)))
          (or (buffer-base-buffer buf) buf)
        (largefile--create-file-buffer filename mode)))))

;;;###autoload
(define-minor-mode largefile-mode
  ""
  :group 'largefile
  :global t
  :init-value nil
  (cond
   (largefile-mode
    (advice-add 'find-file-noselect :before-until 'largefile--find-file-noselect-a))
   (t
    (advice-remove 'find-file-noselect 'largefile--find-file-noselect-a))))

(provide 'largefile)
;;; largefile.el ends here
