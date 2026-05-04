---
id: q4-smith-lazy-phase1
plan: quickstop-dev-tooling
status: closed
updated: 2026-05-04
---

# Q4 — Smith lazy Phase 1 verification (deferred from Q3 / U2)

## Closure note (2026-05-04)

Verification protocol executed per the spec below. Six recipe-by-hand
scaffolds (3 cases × 2 modes) produced byte-identical output across all
three case-pairs:

```
=== Case 1 (sibling testfoo) ===            IDENTICAL
=== Case 2 (tool testbar, hooks-mentioned)===IDENTICAL
=== Case 3 (tool testbaz, no hooks) ===      IDENTICAL
```

Mode A faithfully ran Phase 1's research-subagent fallback (claudit:knowledge
not in the active skill list); Mode B skipped Phase 1 entirely. Both modes
fed the same Phase 2 answers into the same Phase 3 templates. Diff was empty.

**Root cause why this had to be empirical.** Phase 3's templates substitute
only from user answers (Phase 2) and three pronto files
(`.claude-plugin/plugin.json`, `references/recommendations.json`,
`references/rubric.md`) plus `date +%Y`. None of the substitution slots
(`<PRONTO_VERSION>`, `<SIBLING_DIMENSION>`, `<SIBLING_DIMENSION_LABEL>`,
`<WEIGHT_HINT>`, `<YEAR>`, `<name>`, `<description>`, etc.) are sourced
from Expert Context. The "Use Expert Context" guidance at Phase 3's
intro was a verification hint, not a substitution input.

**Decision.** Shipped lazy-Phase-1 path: Phase 1 is now default-skip with
explicit trigger conditions (Q4 returned "Other (non-canonical)";
free-text answer names a capability the templates don't cover; explicit
verification need). For the standard sibling and tool paths, smith now
goes Phase 0 → Phase 2 → Phase 3 directly.

**Sanity check.** Re-scaffolded a `lintguini`-style sibling
(name=`lintguini-q4-sanity`, dimension=`lint-posture`) via the lazy
path to a throwaway directory; output is well-formed and matches the
shape 2b1's lintguini scaffold produced before customization
(plugin.json with pronto block, audit/SKILL.md using the slug per Q3 U3,
parse-<name>.md transitional parser, README with Plugin surface section).

PR: [#91](https://github.com/acostanzo/quickstop/pull/91).


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
