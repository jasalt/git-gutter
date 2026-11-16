# Staged change indicators

Enable `(setq git-gutter:show-staged-changes t)` to show index changes alongside
unstaged changes. This is disabled by default and only applies to Git with no
custom start revision.

Staged signs use the normal signs, faded halfway toward the editor background.
Both foreground and background colors are faded, since some themes (such as
Modus) color signs by background. Faces inherit from `git-gutter:staged-added`, `git-gutter:staged-modified`, and
`git-gutter:staged-deleted`. Colors are resolved at rendering time so theme
changes are respected on refresh.

The staged diff is read asynchronously using `git diff --cached`. Its index line
numbers are translated through unstaged changes before rendering. Unstaged
changes take precedence on overlapping lines. Staged changes are display-only:
navigation, staging, reverting, marking, and popups still use unstaged hunks.

Run tests with:

```sh
emacs --batch -Q -L . -L test -l test/test-git-gutter.el -l test/test-staged.el \
  -f ert-run-tests-batch-and-exit
```
