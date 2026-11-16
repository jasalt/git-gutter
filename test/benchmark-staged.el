;;; benchmark-staged.el --- Reproducible staged benchmarks -*- lexical-binding: t; -*-
(require 'git-gutter)
(require 'benchmark)
(require 'staged-reference)

(dolist (size '(1000 10000))
  (let* ((staged (list (make-git-gutter-hunk :type 'added :start-line 1 :end-line size)))
         (unstaged (cl-loop for line from 10 to size by 100
                            collect (make-git-gutter-hunk
                                     :type 'modified :start-line line :end-line line
                                     :content (format "@@ -%d +%d @@\n-a\n+b\n" line line))))
         (legacy (benchmark-run 3 (git-gutter-test:map-staged-lines staged unstaged)))
         mapped mapping rendering)
    (garbage-collect)
    (setq mapping (benchmark-run 3 (setq mapped (git-gutter:map-staged-hunks staged unstaged))))
    (with-temp-buffer
      (dotimes (_ size) (insert "line\n"))
      (let ((git-gutter:staged-diffinfos mapped))
        (setq rendering
              (benchmark-run 3
                (remove-overlays)
                (git-gutter:view-diff-infos unstaged)))))
    (princ (format "lines=%d unstaged=%d mapped-ranges=%d\n  per-line reference (3 runs): %S\n  mapping (3 runs): %S\n  rendering (3 runs): %S\n"
                   size (length unstaged) (length mapped) legacy mapping rendering))))
