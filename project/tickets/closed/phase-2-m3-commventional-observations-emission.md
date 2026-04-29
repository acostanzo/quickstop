---
id: m3
plan: phase-2-pronto
status: closed
updated: 2026-04-28
---

# M3 — Commventional observations[] emission

## Scope

H4 (merged) shipped pronto s observations-aware scorer plus the
`commit-hygiene` rubric stanza calibrated against
`score-commventional.sh` s v1 emission. With H4 alone, commventional
still emits v1-shaped JSON (`composite_score`, `categories[]`, no
`observations[]`); the translator s back-compat passthrough rule routes
the v1 score through unchanged. M3 moves commventional to v2 emission
so the rubric-derived score path is exercised end-to-end on the
harness fixture.

The migration target is **`plugins/pronto/agents/parsers/scorers/score-commventional.sh`**
— pronto s deterministic scorer for the commit-hygiene dimension.
The commventional plugin itself (`plugins/commventional/agents/`,
`hooks/`, `skills/`) is **not** modified by this ticket; the plugin is
passive (no slash commands, only PreToolUse hook + dispatch agents) and
none of those files are on the pronto wire path.

## Architecture

A pre-implementation survey on `survey/m3-commventional-observations`
produced `/tmp/m3-commventional-design.md` with the structural shape,
observation IDs, and calibration verification. Recap of the load-bearing
pieces:

### `score-commventional.sh` becomes a v2 emitter

The script keeps every existing measurement and category emission. A
new `observations[]` block is added to the final `jq -n` envelope-build
step, alongside `categories[]`. The four rubric-registered observation
IDs map to existing shell variables in the script:

| Observation ID | Kind | Source variable | Evidence shape |
|---|---|---|---|
| `conventional-commit-ratio` | ratio | `matches`, `total` | `{numerator, denominator, ratio}` (4dp ratio when total≥5; ratio=0 when total<5 to make the insufficient-signal case unambiguous) |
| `auto-trailer-count` | count | `auto_trailers` | `{count: N}` |
| `auto-attribution-marker-count` | count | `auto_marker` | `{count: N}` |
| `review-signal-presence` | presence | (n/a — flat) | `{present: false}` (network-free; the signal is never sampled) |

The envelope also gains `"$schema_version": 2` at the top level. v1
fields (`plugin`, `dimension`, `categories`, `composite_score`,
`letter_grade`, `recommendations`) stay byte-identical.

### Rubric stanza calibration adjustments

The H4-shipped `commit-hygiene` stanza in `rubric.md` mis-calibrates on
the harness `mid` and `noisy` fixtures (rubric→85 vs commv→82 on mid,
+3 drift; rubric→63 vs commv→43 on noisy, +20 drift). Band-tightening
converges the rubric path on score-commventional.sh s path within ±1
across `clean`, `mid`, `noisy` (verified empirically during the survey).
Final stanza shape:

```json
{
  "observations": [
    { "id": "conventional-commit-ratio", "kind": "ratio", "rule": "ladder",
      "bands": [
        { "gte": 0.95, "score": 100 },
        { "gte": 0.80, "score": 80  },
        { "gte": 0.50, "score": 60  },
        { "else": 30 }
      ]
    },
    { "id": "auto-trailer-count", "kind": "count", "rule": "ladder",
      "bands": [
        { "gte": 6, "score": 28  },
        { "gte": 3, "score": 60  },
        { "gte": 1, "score": 85  },
        { "else": 100 }
      ]
    },
    { "id": "auto-attribution-marker-count", "kind": "count", "rule": "ladder",
      "bands": [
        { "gte": 3, "score": 14  },
        { "gte": 1, "score": 70  },
        { "else": 100 }
      ]
    },
    { "id": "review-signal-presence", "kind": "presence", "rule": "boolean",
      "present": 100, "absent": 100
    }
  ],
  "default_rule": "passthrough"
}
```

Verification table (hand-walked):

| Fixture | Signals | Bands hit | Mean | v1 | Drift |
|---|---|---|---|---|---|
| clean | (1.0, 0, 0, absent) | 100,100,100,100 | 100 | 100 | 0 |
| mid   | (1.0, 17, 0, absent) | 100, 28,100,100 |  82 |  82 | 0 |
| noisy | (0.286, 7, 3, absent) | 30, 28, 14,100 |  43 |  43 | 0 |

These calibration changes ride in the same M3 PR as the emission code —
the rubric stanza and the emitter must agree on the observation ID set
or the translator drops the new ID with a "no rubric rule registered"
warning.

### Discovery path stays at step 2

Like M1, M3 stays in the `score-commventional.sh` + parser-agent +
recommendations.json discovery path (ADR-005 §5 step 2). A future
follow-up could move commventional to a dispatched-skill step-1 path,
but that is independent of observations emission.

## Implementation order

1. **`plugins/pronto/references/rubric.md`** — apply the band-tightening
   adjustments to the `commit-hygiene` translation stanza:
   - `conventional-commit-ratio` bands → `[gte 0.95→100, gte 0.80→80, gte 0.50→60, else 30]`
   - `auto-trailer-count` bands → `[gte 6→28, gte 3→60, gte 1→85, else 100]`
   - `auto-attribution-marker-count` bands → `[gte 3→14, gte 1→70, else 100]`
   - `review-signal-presence` unchanged (`100/100`).
   - Update the prose paragraph beneath the stanza to describe the new
     band shapes and call out the network-free / dead-weight design.
