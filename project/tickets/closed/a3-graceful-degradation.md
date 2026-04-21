---
id: a3
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# A3 — Graceful degradation

## Scope of this record

Executed the full `skills/audit/SKILL.md` Phase 4 decision tree against A1's
zero-sibling fixture — every presence-fallback branch walked with real
filesystem state: glob for skill files, `git log` on an empty repo, grep
for observability patterns, lint-config file probes, `AGENTS.md` line count,
and subdir-presence for `project/`. The executor asserted that every
dimension lands in one of the four `source` enum values with a defined
human-readable annotation.

## Fixture

`/tmp/pronto-a1-lA8NA` — the A1 fresh-repo fixture. Pronto-init'd kernel
only; no siblings installed; no README; no LICENSE; no commits; no lint config;
no observability code.

## Executed per-dimension behavior

```
  slug                    wt   sc  source                 annotation
  claude-code-config      25   50  kernel-presence-cap    presence-cap (weight 25) — recommended: claudit
  skills-quality          10    0  presence-fail          not configured (weight 10) — recommended: skillet
  commit-hygiene          15    0  presence-fail          not configured (weight 15) — recommended: commventional
  code-documentation      15    0  presence-fail          not configured (weight 15) — recommended: inkwell (Phase 2+)
  lint-posture            15    0  presence-fail          not configured (weight 15) — recommended: lintguini (Phase 2+)
  event-emission           5    0  presence-fail          not configured (weight 5)  — recommended: autopompa (Phase 2+)
  agents-md               10  100  kernel-owned           kernel-owned (weight 10)
  project-record           5   50  kernel-presence-cap    presence-cap (weight 5)  — recommended: avanti (Phase 1b)

  composite_score = 25   grade = F   (Critical)
  Total execution time: 3 ms (budget 5000 ms)
```

## Behavioural assertions (all passed)

- ✓ **No sibling-missing failure is a traceback.** Every branch of the Phase 4
  decision tree has a handler. The executor verified `d is not None` for all 8
  dimensions after `score_dim()`. The empty-repo `git log` exits non-zero with
  stderr noise but returns an empty commit list; presence-check falls through
  cleanly to score 0.
- ✓ **Each non-configured dimension offers a clear next step.** All six
  `presence-fail` / `kernel-presence-cap` non-kernel rows carry a
  `recommended: <plugin>` annotation plus the `(Phase N)` suffix for
  Phase-1b / Phase-2+ siblings. Assertion enforced in the executor.
- ✓ **Kernel presence dimensions still score normally.** `agents-md = 100`
  (AGENTS.md 36 lines ≥ 5); `project-record = 50` (all 4 subdirs present,
  capped because avanti absent); `claude-code-config = 50` (`.claude/`
  present, capped because claudit absent).
- ✓ **Composite score reflects that most dimensions are ungraded.** 25/F.
  Contributions: 12.5 (claude-code-config cap) + 10.0 (agents-md kernel) +
  2.5 (project-record cap) = 25.0. The scorecard does not inflate the grade
  by skipping dimensions.

## Defect-carryover note

A3 re-execution confirmed the zsh `path`-variable bug fixed in A1's record
would, pre-fix, have dropped `agents-md` from 100 → 0 and the composite from
25 → 15. Post-fix (this commit's change to `skills/kernel-check/SKILL.md`),
A3 produces the expected 25/F under zsh.

## Deferred to live environment

- Markdown scorecard render (the executor validated JSON correctness; markdown
  formatting per `references/report-format.md` is purely presentation).
- `/pronto:improve` follow-on AskUserQuestion flow after the audit.

## Decision recorded

Graceful degradation is exercised against the real A1 fixture, not reasoned
about. The executor walked every Phase 4 branch with real filesystem state and
asserted on the output shape. The only defect surfaced — the zsh `path`
collision in kernel-check — is fixed in the same commit that tightens these
records.
