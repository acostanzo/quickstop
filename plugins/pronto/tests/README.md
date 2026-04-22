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
```

Defaults:
- `--fixture mid`
- `--n 10`
- `--output plugins/pronto/tests/eval-results.json`

Run from the repo root (or anywhere — the script resolves paths from its
own location).

### Examples

```bash
# Default: 10 runs against the 'mid' fixture
./plugins/pronto/tests/eval.sh

# Smoke test with 2 runs
./plugins/pronto/tests/eval.sh --n 2

# Different fixture, custom output path
./plugins/pronto/tests/eval.sh --fixture mid --n 20 --output /tmp/my-eval.json
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
4. For each run, parses the composite JSON and extracts `composite_score`,
   `composite_grade`, and each `dimensions[].score`.
5. Aggregates across runs:
   - Composite: mean, stddev, min, max
   - Grade distribution: count per letter + flip rate (fraction of runs
     whose grade differs from the mode)
   - Per-dimension: mean, stddev, min, max
6. Emits a human-readable summary to stdout and a structured JSON object
   to the `--output` path.

## Files

| File | Role |
|---|---|
| `eval.sh` | The harness itself |
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
