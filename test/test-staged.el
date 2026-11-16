;;; test-staged.el --- Staged sign tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'git-gutter)
(require 'staged-reference)

(defun git-gutter-test:parse (text)
  (with-temp-buffer
    (insert text)
    (git-gutter:process-diff-output (current-buffer))))

(ert-deftest git-gutter-test:map-index-lines ()
  (let ((inserted (git-gutter-test:parse "@@ -2,0 +3,2 @@\n+x\n+y\n"))
        (deleted (git-gutter-test:parse "@@ -2,2 +1,0 @@\n-x\n-y\n"))
        (replaced (git-gutter-test:parse "@@ -2 +2 @@\n-x\n+y\n")))
    (should (= 2 (git-gutter-test:map-index-line 2 inserted)))
    (should (= 5 (git-gutter-test:map-index-line 3 inserted)))
    (should-not (git-gutter-test:map-index-line 2 deleted))
    (should-not (git-gutter-test:map-index-line 3 deleted))
    (should (= 2 (git-gutter-test:map-index-line 4 deleted)))
    (should-not (git-gutter-test:map-index-line 2 replaced))
    (should (= 3 (git-gutter-test:map-index-line 3 replaced)))))

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

(ert-deftest git-gutter:range-mapping-matches-line-reference ()
  (dolist (diff '("@@ -2,0 +3,2 @@\n+x\n+y\n"
                  "@@ -2,2 +1,0 @@\n-x\n-y\n"
                  "@@ -2 +2 @@\n-x\n+y\n"
                  "@@ -2,2 +2 @@\n-a\n-b\n+c\n@@ -8,0 +8,2 @@\n+x\n+y\n"))
    (let ((unstaged (git-gutter-test:parse diff)))
      (dotimes (start 12)
        (dotimes (width 5)
          (let* ((low (1+ start)) (high (+ low width))
                 (staged (list (make-git-gutter-hunk :type 'modified
                                                   :start-line low :end-line high)))
                 (expected (mapcar #'git-gutter-hunk-start-line
                                   (git-gutter-test:map-staged-lines staged unstaged)))
                 (actual (cl-loop for info in (git-gutter:map-staged-hunks staged unstaged)
                                  append (number-sequence (git-gutter-hunk-start-line info)
                                                          (git-gutter-hunk-end-line info)))))
            (should (equal expected actual))))))))

(ert-deftest git-gutter:discard-superseded-staged-query ()
  (with-temp-buffer
    (let ((git-gutter-mode t)
          (git-gutter:show-staged-changes t)
          (git-gutter:vcs-type 'git)
          stale done)
      (git-gutter:collect-staged-changes "missing-file" nil (lambda () (setq stale t)))
      (git-gutter:collect-staged-changes "missing-file" nil (lambda () (setq done t)))
      (let ((deadline (+ (float-time) 5)))
        (while (and (not done) (< (float-time) deadline))
          (accept-process-output nil 0.05)))
      (should done)
      (should-not stale))))

(ert-deftest git-gutter:staged-sign-lightens-background ()
  "Themes such as Modus color signs with a background."
  (let ((spec (get 'git-gutter:added 'face-defface-spec)))
    (unwind-protect
        (progn
          (face-spec-set 'git-gutter:added '((t (:background "#6cc06c"))))
          (let ((face (get-text-property 0 'face (git-gutter:propertized-sign 'added t))))
            (should (stringp (plist-get face :background)))
            (should-not (equal (plist-get face :background) "#6cc06c"))))
      (face-spec-set 'git-gutter:added spec))))
