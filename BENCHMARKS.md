# Staged indicator benchmark

Run from the fork root:

```sh
emacs --batch -Q -L . -L test -l test/benchmark-staged.el
```

Measured locally with interpreted Elisp in fresh batch Emacs processes. Each
measurement is three iterations; table values are totals divided by three.
Each fixture has a staged addition covering the file and one unstaged
single-line replacement every 100 lines. Rendering creates real overlays in a
temporary buffer. GC is included. These are synthetic CPU benchmarks, not
interactive redisplay, subprocess, filesystem, or TRAMP latency measurements.

| Lines / unstaged hunks | Operation | Before per run | After per run |
| --- | --- | --- | --- |
| 1,000 / 10 | Mapping | 23.75 ms | 0.44 ms |
| 1,000 / 10 | Rendering | 11.09 ms | 1.33 ms |
| 10,000 / 100 | Mapping | 2,149.25 ms | 0.49 ms |
| 10,000 / 100 | Rendering | 113.57 ms | 22.33 ms |

The larger fixture allocates 101 mapped ranges instead of 9,900 single-line
hunks. Three mapping iterations went from 82 garbage collections to zero.

Changes:

- Parse unstaged headers once into unchanged index intervals with offsets.
- Remove occupied worktree lines, then intersect staged ranges with intervals.
- Cache each staged sign/color once per rendering pass; theme changes remain
  visible on the next refresh.
- Cancel superseded staged queries; only the current process may publish results.
- Cancel staged queries when their source buffer is killed or mode is disabled.

Remaining costs: one additional asynchronous Git process per refresh, one
margin overlay per displayed line, and normal redisplay. No staged-diff cache is
used, avoiding index invalidation issues after external staging. The test-only
per-line mapper in `test/staged-reference.el` is the correctness reference.
The table records the original before/after run; its reference timing is not
comparable because the reference now runs as interpreted test code.
