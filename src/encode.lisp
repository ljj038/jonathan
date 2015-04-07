(in-package :cl-user)
(defpackage jonathan.encode
  (:use :cl
        :jonathan.util)
  (:import-from :fast-io
                :fast-write-byte
                :make-output-buffer
                :finish-output-buffer)
  (:import-from :trivial-types
                :association-list-p)
  (:export :write-key
           :write-value
           :write-key-value
           :with-object
           :with-array
           :write-item
           :with-output
           :*octets*
           :*from*
           :*stream*
           :to-json
           :%to-json
           :%write-char
           :%write-string))
(in-package :jonathan.encode)

(declaim (optimize (speed 3) (safety 0) (debug 0)))

(defvar *octets* nil)
(defvar *from* nil)
(defvar *stream* nil)

(declaim (inline %write-string))
(defun %write-string (string)
  (declare (type simple-string string))
  (if *octets*
      (loop for c across string
            do (fast-write-byte (char-code c) *stream*))
      (write-string string *stream*))
  nil)

(declaim (inline %write-char))
(defun %write-char (char)
  (if *octets*
      (fast-write-byte (char-code char) *stream*)
      (write-char char *stream*))
  nil)

(declaim (inline string-to-json))
(defun string-to-json (string)
  (declare (type simple-string string))
  (%write-char #\")
  (loop for char across string
        do (case char
             (#\Newline (%write-string "\\n"))
             (#\Return (%write-string "\\r"))
             (#\Tab (%write-string "\\t"))
             (#\" (%write-string "\\\""))
             (#\\ (%write-string "\\\\"))
             (t (%write-char char))))
  (%write-char #\"))

(defmacro with-macro-p (list)
  `(and (consp ,list)
        (member (car ,list) '(with-object with-array))))

(defmacro write-key (key)
  (declare (ignore key)))

(defmacro write-value (value)
  (declare (ignore value)))

(defmacro write-key-value (key value)
  (declare (ignore key value)))

(defmacro with-object (&body body)
  (let ((first (gensym "first")))
    `(let ((,first t))
       (macrolet ((write-key (key)
                    `(progn
                       (if ,',first
                           (setq ,',first nil)
                           (%write-char #\,))
                       (string-to-json (princ-to-string ,key))))
                  (write-value (value)
                    `(progn
                       (%write-char #\:)
                       ,(if (with-macro-p value)
                            value
                            `(%to-json ,value))))
                  (write-key-value (key value)
                    `(progn
                       (write-key ,key)
                       (write-value ,value))))
         (%write-char #\{)
         ,@body
         (%write-char #\})))))

(defmacro write-item (item)
  (declare (ignore item)))

(defmacro with-array (&body body)
  (let ((first (gensym "first")))
    `(let ((,first t))
       (macrolet ((write-item (item)
                    `(progn
                       (if ,',first
                           (setq ,',first nil)
                           (%write-char #\,))
                       ,(if (with-macro-p item)
                            item
                            `(%to-json ,item)))))
         (%write-char #\[)
         ,@body
         (%write-char #\])))))

(defmacro with-output ((stream) &body body)
  `(let ((*stream* ,stream))
     ,@body))

(declaim (inline alist-to-json))
(defun alist-to-json (list)
  (with-object
    (loop for (item rest) on list
          do (write-key-value (car item) (cdr item)))))

(declaim (inline plist-to-json))
(defun plist-to-json (list)
  (with-object
    (loop for (key value) on list by #'cddr
          do (write-key-value key value))))

(declaim (inline list-to-json))
(defun list-to-json (list)
  (with-array
    (loop for item in list
          do (write-item item))))

(defun to-json (obj &key (octets *octets*) (from *from*))
  "Converting object to JSON String."
  (let ((*stream* (if octets
                      (make-output-buffer :output :vector)
                      (make-string-output-stream)))
        (*octets* octets)
        (*from* from))
    (%to-json obj)
    (if octets
        (finish-output-buffer *stream*)
        (get-output-stream-string *stream*))))

(defgeneric %to-json (obj))

(defmethod %to-json ((string string))
  (string-to-json string))

(defmethod %to-json ((number number))
  (%write-string (princ-to-string number)))

(defmethod %to-json ((ratio ratio))
  (%write-string (princ-to-string (coerce ratio 'float))))

(defmethod %to-json ((list list))
  (cond
    ((and (eq *from* :alist)
          (association-list-p list))
     (alist-to-json list))
    ((and (eq *from* :jsown)
          (eq (car list) :obj))
     (alist-to-json (cdr list)))
    ((and (or (eq *from* :plist)
              (null *from*))
          (my-plist-p list))
     (plist-to-json list))
    (t (list-to-json list))))

(defmethod %to-json ((sv simple-vector))
  (with-array
    (loop for item across sv
          do (write-item item))))

(defmethod %to-json ((hash hash-table))
  (with-object
    (loop for key being the hash-key of hash
            using (hash-value value)
          do (write-key-value key value))))

(defmethod %to-json ((symbol symbol))
  (string-to-json (symbol-name symbol)))

(defmethod %to-json ((_ (eql t)))
  (%write-string "true"))

(defmethod %to-json ((_ (eql :false)))
  (%write-string "false"))

(defmethod %to-json ((_ (eql :null)))
  (%write-string "null"))

(defmethod %to-json ((_ (eql nil)))
  (%write-string "[]"))
