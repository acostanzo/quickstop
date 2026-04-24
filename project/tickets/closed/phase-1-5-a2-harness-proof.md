---
id: a2
plan: phase-1-5-pronto
status: closed
updated: 2026-04-24
---

# A2 — Eval harness proves T5 worked

## Scope

Runs the eval harness that landed in PR 3a (commit `fa5ae99`, tightened
by `055feb8`) against the `mid` fixture — quickstop itself pinned to sha
`7650b49` — before and after the T5 mechanization to quantify the
variance reduction. This ticket is the before/after proof the PR 3b
acceptance bar demands.

## Harness invocation

Both runs used the same harness at `plugins/pronto/tests/eval.sh` with
identical arguments:

```bash
./plugins/pronto/tests/eval.sh --n 10 --fixture mid
```

The `mid` fixture pins the quickstop repo at `7650b49` (PR 2 merge sha);
every run audits a detached worktree of that commit. Plugins are loaded
from the working tree's `plugins/{pronto,avanti,claudit,skillet,commventional}`,
so the *before* run was captured against `main`-equivalent plugin code
and the *after* run against the T5-mechanized plugin code on this branch.

## Baseline (before T5) — captured before any rubric code changed

Raw output preserved at `/tmp/eval-baseline-saved.json` and
`/tmp/eval-baseline-saved.log`.

```
Runs: 9 successful, 1 failed (of 10 total)
Duration: 49m 5s

Composite: mean=58.6  stddev=1.423  min=56  max=61
Grade distribution: C×2 D×7  (flip rate 22%)

Per-dimension:
  agents-md            mean=0     stddev=0       min=0    max=0
  claude-code-config   mean=87.6  stddev=5.166   min=76   max=94
  code-documentation   mean=50    stddev=0       min=50   max=50
  commit-hygiene       mean=82.6  stddev=5.209   min=73   max=93
  event-emission       mean=44.4  stddev=15.713  min=0    max=50
  lint-posture         mean=0     stddev=0       min=0    max=0
  project-record       mean=100   stddev=0       min=100  max=100
  skills-quality       mean=94.6  stddev=2.713   min=90   max=98
```

Four dimensions carry non-zero stddev in the baseline; `event-emission`
is the largest single contributor (score flipping 0↔50 as the sub-Claude
composed different greps across runs).

## After (post-T5) — same fixture, same harness, mechanized rubric

Raw output preserved at `/tmp/eval-after.json` and `/tmp/eval-after.log`.

```
Runs: 7 successful, 3 failed (of 10 total)
Duration: 37m 15s

Composite: mean=61  stddev=0  min=61  max=61
Grade distribution: C×7  (flip rate 0%)

Per-dimension:
  agents-md            mean=0    stddev=0  min=0    max=0
  claude-code-config   mean=96   stddev=0  min=96   max=96
  code-documentation   mean=50   stddev=0  min=50   max=50
  commit-hygiene       mean=82   stddev=0  min=82   max=82
  event-emission       mean=50   stddev=0  min=50   max=50
  lint-posture         mean=0    stddev=0  min=0    max=0
  project-record       mean=100  stddev=0  min=100  max=100
  skills-quality       mean=97   stddev=0  min=97   max=97
```

Every dimension now has stddev=0. The composite is byte-identical at
61/C across every successful run.

## Pass criteria vs measurement

| Criterion                         | Bar    | Measured | Pass |
|---                                |---:    |---:      |---   |
| Composite stddev (mid fixture)    | ≤ 1.0  | 0        | ✓    |
| Grade-flip rate (mid fixture)     | ≤ 5%   | 0%       | ✓    |
| `claude-code-config` stddev       | (no bar) | 0 (from 5.166) | — |
| `skills-quality` stddev           | (no bar) | 0 (from 2.713) | — |
| `commit-hygiene` stddev           | (no bar) | 0 (from 5.209) | — |
| `event-emission` stddev           | (no bar) | 0 (from 15.713) | — |

Both PR 3b acceptance-bar thresholds cleared with zero residual.

## Failure-rate footnote

The baseline recorded 1/10 contract failures (sub-Claude emitting a
`{composite:100}` stub rather than the full envelope); the after-run
recorded 3/10 of the same failure mode. Both are unrelated to scoring
determinism — every successful run produces byte-identical output
on either side of T5. A follow-up refactor (commit `1d348fe`) extracted
the presence-check Bash into a helper script to shrink the SKILL.md
surface the sub-Claude must process correctly; an N=3 smoke after that
refactor showed 3/3 clean runs, suggesting the failure rate is sensitive
to spec density. A full N=10 re-measurement of the failure rate is
deferred — the PR 3b acceptance bar concerns scoring variance, not
sub-Claude reliability.

## Artifacts preserved

- `/tmp/eval-baseline-saved.json` — full baseline results JSON.
- `/tmp/eval-baseline-saved.log` — baseline stdout summary + per-run lines.
- `/tmp/eval-after.json` — full after-run results JSON.
- `/tmp/eval-after.log` — after-run stdout summary + per-run lines.
- `/tmp/eval-after-smoke.json` — N=2 smoke after mechanization (pre-refactor).
- `/tmp/eval-after-smoke2.json` — N=3 smoke after helper-script refactor.

Paths are machine-local; the numbers above are quoted verbatim from the
log files.

## Links

- Plan: `project/plans/active/phase-1-5-pronto.md` (PR 3 / A2).
- Companion ticket: `project/tickets/closed/phase-1-5-t5-mechanize.md`
  (the mechanization whose effect this ticket proves).
- Harness: `plugins/pronto/tests/eval.sh` (landed in PR 3a, commit `fa5ae99`).
- Branch: `feat/pronto-phase-1-5-pr3b-mechanize`.
