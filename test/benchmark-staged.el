;;; benchmark-staged.el --- Reproducible staged benchmarks -*- lexical-binding: t; -*-
(require 'git-gutter)
(require 'benchmark)

(defun git-gutter-bench:legacy-map (staged unstaged)
  (cl-loop for info in staged append
           (cl-loop for line from (git-gutter-hunk-start-line info)
                    to (git-gutter-hunk-end-line info)
                    for mapped = (git-gutter:map-index-line line unstaged)
                    when (and mapped (git-gutter:unchanged-line-p mapped unstaged))
                    collect (make-git-gutter-hunk :type (git-gutter-hunk-type info)
                                                 :start-line mapped :end-line mapped))))

(dolist (size '(1000 10000))
  (let* ((staged (list (make-git-gutter-hunk :type 'added :start-line 1 :end-line size)))
         (unstaged (cl-loop for line from 10 to size by 100
                            collect (make-git-gutter-hunk
                                     :type 'modified :start-line line :end-line line
                                     :content (format "@@ -%d +%d @@\n-a\n+b\n" line line))))
         (mapper (if (fboundp 'git-gutter:map-staged-hunks)
                     #'git-gutter:map-staged-hunks #'git-gutter-bench:legacy-map))
         mapped mapping rendering)
    (garbage-collect)
    (setq mapping (benchmark-run 3 (setq mapped (funcall mapper staged unstaged))))
    (with-temp-buffer
      (dotimes (_ size) (insert "line\n"))
      (let ((git-gutter:staged-diffinfos mapped))
        (setq rendering
              (benchmark-run 3
                (remove-overlays)
                (git-gutter:view-diff-infos unstaged)))))
    (princ (format "lines=%d unstaged=%d mapped-ranges=%d\n  mapping (3 runs): %S\n  rendering (3 runs): %S\n"
                   size (length unstaged) (length mapped) mapping rendering))))
