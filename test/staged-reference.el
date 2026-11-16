;;; staged-reference.el --- Reference staged mapper -*- lexical-binding: t; -*-
(require 'git-gutter)

(defun git-gutter-test:map-index-line (line diffinfos)
  "Reference per-line mapper: index LINE through DIFFINFOS, or nil if replaced."
  (let ((offset 0) replaced)
    (dolist (info diffinfos)
      (let ((header (git-gutter-hunk-content info)))
        (when (string-match git-gutter:hunk-header-regexp header)
          (cl-flet ((num (n) (if (match-string n header)
                                 (string-to-number (match-string n header))
                               1)))
            (let ((start (num 1)) (old (num 2)) (new (num 3)))
              (cond ((and (> old 0) (>= line start) (< line (+ start old)))
                     (setq replaced t))
                    ((if (zerop old) (> line start) (>= line (+ start old)))
                     (setq offset (+ offset (- new old))))))))))
    (unless replaced (max 1 (+ line offset)))))

(defun git-gutter-test:map-staged-lines (staged unstaged)
  "Reference mapper returning one single-line hunk per visible STAGED line."
  (cl-loop for info in staged append
           (cl-loop for line from (git-gutter-hunk-start-line info)
                    to (git-gutter-hunk-end-line info)
                    for mapped = (git-gutter-test:map-index-line line unstaged)
                    when (and mapped (git-gutter:unchanged-line-p mapped unstaged))
                    collect (make-git-gutter-hunk :type (git-gutter-hunk-type info)
                                                 :start-line mapped :end-line mapped))))

(provide 'staged-reference)
