;;; -*- mode:lisp; package:coffee-mode -*-

;; coffee-mode.l - CoffeeScript�p���W���[���[�h for xyzzy

(defpackage "coffee-mode"
  (:nicknames "coffee")
  (:use :lisp :editor))

(in-package "coffee")
(export '(*command-path* *compiled-buffer-mode* *keymap* *repl-keymap*
	  *tab-width* *hook*))

(defvar *command-path* nil
  "��: 'C:/path/to/node.exe C:/path/to/coffee/bin/coffee'")

(defvar *compiled-buffer-mode* nil
  "�R���p�C�����ʃo�b�t�@�p major mode")

(defparameter *keymap* nil
  "coffee-mode�p �L�[�}�b�v")

(defparameter *repl-keymap* nil
  "coffee-repl�p �L�[�}�b�v")

(defvar *tab-width* 2)
(defvar *hook* nil)

(defvar *output-buffer-name* "*coffee-output*")
(defvar *repl-buffer-name* "*coffee-repl*")

(defvar *keyword-file* "CoffeeScript")
(defvar *keyword-table* nil)
(defun load-keyword ()
  (or *keyword-table*
      (setq *keyword-table*
	    (load-keyword-file *keyword-file*))))

(defparameter *keyword-regexps*
  (compile-regexp-keyword-list
   '(("@[a-zA-Z0-9_]+"      t (:keyword 1))
     ("->"                  t (:keyword 0) nil)
     )))

(defparameter *function-regexp*
  (concat
   "\\( *class +[A-Za-z_$][0-9A-Za-z_.$]*\\(?: +extends +.+\\)?\\)"
   "\\|\\(^ *[@A-Za-z_$][0-9A-Za-z_.$]* *[:=] *(.+) *->\\)"
   ))

