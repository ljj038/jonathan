(in-package :cl-user)
(defpackage jonathan.util
  (:use :cl)
  (:export :my-plist-p
           :integer-char-p
           :make-keyword
           :comma-p
           :comma-expr
           :*quasiquote*))
(in-package :jonathan.util)

(eval-when (:compile-toplevel :load-toplevel :execute)
  #+sbcl
  (when (and (find-package :sb-impl)
             (find-symbol "COMMA-P" :sb-impl)
             (find-symbol "COMMA-EXPR") :sb-impl)
    (push :sb-impl-comma *features*)))

(defun my-plist-p (list)
  (typecase list
    (null t)
    (cons (loop for (key val next) on list by #'cddr
                if (not (keywordp key))
                  return nil
                else
                  unless next return t))))

(declaim (inline integer-char-p))
(defun integer-char-p (char)
  (or (char<= #\0 char #\9)
      (char= char #\-)))

(defun make-keyword (str)
  (intern str #.(find-package :keyword)))

(defun comma-p (comma)
  #+sb-impl-comma
  (sb-impl::comma-p comma)
  #-sb-impl-comma
  (error "Not supported."))

(defun comma-expr (comma)
  #+sb-impl-comma
  (sb-impl::comma-expr comma)
  #-sb-impl-comma
  nil)

(defvar *quasiquote*
  #+sb-impl-comma
  'sb-int:quasiquote
  #-sb-impl-comma
  nil)
