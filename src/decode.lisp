(in-package :cl-user)
(defpackage jonathan.decode
  (:use :cl
        :jonathan.util
        :proc-parse)
  (:export :parse))
(in-package :jonathan.decode)

(defun parse (string &key (as :plist))
  (with-string-parsing (string)
    (macrolet ((skip-spaces ()
                 `(skip* #\Space))
               (skip?-with-spaces (char)
                 `(progn
                    (skip-spaces)
                    (skip? ,char)
                    (skip-spaces)))
               (skip?-or-eof (char)
                 `(or (skip? ,char) (eofp))))
      (labels ((dispatch ()
                 (skip-spaces)
                 (match-case
                  ("{" (read-object))
                  ("\"" (read-string))
                  ("[" (read-array))
                  (otherwise (read-number))))
               (read-object ()
                 (skip-spaces)
                 (loop until (skip?-or-eof #\})
                       for first = t
                       for key = (progn (advance*) (read-string))
                       for value = (progn (skip-spaces) (advance*) (skip-spaces) (dispatch))
                       do (skip?-with-spaces #\,)
                       when (and first (eq as :jsown))
                         collecting (progn (setq first nil) :obj)
                       if (or (eq as :alist) (eq as :jsown))
                         collecting (cons key value)
                       else
                         nconc (list (make-keyword key) value)))
               (read-string ()
                 (with-output-to-string (stream)
                   (loop until (skip?-or-eof #\")
                         do (write-char
                             (the standard-char
                                  (match-case
                                   ("\\b" #\Backspace)
                                   ("\\f" #\Newline)
                                   ("\\n" #\Newline)
                                   ("\\r" #\Return)
                                   ("\\t" #\Tab)
                                   (otherwise (prog1 (current) (advance*)))))
                             stream))))
               (read-array ()
                 (skip-spaces)
                 (loop until (skip?-or-eof #\])
                       collect (prog1 (dispatch)
                                 (skip?-with-spaces #\,))))
               (read-number (&optional rest-p)
                 (let ((start (the fixnum (pos))))
                   (bind (num-str (skip-while integer-char-p))
                     (let ((num (the fixnum (or (parse-integer num-str :junk-allowed t) 0))))
                       (cond
                         (rest-p
                          (the rational (/ num (the fixnum (expt 10 (- (pos) start))))))
                         ((skip? #\.)
                          (the rational (+ num (the rational (read-number t)))))
                         (t (the fixnum num))))))))
        (skip-spaces)
        (return-from parse (dispatch))))))
