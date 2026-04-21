---
id: a2
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# A2 — Sibling audit aggregation

## Scope of this record

Executed the orchestrator's aggregation (Phase 4 + Phase 5 of `skills/audit/SKILL.md`)
against real fixture parser-output JSON files on disk — not hand arithmetic.
The fixtures are the three Phase-1 parsers' required output shape as defined by
`references/sibling-audit-contract.md`. The uncertainty that does remain — that
the actual live parser subagents produce contract-conforming JSON — is deferred
to Alfred's live session; the aggregator itself is deterministic given any
conforming input and has now been exercised.

## Fixtures

Written to `/tmp/pronto-a2-fixtures/{claudit,skillet,commventional}.json`.
Shaped to test realistic composite scores and contract edge cases:

| Parser | Categories (with weights summing to 1.0) | Composite |
|---|---|---|
| claudit | 6 categories (0.20, 0.15, 0.15, 0.15, 0.20, 0.15) | 80 |
| skillet | 4 categories @ 0.25 each | 70 |
| commventional | 3 categories (0.5, 0.3, 0.2) | 85 |

Each fixture was validated against `references/sibling-audit-contract.md`:
required fields present, category weights sum to 1.0 (±0.05), `composite_score`
matches the weighted mean of category scores.

## Executed aggregation

```
  Phase 5 scoring table:
  dim                     wt    sc   contrib   source
  claude-code-config      25    80      20.0   claudit
  skills-quality          10    70       7.0   skillet
  commit-hygiene          15    85      12.8   commventional
  code-documentation      15    50       7.5   kernel-presence-cap
  lint-posture            15     0       0.0   presence-fail
  event-emission           5     0       0.0   presence-fail
  agents-md               10   100      10.0   kernel-owned
  project-record           5    50       2.5   kernel-presence-cap
  SUM                    100           59.80

  composite_score = 60
  composite_grade = C (Fair)

  ✓ JSON round-trip: full composite envelope = 3849 bytes, round-trips losslessly
  ✓ Contract validation: dimensions[8], all source values in enum, contribution
    sum=59.8 ≈ composite=60 (within ±1 rounding tolerance per report-format.md)
```

Execution time: **98 ms** (budget 5 s).

## Pass criteria check

- ✓ Aggregation math is correct. Composite from executed Phase 5 = **60**.
  Matches hand expectation (20.00 + 7.00 + 12.75 + 7.50 + 0 + 0 + 10.00 + 2.50
  = 59.75 → round to 60).
- ✓ Each sibling's audit runs exactly once. The Phase 4 walk iterates the
  rubric row-by-row; each sibling's parser output is loaded once from its
  fixture file.
- ✓ Output JSON round-trips through a JSON parser. Executed
  `json.loads(json.dumps(output)) == output` on the full 3849-byte envelope;
  assertion passes.
- ✓ Match within ±2 points: executed composite = 60, hand composite = 60. Zero
  delta.

## Notes on Phase 5 rounding

`skills/audit/SKILL.md` Phase 5 says
`weighted_contribution = round(weight * score / 100, 1)`. That per-dimension
rounding is what the executor emits — the sum of one-decimal contributions
(59.8) differs from the unrounded sum (59.75) by 0.05, well within the
`±1` tolerance `references/report-format.md` documents. Both paths produce
`composite_score = 60`.

## Deferred to live environment

- Actual parser-agent dispatches (Task tool) with real claudit / skillet /
  commventional repo state as input. This execution exercised the
  aggregator against the parsers' *contract shape*; a live run additionally
  validates that the parsers themselves produce conforming output.
- Observation of persisted `.pronto/state.json` after a live run matching
  the emitted JSON composite.
- Phase 2.5 expert-context branch activating when claudit is installed.

## Decision recorded

The aggregation layer is exercised end-to-end against contract-shaped JSON.
The delta between this record and a live run is isolated to the parsers'
stdout-to-JSON translation step — not the math pronto owns. The math
produced exactly 60/C on the designed fixture.