(unless *keymap*
  (setq *keymap* (make-sparse-keymap))
  (define-key *keymap* #\RET 'smart-newline)
  (define-key *keymap* #\TAB 'indent-or-dabbreb-expand)
  (define-key *keymap* '(#\C-c #\s) 'compile-file-to-js)
  (define-key *keymap* '(#\C-c #\i) 'repl)
  (define-key *keymap* '(#\C-c #\c) 'compile-buffer)
  (define-key *keymap* '(#\C-c #\C-c) 'compile-region)
  (define-key *keymap* '(#\C-c #\r) 'evaluate-buffer)
  (define-key *keymap* '(#\C-c #\C-r) 'evaluate-region)
  (define-key *keymap* '(#\C-c #\C-x #\r) 'evaluate-buffer-in-repl)
  (define-key *keymap* '(#\C-c #\C-x #\C-r) 'evaluate-region-in-repl)
  (define-key *keymap* '(#\C-c #\l) 'ed:list-function)
  )

(unless *repl-keymap*
  (setq *repl-keymap* (copy-keymap ed:*shell-mode-map*))
  (define-key *repl-keymap* #\LFD 'smart-newline)
  (define-key *repl-keymap* #\TAB 'indent-or-dabbreb-expand)
  (define-key *repl-keymap* '(#\C-c #\C-z) 'quit-repl))

(defvar *syntax-table* nil)
(unless *syntax-table*
  (setq *syntax-table* (make-syntax-table))
  (set-syntax-string *syntax-table* #\")
  (set-syntax-string *syntax-table* #\')
  (set-syntax-string *syntax-table* #\`)
  (set-syntax-escape *syntax-table* #\\)
  (set-syntax-symbol *syntax-table* #\_)
  (set-syntax-symbol-prefix *syntax-table* #\$)
  (set-syntax-match *syntax-table* #\( #\))
  (set-syntax-match *syntax-table* #\{ #\})
  (set-syntax-match *syntax-table* #\[ #\])
  (set-syntax-start-comment *syntax-table* #\# t)
  (set-syntax-end-comment *syntax-table* #\LFD nil t)
  (set-syntax-start-multi-comment *syntax-table* "/*")
  (set-syntax-end-multi-comment *syntax-table* "*/"))


;;; compile, eval
(defun compile-region (from to)
  (interactive "r")
  (let ((src (buffer-substring from to)))
    (send-string src "bcp" t)))

(defun compile-buffer ()
  (interactive)
  (compile-region (point-min) (point-max)))

(defun evaluate-region (from to)
  (interactive "r")
  (let ((src (buffer-substring from to)))
    (send-string src "bcp")))

(defun evaluate-buffer ()
  (interactive)
  (evaluate-region (point-min) (point-max)))

(defun ast-region (from to)
  (interactive "r")
  (let ((src (buffer-substring from to)))
    (send-string src "ajp" t)))

(defun ast-buffer ()
  (interactive)
  (ast-region (point-min) (point-max)))

(defun send-string (str opt &optional set-mode)
  (unless *command-path*
    (error "*command-path* ��ݒ肵�Ă�������"))
  (let* ((infile #0=(make-temp-file-name))
	 (outfile #0#)
	 (cmd (format nil "~A -~A \"~A\"" *command-path* opt infile)))
    (with-open-file (os infile :direction :output) (princ str os))
    (unwind-protect
	(prog1
	    (multiple-value-bind (cmdline dir)
		(ed::shell-command-line cmd (default-directory))
	      (call-process cmdline
			    :output outfile
			    :exec-directory dir
			    :show :minimize
			    :wait t))
	  (let ((buf (get-buffer-create *output-buffer-name*)))
	    (erase-buffer buf)
	    (pop-to-buffer buf t)
	    (if (and set-mode *compiled-buffer-mode*)
		(funcall *compiled-buffer-mode*)
	      (fundamental-mode))
	    (insert-file-contents outfile)
	    (setup-temp-buffer buf)
	    (set-buffer-modified-p nil buf)))
      (delete-file infile)
      (delete-file outfile))))


;;; compile file
(defun compile-file-to-js (&optional bear)
  (interactive "P" :default0 t :title0 "bear: ")
  (unless *command-path*
    (error "*command-path* ��ݒ肵�Ă�������"))
  (when (need-buffer-save-p (selected-buffer))
    (case (message-box "�ۑ����܂���?" "�ۑ��m�F" '(:question :yes-no-cancel))
      (:cancel (return-from compile-file-to-js nil))
      (:yes (call-interactively 'save-buffer))
      (:no t)))
  (let ((fn (get-buffer-file-name)))
    (when fn
      (let ((jsfn (substitute-string fn (concat (pathname-type fn) "$") ".js"))
	    (proc (make-process (format nil "~A -c \"~A\"" *command-path* fn)
				:output (get-buffer-create *output-buffer-name*))))
	(while (eq (process-status proc) :run)
	  (sleep-for 0.1))
	(when (file-exist-p jsfn)
	  (find-file-other-window jsfn))))))


;; repl
(defun repl ()
  (interactive)
  (run-repl *repl-buffer-name*))

(defun run-repl (bufname &optional (opt ""))
  (unless *command-path*
    (error "*command-path* ��ݒ肵�Ă�������"))
  (let ((buf (get-buffer-create bufname)))
    (pop-to-buffer buf t)
    (let ((proc (buffer-process buf)))
      (when (and proc (eq (process-status proc) :run))
	(return-from run-repl (values buf proc))))
    (goto-char (point-max))
    (let ((*eshell* "coffee"))
      (ed::shell-mode))
    (use-keymap *repl-keymap*)
    (make-local-variable 'highlight-keyword)
    (make-local-variable 'keyword-hash-table)
    (setq highlight-keyword t
	  keyword-hash-table (load-keyword))
    (values buf
	    (make-process (format nil "~A -~Ai" *command-path* opt)
			  :output buf
			  :environ '(("NODE_DISABLE_COLORS" . "1"))))))

(defun evaluate-region-in-repl (from to)
  (interactive "r")
  (send-string-to-repl (buffer-substring from to)))

(defun evaluate-buffer-in-repl ()
  (interactive)
  (evaluate-region-in-repl (point-min) (point-max)))

(defun send-string-to-repl (str)
  (let ((buf (find-buffer *repl-buffer-name*))
	proc)
    (if buf
	(setq proc (buffer-process buf))
      (multiple-value-setq (buf proc) (repl)))
    (process-send-string proc str)
    (let ((w (selected-window)))
      (pop-to-buffer buf t)
      (end-of-buffer)
      (recenter 1)
      (set-window w))))

(defun quit-repl ()
  (interactive)
  (let* ((buf (selected-buffer))
	 (proc (buffer-process buf)))
    (kill-process proc)
    (while (eq (process-status proc) :run)
      (sleep-for 0.1))
    (kill-buffer buf)))


;;; edit
(defun summary-of-functions ()
  (let ((fns nil))
    (save-excursion
      (beginning-of-buffer)
      (while (scan-buffer *function-regexp* :regexp t :no-dup t :tail t)
	(push (list (current-line-number) (match-string 0)) fns)))
    (nreverse fns)))

(defun point-at-bol ()
  (save-excursion
    (goto-bol)
    (point)))

(defun indent-or-dabbreb-expand ()
  (interactive)
  (if (= (point-at-bol)
	 (save-excursion
	   (skip-chars-backward " \t")
	   (point)))
      (indent-line)
    (dabbrev-expand)))


;;; from emacs/lisp/simple.el
(defun forward-to-indentation (&optional arg)
  (interactive "p")
  (forward-line (or arg 1))
  (skip-chars-forward " \t"))

(defun backward-to-indentation (&optional arg)
  (interactive "p")
  (forward-line (- (or arg 1)))
  (skip-chars-forward " \t"))

(defun current-indentation ()
  (save-excursion
    (goto-bol)
    (skip-chars-forward " \t")
    (current-column)))

(defun insert-tab ()
  (insert (make-sequence 'string *tab-width* :initial-element #\SPC)))


;;; from coffee-mode.el
;;
;; Indentation
;;
(defun indent-line ()
  "Indent current line as CoffeeScript."
  (interactive)

  (if (= (point) (point-at-bol))
      (insert-tab)
    (save-excursion
      (let ((prev-indent 0) (cur-indent 0))
	;; Figure out the indentation of the previous line
	(setq prev-indent (previous-indent))

	;; Figure out the current line's indentation
	(setq cur-indent (current-indentation))

	;; Shift one column to the left
	(beginning-of-line)
	(insert-tab)

	;(debug "point: %s" (point))
	;(debug "point-at-bol: %s" (point-at-bol))

	(when (= (point-at-bol) (point))
	  (forward-char *tab-width*))

	;(debug "New indent: %s" (current-indentation))

	;; We're too far, remove all indentation.
	(when (> (- (current-indentation) prev-indent) *tab-width*)
	  (backward-to-indentation 0)
	  (delete-region (point-at-bol) (point)))))))

(defun previous-indent ()
  "Return the indentation level of the previous non-blank line."

  (save-excursion
    (forward-line -1)
    (if (bobp)
        0
      (progn
        (while (and (line-empty-p) (not (bobp))) (forward-line -1))
        (current-indentation)))))

(defun line-empty-p ()
  "Is this line empty? Returns non-nil if so, nil if not."
  (or (bobp)
      (save-excursion
	(goto-bol)
	(looking-at "^\\[ \t\\]*$"))))

(defun smart-newline ()
  "Inserts a newline and indents it to the same level as the previous line."
  (interactive)

  ;; Remember the current line indentation level,
  ;; insert a newline, and indent the newline to the same
  ;; level as the previous line.
  (let ((prev-indent (current-indentation)) (indent-next nil))
    (delete-horizontal-spaces)
    (newline-and-indent)

    ;; We need to insert an additional tab because the last line was special.
    (when (line-wants-indent)
      (insert-tab)))

  ;; Last line was a comment so this one should probably be,
  ;; too. Makes it easy to write multi-line comments (like the one I'm
  ;; writing right now).
  (when (previous-line-is-comment)
    (insert "# ")))


;; Indenters help determine whether the current line should be
;; indented further based on the content of the previous line. If a
;; line starts with `class', for instance, you're probably going to
;; want to indent the next line.

(defparameter indenters-bol-regexp
  #.(format nil "~{~A~^\\|~}"
	    '("class" "for" "if" "else" "try" "case")))

(defparameter indenters-eol '("->" "{" "["))

(defun line-wants-indent ()
  "Does the current line want to be indented deeper than the previous
line? Returns `t' or `nil'. See the README for more details."
  (interactive)

  (save-excursion
    (let ((indenter-at-bol) (indenter-at-eol))
      ;; Go back a line and to the first character.
      (forward-line -1)
      (backward-to-indentation 0)

      ;; If the next few characters match one of our magic indenter
      ;; keywords, we want to indent the line we were on originally.
      (when (looking-at indenters-bol-regexp)
	(setq indenter-at-bol t))

      ;; If that didn't match, go to the back of the line and check to
      ;; see if the last character matches one of our indenter
      ;; characters.
      (when (not indenter-at-bol)
	(end-of-line)

	(when (some #'(lambda (e) (looking-back e)) indenters-eol)
	  (setq indenter-at-eol t)))

      ;; If we found an indenter, return `t'.
      (or indenter-at-bol indenter-at-eol))))

(defun previous-line-is-comment ()
  "Returns `t' if the previous line is a CoffeeScript comment."
  (save-excursion
    (forward-line -1)
    (line-is-comment)))

(defun line-is-comment ()
  "Returns `t' if the current line is a CoffeeScript comment."
  (save-excursion
    (backward-to-indentation 0)
    (eq (char-after (point)) #\#)))


;;; mode definition
(in-package "editor")
(defun coffee-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "coffee"
	buffer-mode 'coffee-mode
	comment-start "#"
	comment-end "")
  (use-syntax-table coffee::*syntax-table*)
  (use-keymap coffee::*keymap*)
  (make-local-variable 'keyword-hash-table)
  (setq keyword-hash-table (coffee::load-keyword))
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list coffee::*keyword-regexps*)
  (make-local-variable 'build-summary-function)
  (setq build-summary-function #'coffee::summary-of-functions)
  (ed::set-buffer-local 'indent-tabs-mode nil)
  (make-local-variable '*post-command-hook*)
  (run-hooks 'coffee::*hook*))

(export '(coffee-mode))

(provide "coffee-mode")