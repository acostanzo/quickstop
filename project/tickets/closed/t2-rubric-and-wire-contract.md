---
id: t2
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T2 — Rubric + wire contract references

## Context

Two references that are the canonical ground truth for every subsequent ticket:

- `references/rubric.md` — dimension list, weights, owners, presence-check semantics, letter-grade bands.
- `references/sibling-audit-contract.md` — `plugin.json` declaration schema, stdout JSON shape, parser pattern for siblings that haven't adopted the contract upstream.

These two docs are what T3 (kernel presence checks), T4 (audit orchestrator + parsers), T9 (recommendations registry), and T11 (report format) all read from. Getting them down before any skill lands means the skills don't have to inline their own copy of the rubric.

## Acceptance

- `rubric.md` — 8 dimensions, weights sum to 100 (hand-verified: 25+10+15+15+15+5+10+5=100), every dimension has a slug, owner, and presence check, letter-grade bands match claudit's A+..F scheme.
- `sibling-audit-contract.md` — `plugin.json` declaration format, stdout JSON schema with per-field required/optional table, severity and priority enums, parser pattern for Phase 1 glue, validation rules.
- Both referenced from `plugins/pronto/README.md`.
- Portability grep for `anthony|batcomputer|batdev|batvault|alfred|grapple-gun|batctl|mind-palace|/home/|localhost`: zero matches inside `plugins/pronto/`.

## Decisions recorded

- Cap value for presence-only scores set at 50 per the plan. Tuning knob called out in rubric.
- Letter-grade bands mirror claudit's so scorecards are visually comparable — deliberate alignment, not copy.
- `weight_hint` in the sibling declaration is advisory, not authoritative. Pronto's rubric weights are the source of truth.
- Parsers live at `plugins/pronto/agents/parsers/<sibling>.md` (T4), documented in the contract as glue that vanishes when siblings ship native support.
- The kernel presence checks are deliberately coarse — "does it exist" not "is it any good." Depth is every sibling's job.
