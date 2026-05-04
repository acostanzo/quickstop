---
id: q4-smith-lazy-phase1
plan: quickstop-dev-tooling
status: open
updated: 2026-05-03
---

# Q4 — Smith lazy Phase 1 verification (deferred from Q3 / U2)

## Scope

Q3 (PR #88) deferred U2 — the Phase 1 lazy-fanout proposal — because the verification step requires interactive `AskUserQuestion` and can't run inside a non-interactive automation PR. This ticket captures the deferred work; the verification is the deliverable.

The proposal (per Q3's U2 finding): smith's Phase 1 dispatches `/claudit:knowledge ecosystem` (or two parallel research subagents on fallback) before any user-visible scaffolding. The 2b1 lintguini dogfood observed empirically that Phase 1's output did **not** influence the scaffolded files for that standard sibling case. If that's true generally for standard sibling/tool paths, Phase 1 can run lazily — only when a free-text answer exposes a gap (non-standard plugin type, unfamiliar dimension, request smith doesn't have a template for).

If verification confirms byte-identical output across three standard cases, ship the lazy-Phase-1 path. If verification shows differences, document which inputs trigger them and condition Phase 1 on those — don't ship a blanket skip that would degrade output quality.

## Verification protocol

Run smith twice for each of three standard cases. Mode A: Phase 1 enabled (current behaviour). Mode B: Phase 1 manually skipped (jump straight to Phase 2). Diff the two scaffold outputs.

| # | Case | Inputs to smith |
|---|---|---|
| 1 | Sibling | role=sibling, dimension=any-existing-rubric-row (e.g. `code-documentation`), name=`testfoo` |
| 2 | Tool with hooks-considered | role=tool, hooks-considered=yes, name=`testbar` |
| 3 | Tool without hooks | role=tool, hooks-considered=no, name=`testbaz` |

For each case: `diff -r` the two scaffold output trees. Acceptance: byte-identical across all three cases.

## Decision rule

- **All three byte-identical:** ship the lazy-Phase-1 path. `.claude/skills/smith/SKILL.md` Phase 1 grows a guard that runs the expert-context fanout only when a free-text answer flags an unrecognized plugin type or dimension. Standard cases skip Phase 1 entirely.
- **Any case differs:** identify the inputs driving the difference. Either (a) condition Phase 1 on those inputs (lazy with explicit triggers), or (b) keep Phase 1 mandatory and close this ticket as "investigation produced no actionable change."

## Scope discipline

- The verification work itself involves running smith interactively six times. Allocate ~30 minutes.
- Don't widen scope to other smith tweaks — Q3 already shipped the polish round.
- If Phase 1 is shipped lazy, regenerate one of the existing siblings (e.g. `lintguini`-style, but to a throwaway directory) end-to-end as a sanity check before merging.

## Out of scope

- Re-running smith against `inkwell` or any of the production siblings — those are hand-implemented, not the smith dogfood path.
- Deeper smith-architecture changes (template engine swap, etc.) — separate work.

## References

- Q3 ticket (closed) — `project/tickets/closed/quickstop-dev-tooling-q3-smith-dogfood-fixes.md` — U2 finding context.
- PR #88 — Q3 implementation; PR body documents the deferral rationale.
- `.claude/skills/smith/SKILL.md` — current Phase 1 logic.

## Why this isn't urgent

`/smith` is invoked at plugin-creation time, not per-PR. Phase 1's wasted time per call is real but bounded; total wasted time across the project is low because /smith runs rarely. This is polish, not a critical fix. Pick it up when there's a "smith improvement" mood, not as a gating item.
