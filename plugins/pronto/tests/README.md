# Pronto eval harness

A determinism measurement harness for `/pronto:audit --json`. Runs the audit
N times against a pinned fixture and reports variance statistics.

## Purpose

`/pronto:audit` currently produces non-deterministic composites across runs
on the same commit (see `project/plans/active/phase-1-5-pronto.md`, finding
N3). This harness is the measurement layer that quantifies that variance,
so Phase 1.5 PR 3b can cite a trustworthy before/after stddev when it
mechanizes the rubric's scoreable dimensions.

**The harness reports numbers. It does not enforce pass/fail thresholds.**
Threshold gates ("composite stddev ≤ 1.0", "grade-flip rate ≤ 5%") are
PR 3b's concern.

## Usage

```bash
./plugins/pronto/tests/eval.sh [--fixture <name>] [--n <int>] [--output <path>]
                               [--model <name>] [--preserve-runs <dir>]
```

Defaults:
- `--fixture mid`
- `--n 10`
- `--output plugins/pronto/tests/eval-results.json`
- `--model sonnet` (override via `EVAL_MODEL`)
- `--preserve-runs` unset — per-run artefacts go to a mktemp dir that's
  deleted on exit. Override via `EVAL_PRESERVE_RUNS`.

Run from the repo root (or anywhere — the script resolves paths from its
own location).

### Why pin the model?

Without a pin, every run uses whatever the `claude` CLI's current default
model is. A silent default-model bump between baseline and verification
runs would confound any failure-rate comparison — a real fix could fail
the bar because the model regressed underneath, or a no-op fix could
pass because the model improved. Pinning to an alias (`sonnet` follows
the current Sonnet generation) keeps measurements comparable; pin to a
dated snapshot (e.g. `claude-sonnet-4-6`) for stricter reproducibility
across longer windows.

### Examples

```bash
# Default: 10 runs against the 'mid' fixture, model=sonnet
./plugins/pronto/tests/eval.sh

# Smoke test with 2 runs
./plugins/pronto/tests/eval.sh --n 2

# Different fixture, custom output path
./plugins/pronto/tests/eval.sh --fixture mid --n 20 --output /tmp/my-eval.json

# Preserve per-run artefacts (stdout, stderr, meta.json, normalized JSON)
# for post-hoc failure analysis
./plugins/pronto/tests/eval.sh --n 30 --preserve-runs /tmp/h2a-pilot

# Pin a specific model snapshot
./plugins/pronto/tests/eval.sh --model claude-sonnet-4-6 --n 10
```

### Exit codes

| Code | Meaning |
|---|---|
| 0 | All runs completed; results written |
| 2 | Fixture lookup or worktree setup failed (nothing ran) |
| 3 | One or more audit invocations failed (partial results still written) |
| 4 | jq or aggregation step failed |

Exit 0 means the harness ran cleanly, **not** that variance is within any
particular bound.

## How it works

1. Reads the fixture entry from `fixtures.json` (repo path + pinned sha +
   description).
2. Creates a detached `git worktree` of the fixture repo at the pinned sha
   under `/tmp/pronto-eval-fixture-<name>-<pid>`. A trap cleans this up on
   exit (including on Ctrl-C and failures).
3. Runs `/pronto:audit --json` N times with `cwd` set to the fixture
   worktree, loading plugins from the *harness-invoking* repo's
   `plugins/{pronto,avanti,claudit,skillet,commventional}/`. This means
   the fixture is audited by the *current* pronto code, not by pronto at
   the fixture's sha.
4. For each run, captures stdout/stderr to disk, classifies the outcome
   (success or one of the failure buckets below), and writes a per-run
   `meta.json`. Successful runs are normalized into a single
   `composite/grade/dimensions` shape for aggregation.
5. Aggregates across runs:
   - Composite: mean, stddev, min, max
   - Grade distribution: count per letter + flip rate (fraction of runs
     whose grade differs from the mode)
   - Per-dimension: mean, stddev, min, max
   - Failures by category: count of failing runs by classification bucket
6. Emits a human-readable summary to stdout and a structured JSON object
   to the `--output` path.

## Failure classification

