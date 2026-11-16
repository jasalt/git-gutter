;;; test-staged.el --- Staged sign tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'git-gutter)

(defun git-gutter-test:parse (text)
  (with-temp-buffer
    (insert text)
    (git-gutter:process-diff-output (current-buffer))))

(ert-deftest git-gutter:map-index-lines ()
  (let ((inserted (git-gutter-test:parse "@@ -2,0 +3,2 @@\n+x\n+y\n"))
        (deleted (git-gutter-test:parse "@@ -2,2 +1,0 @@\n-x\n-y\n"))
        (replaced (git-gutter-test:parse "@@ -2 +2 @@\n-x\n+y\n")))
    (should (= 2 (git-gutter:map-index-line 2 inserted)))
    (should (= 5 (git-gutter:map-index-line 3 inserted)))
    (should-not (git-gutter:map-index-line 2 deleted))
    (should-not (git-gutter:map-index-line 3 deleted))
    (should (= 2 (git-gutter:map-index-line 4 deleted)))
    (should-not (git-gutter:map-index-line 2 replaced))
    (should (= 3 (git-gutter:map-index-line 3 replaced)))))

(ert-deftest git-gutter:staged-rendering ()
  (with-temp-buffer
    (insert "one\ntwo\nthree\n")
    (let ((git-gutter:staged-diffinfos
           (list (make-git-gutter-hunk :type 'added :start-line 2 :end-line 2))))
      (git-gutter:view-diff-infos nil)
      (let* ((overlay (car (overlays-in (point-min) (point-max))))
             (display (get-text-property 0 'display (overlay-get overlay 'before-string)))
             (face (get-text-property 0 'face (cadr display))))
        (should overlay)
        (should (or (eq face 'git-gutter:staged-added)
                    (eq (plist-get face :inherit) 'git-gutter:staged-added))))
      (should-not git-gutter:diffinfos))))

(ert-deftest git-gutter:staged-integration ()
  (let ((directory (make-temp-file "git-gutter-staged-" t)))
    (unwind-protect
        (let ((default-directory (file-name-as-directory directory)))
          (cl-labels ((git (&rest args)
                       (should (zerop (apply #'process-file "git" nil nil nil args))))
                      (write-file-text (text)
                        (with-temp-file "sample" (insert text))))
            (git "init" "-q")
            (write-file-text "one\ntwo\nthree\nfour\n")
            (git "add" "sample")
            (git "-c" "user.name=Test" "-c" "user.email=test@example.com"
                 "commit" "-qm" "Initial")
            (write-file-text "one\nTWO\nthree\nfour\n")
            (git "add" "sample")
            (write-file-text "new\none\nTWO\nthree\nfour\n")
            (with-temp-buffer
              (insert-file-contents "sample")
              (let ((git-gutter-mode t)
                    (git-gutter:show-staged-changes t)
                    (git-gutter:vcs-type 'git)
                    (diffinfos (git-gutter-test:parse "@@ -0,0 +1 @@\n+new\n"))
                    done)
                (git-gutter:collect-staged-changes "sample" diffinfos
                                                 (lambda () (setq done t)))
                (let ((deadline (+ (float-time) 5)))
                  (while (and (not done) (< (float-time) deadline))
                    (accept-process-output nil 0.05)))
                (should done)
                (should (= 1 (length git-gutter:staged-diffinfos)))
                (should (= 3 (git-gutter-hunk-start-line
                              (car git-gutter:staged-diffinfos))))))))
      (delete-directory directory t))))