2. **`plugins/pronto/agents/parsers/scorers/score-commventional.sh`** —
   extend the final `jq -n` step to emit `observations[]` with the four
   IDs above. Add `"$schema_version": 2` at the top level. Confirm
   `categories[]` and the other v1 fields are byte-identical to
   pre-change for each fixture (use the snapshots staged on the survey
   branch).
3. **`plugins/commventional/test-fixtures/snapshots/`** — already staged
   on the survey branch with `clean`, `mid`, `noisy` envelopes plus
   build scripts for clean/noisy. Move from the survey branch to M3 s
   branch as test infrastructure for invariant B.
4. **`plugins/commventional/test-fixtures/snapshots/snapshots.test.sh`** —
   already staged. Confirms invariant B (categories[] byte-identity)
   and invariant A by mechanical proxy (scorer output is the wire
   payload; the LLM dispatch agents and ownership hook are untouched).
5. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** —
   add a fixture-scoped case for the four-observation commit-hygiene
   shape so the harness can spot calibration drift if the stanza or
   emission gets edited later.
6. **Eval harness on `mid`** — run with `N=20` against the M1-closeout
   baseline (composite=61, all-dim stddev=0). Acceptance: composite
   stddev ≤ 1.0; per-dimension `commit-hygiene` mean within ±0.5 of
   baseline. After the stanza fix the deterministic dimension score is
   82, matching today s path; the harness composite is unchanged.

## Acceptance

- All four observation IDs emit on every run with deterministic
  evidence shape; `score-commventional.sh` exit code unchanged.
- `categories[]`, `plugin`, `dimension`, `composite_score`,
  `letter_grade`, `recommendations` byte-identical to pre-M3 snapshots
  for `clean`/`mid`/`noisy` fixtures.
- Translator (`observations-to-score.sh`) on the M3-emitted envelope
  produces a `composite_score` within ±1 of `score-commventional.sh` s
  `composite_score` on each fixture.
- Eval harness on `mid` (N=20): composite stddev ≤ 1.0; per-dimension
  `commit-hygiene` mean within ±0.5 of the M1-closeout baseline.
- `plugins/commventional/agents/`, `plugins/commventional/hooks/`, and
  `plugins/commventional/skills/` are unchanged in the diff.
- Audit-level passthrough summary line emitted by Phase 5 reads
  `0/3 siblings scored via legacy passthrough` after M3 ships
  (assuming M2 has also landed; otherwise `1/3`).

## Three load-bearing invariants

A. **Standalone byte-identity.** Commventional has no slash command on
the wire path — the plugin is passive (PreToolUse hook + dispatch
agents). M3 modifies only `score-commventional.sh`; nothing under
`plugins/commventional/` is touched. Confirmed via `git diff main..feat/m3-commventional-observations -- plugins/commventional/` — must produce empty output.

B. **`categories[]` byte-identity.** `snapshots.test.sh` runs 5
byte-level diffs per fixture × 3 fixtures = 15 checks. Pre-M3 envelopes
locked under `plugins/commventional/test-fixtures/snapshots/{clean,mid,noisy}/envelope.json`.

C. **Pronto-side composite reproduction.** Hand-walked verification
against all three fixtures shows ±0 drift with the proposed bands;
harness on `mid` (N=20) must reproduce the M1-closeout
`commit-hygiene=82` mean within ±0.5 stddev ≤ 1.0.

## Out of scope

- **Skill-name migration to `commventional:audit`.** A future follow-up
  if the dispatched-skill discovery path is preferred for commventional.
- **Skillet observations migration (M2).** Independent ticket; same
  pattern, different sibling.
- **Claudit observations migration (M1).** Already shipped (PR #61).
- **Deprecating the back-compat passthrough rule.** Fires once M1 + M2
  + M3 ship and the passthrough summary line reads `0/3`. Separate work
  cycle, tracked in `phase-2-pronto.md`.
- **Refactoring trailer + marker into a single
  `engineering-ownership-score` observation.** Surveyed in the design
  doc as an alternative to band-tightening; deferred. The bands fix is
  M3-shaped; an EO-collapse refactor is a separate Phase-2 closeout
  candidate if off-axis drift bites in practice.

## References

- `project/plans/active/phase-2-pronto.md` — M3 sits in the
  legacy-sibling-migration arc; closes after M1/M2.
- `project/tickets/closed/phase-2-h4-observations-aware-scorer.md` —
  the translator + rubric stanza this ticket calibrates against.
- `project/adrs/005-sibling-skill-conventions.md` §3 — observations
  vs. score split, back-compat passthrough rule.
- `plugins/pronto/references/sibling-audit-contract.md` — v2 wire
  contract (envelope shape, observation entry shape).
- `plugins/pronto/references/rubric.md` `## Observation translation
  rules` — the rubric stanza M3 calibrates and emits against.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  the translator that consumes M3 s emission.
- `plugins/pronto/agents/parsers/scorers/score-commventional.sh` —
  the file M3 modifies.
- `plugins/commventional/test-fixtures/snapshots/` (staged on
  `survey/m3-commventional-observations`) — pre-M3 envelope snapshots
  for invariant B regression.
- `/tmp/m3-commventional-design.md` (on Batdev) — full survey design
  doc with calibration verification.
- M1 PR #61 — canonical pattern this ticket follows.