Each failed run is classified into one of these buckets by
`eval-categorize.sh`:

| Category | Meaning |
|---|---|
| `prose-contamination` | stdout contains valid JSON wrapped in prose (chat preamble, postamble, or both) |
| `partial-emission`    | stdout has unbalanced braces — JSON truncated mid-stream (timeout/abort) |
| `refusal-or-empty`    | stdout is empty, whitespace-only, or contains a refusal/apology with no JSON |
| `contract-violation`  | stdout parses as JSON but pronto's contract is not met (composite missing, dimensions partial, stub emission) |
| `exit-nonzero`        | the `claude` CLI itself exited non-zero |
| `other`               | none of the above (structurally malformed JSON, multiple blocks, etc) |

The category, sub-reason, and bounded evidence excerpts (head/tail of
stdout, tail of stderr) land in the run's `meta.json` under `failure`,
and the harness's `eval-results.json` carries a top-level
`failures_by_category` aggregate.

The categorize helper is also runnable standalone for post-hoc
classification of a preserved run directory:

```bash
./plugins/pronto/tests/eval-categorize.sh \
  --stdout run-7.stdout --stderr run-7.stderr --exit-code 0
```

## Per-run artefacts

When `--preserve-runs <dir>` is set (or `EVAL_PRESERVE_RUNS=<dir>` is
exported), each run leaves the following files in that directory:

| File | Role |
|---|---|
| `run-N.stdout` | Full captured stdout from the audit invocation |
| `run-N.stderr` | Full captured stderr |
| `run-N.normalized.json` | Single-line `{composite, grade, dimensions}` extract — present only on success |
| `run-N.meta.json` | Per-run record: `{run, model, exit_code, duration_seconds, outcome, stdout_path, stderr_path, ...}`. Failures carry `failure: {category, sub_reason, evidence}`; successes carry `composite, grade` |
| `all.json` | Combined array of normalized successes |
| `aggregates.json` | jq-derived statistics |
| `failures_by_category.json` | Counts per failure category |

Without `--preserve-runs`, all of the above land in a `mktemp` directory
that's deleted on exit (matches the original harness behaviour); only
the `--output` `eval-results.json` survives.

## Files

| File | Role |
|---|---|
| `eval.sh` | The harness itself |
| `eval-categorize.sh` | Failure-classification helper (called by eval.sh, also runnable standalone) |
| `eval-categorize.test.sh` | Tests for the categorize helper — synthetic stdout/stderr fixtures covering each bucket |
| `fixtures.json` | Fixture registry (repo + pinned sha + description) |
| `README.md` | This file |
| `.gitignore` | Ignores per-run output (`eval-results.json`, `eval-run-*.log`) |
| `eval-results.json` | Written by each run; **git-ignored** |

## Fixtures

The registry lives in `fixtures.json`. Each entry pins a repo and sha so
the harness measures variance against a *frozen snapshot*, not a moving
target. Changing a pinned sha is a deliberate act.

Phase 1.5 PR 3a ships with one fixture:

| Name | Repo | Sha | Purpose |
|---|---|---|---|
| `mid` | `.` (quickstop itself) | `7650b49` (PR 2 merge) | Known mid-grade baseline (~C composite) |

Additional fixtures (`ideal`, `empty`) are out of scope for PR 3a and may
land later.

## Cost

Each run invokes `claude -p "/pronto:audit --json"`, which spawns a
sub-Claude session that dispatches parser agents for each rubric
dimension. At `--n 10`, a full run uses roughly 10 sub-Claude invocations
and takes several minutes. Run on demand only — this is not wired into CI.

## Pairing with PR 3b

PR 3a ships the harness. PR 3b mechanizes the scoreable rubric dimensions
and cites this harness's output as its before/after proof. The N=10
baseline captured in PR 3a's PR body is the "before" number.

## Pairing with Phase 2 PR H2

PR H2a re-uses this harness with the new instrumentation (model pin,
preserved artefacts, per-run categorization, `failures_by_category`
aggregate) to diagnose the dominant `/pronto:audit` failure mode. PR H2b
then remediates that mode, and the harness re-runs to verify ≥95%
JSON-emission success over N=20.
