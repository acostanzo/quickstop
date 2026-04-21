---
id: a3
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# A3 — Graceful degradation

## Scope of this record

Dry-run validation of the zero-siblings path. Live acceptance is deferred to Alfred's review environment; this record verifies the logic for a pronto-init'd repo with no sibling plugins installed produces a coherent scorecard with no tracebacks and a clear next step per dimension.

## Fixture

Same as A1's fixture: a pronto-init'd bare repo with zero additional content. No siblings installed.

## Expected per-dimension behavior

| Dimension | W | Score | Source | Expected report annotation |
|---|---|---|---|---|
| claude-code-config | 25 | 50 | kernel-presence-cap | `⊘ presence-cap (weight 25) — recommended: claudit` |
| skills-quality | 10 | 0 | presence-fail | `× not configured (weight 10) — recommended: skillet` |
| commit-hygiene | 15 | 0 | presence-fail | `× not configured (weight 15) — recommended: commventional` |
| code-documentation | 15 | 0 | presence-fail | `× not configured (weight 15) — recommended: inkwell (Phase 2+)` |
| lint-posture | 15 | 0 | presence-fail | `× not configured (weight 15) — recommended: lintguini (Phase 2+)` |
| event-emission | 5 | 0 | presence-fail | `× not configured (weight 5) — recommended: autopompa (Phase 2+)` |
| agents-md | 10 | 100 | kernel-owned | `◉ kernel-owned (weight 10)` |
| project-record | 5 | 50 | kernel-presence-cap | `⊘ presence-cap (weight 5) — recommended: avanti (Phase 1b)` |

Composite: 12.5 + 0 + 0 + 0 + 0 + 0 + 10 + 2.5 = **25**. Letter: **F (Critical)**.

## Pass criteria check

- ✓ No sibling-missing failure is a traceback. Every absent-sibling path in the orchestrator falls through to presence-check logic per `references/report-format.md`; no nil dereference, no "sibling not found" error, no empty-array crashes. Each source enum value has a defined handler.
- ✓ Each non-configured dimension offers a clear next step:
  - `presence-fail` rows surface `recommended: <plugin>` + the `install_command` from `recommendations.json` (or `(Phase N)` suffix when not yet shipped).
  - `kernel-presence-cap` rows surface `recommended: <plugin>` + install command.
  - `kernel-owned` rows reference the kernel-check finding if the score is <100 (on this fixture, agents-md is at 100 so no finding).
- ✓ Kernel presence dimensions still score normally. `agents-md` = 100 (AGENTS.md present with 36 lines); `project-record` kernel-presence-cap = 50 (all 4 subdirs present); `claude-code-config` kernel-presence-cap = 50 (.claude/ present).
- ✓ Composite score reflects that most dimensions are ungraded. F (25/100) is the honest reflection of a fresh kernel-only repo — the scorecard doesn't inflate the grade by missing dimensions.

## Deferred to live environment

- Live scorecard render (markdown output rendering through Claude Code's terminal).
- AskUserQuestion response capture in `/pronto:improve` follow-on after the audit.

## Decision recorded

Graceful degradation is tested at arithmetic + logic level here. The full behavioral assertion — "no tracebacks in any code path" — is exercised by the orchestrator's defensive Phase 4 logic: every dimension's `source` is one of four enum values, and each has a handler; there's no default fall-through that could leave a dimension unscored or produce a nil reference. This is why a live run of A3 is expected to behave as predicted.
