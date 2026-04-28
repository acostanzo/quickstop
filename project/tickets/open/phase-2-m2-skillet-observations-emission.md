---
id: m2
plan: phase-2-pronto
status: open
updated: 2026-04-27
---

# M2 — Skillet observations[] emission

## Scope

H4 (merged) shipped pronto's observations-aware scorer plus the
`skills-quality` rubric stanza calibrated against `score-skillet.sh`'s
v1 emission. With H4 alone — and post-M1 — skillet still emits v1-shaped
JSON (`composite_score`, `categories[]`, no `observations[]`); the
translator's back-compat passthrough rule routes the v1 score through
unchanged. M2 moves skillet to v2 emission so the rubric-derived score
path is exercised end-to-end on the harness fixture.

The migration target is **`plugins/pronto/agents/parsers/scorers/score-skillet.sh`**
— pronto's deterministic scorer for the skills-quality dimension. The
LLM-driven `/skillet:audit`, `/skillet:build`, and `/skillet:improve`
slash commands in `plugins/skillet/skills/{audit,build,improve}/SKILL.md`
are separate banner-style health-report orchestrators and are **not**
modified by this ticket.

## Architecture

A pre-implementation survey on `survey/m2-skillet-observations` produced
`/tmp/m2-skillet-design.md` with the structural shape, observation IDs,
and calibration verification. Recap of the load-bearing pieces:

### `score-skillet.sh` becomes a v2 emitter

The script keeps every existing measurement and category emission. A
new `observations[]` block is added to the final `jq -n` envelope-build
step, alongside `categories[]`. The five rubric-registered observation
IDs map to existing per-skill measurements aggregated across the loop:

| Observation ID | Kind | Source variable | Evidence shape |
|---|---|---|---|
| `skill-frontmatter-completeness-ratio` | ratio | `fm_present_total`, `fm_required_total` (new aggregates of the existing per-skill 4-field check) | `{numerator, denominator, ratio}` |
| `skill-skeletal-count` | count | `skeletal_count` (sum of `nblines < 20` skills) | `{count: N}` |
| `skill-todo-marker-count` | count | `todo_total` (sum of `todo_count` per skill) | `{count: N}` |
| `skill-broken-references-count` | count | `broken_refs_total` (sum of `broken_refs` per skill) | `{count: N}` |
| `skill-stray-file-count` | count | `stray_total` (sum of `stray_count` per skill) | `{count: N}` |

The envelope also gains `"$schema_version": 2` at the top level. v1
fields (`plugin`, `dimension`, `categories`, `composite_score`,
`letter_grade`, `recommendations`) stay byte-identical. The empty-scope
short-circuit (no SKILL.md files found) emits `observations: []` and
`$schema_version: 2`; the translator falls through to v1 passthrough
and end-to-end behaviour is unchanged on no-skills repos.

### Rubric stanza calibration adjustments

The H4-shipped `skills-quality` stanza in `rubric.md` mis-calibrates
on the harness `mid` fixture (rubric→86, score-skillet→97, 11-pt
drift; same drift on `noisy`: rubric→65, score-skillet→76). The root
cause is a scale mismatch — rubric bands operate on aggregate counts,
while score-skillet's per-skill cap-and-average yields different
effective thresholds. Two stanza adjustments converge the rubric path
on score-skillet's path within ±1 across `clean`, `mid`, `noisy`
(verified empirically during the survey):

1. **`skill-todo-marker-count` bands** — rescale to multi-skill
   aggregate thresholds:
   `[{gte: 100, score: 70}, {gte: 50, score: 80}, {gte: 20, score: 90},
   {gte: 5, score: 95}, {else: 100}]`.
2. **`skill-broken-references-count` bands** — same rescale shape:
   `[{gte: 20, score: 60}, {gte: 10, score: 80}, {gte: 5, score: 90},
   {gte: 1, score: 95}, {else: 100}]`.

The other three observations
(`skill-frontmatter-completeness-ratio`, `skill-skeletal-count`,
`skill-stray-file-count`) reproduce score-skillet correctly and don't
need band changes.

These calibration changes ride in the same M2 PR as the emission code —
the rubric stanza and the emitter must agree on the observation ID set
or the translator drops IDs with a "no rubric rule registered" warning.

### Discovery path stays at step 2

ADR-005 §5 specifies a future migration where skillet gets a renamed
`skills/audit/SKILL.md` namespace (e.g. `skillet:audit`) and pronto
resolves dispatch at step 1. M2 does **not** ship that migration — it
stays in the score-skillet.sh + parser-agent + recommendations.json
path. Filing a follow-up M2.5 (skill-name migration) is recommended
once M2 proves stable.

## Implementation order

1. **`plugins/pronto/references/rubric.md`** — apply the two
   calibration adjustments to the `skills-quality` translation stanza
   (TODO and broken-references band rescales).
2. **`plugins/pronto/agents/parsers/scorers/score-skillet.sh`** —
   extend the per-skill loop with five global aggregate counters,
   then extend the final `jq -n` step to emit `observations[]` with
   the five IDs above. Add `"$schema_version": 2` at the top level.
   Extend the empty-scope short-circuit to emit
   `observations: [], "$schema_version": 2`. Confirm
   `categories[]` and the other v1 fields are byte-identical to
   pre-change for each fixture (use the snapshots below).
3. **`plugins/skillet/test-fixtures/snapshots/`** — already staged on
   the survey branch with `clean`, `mid`, `noisy` envelopes plus the
   synthetic input directories for clean/noisy. Move from the survey
   branch to M2's branch as test infrastructure for invariant B.
4. **`plugins/skillet/test-fixtures/snapshots/snapshots.test.sh`** — new
   regression test (lift M1's pattern from
   `plugins/claudit/test-fixtures/snapshots/snapshots.test.sh`):
   for each fixture, run the (new) `score-skillet.sh` and diff the
   `categories[]` and other v1-projected fields against the staged
   snapshot. Confirms invariant B (categories[] byte-identity) and
   invariant A by mechanical proxy (scorer output is the wire payload;
   the LLM skills are untouched).
5. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** —
   add a fixture-scoped case for the five-observation skills-quality
   shape so the harness can spot calibration drift if the stanza or
   emission gets edited later.
6. **Eval harness on `mid`** — run with `N=20` against the post-M1
   baseline. Acceptance: composite stddev ≤ 1.0; per-dimension
   `skills-quality` mean within ±0.5 of post-M1 baseline (97). After
   the stanza fixes the deterministic dimension score is 96, matching
   today's path within ±1; the harness composite is unchanged at 61.

## Acceptance

- All five observation IDs emit on every run with deterministic
  evidence shape; `score-skillet.sh` exit code unchanged.
- `categories[]`, `plugin`, `dimension`, `composite_score`,
  `letter_grade`, `recommendations` byte-identical to pre-M2 snapshots
  for `clean`/`mid`/`noisy` fixtures.
- Translator (`observations-to-score.sh`) on the M2-emitted envelope
  produces a `composite_score` within ±1 of `score-skillet.sh`'s
  `composite_score` on each fixture.
- Eval harness on `mid` (N=20): composite stddev ≤ 1.0; per-dimension
  `skills-quality` mean within ±0.5 of the post-M1 baseline (97 ± 0.5).
- `plugins/skillet/skills/audit/SKILL.md`,
  `plugins/skillet/skills/build/SKILL.md`,
  `plugins/skillet/skills/improve/SKILL.md`, and the rest of
  `plugins/skillet/skills/**` are unchanged in the diff.
- Audit-level passthrough summary line emitted by Phase 5 reads
  `1/3 siblings scored via legacy passthrough — observations[]
  migration pending` after M2 ships (one fewer passthrough than
  post-M1).

## Out of scope

- **Skill-name migration to `skillet:audit`.** ADR-005 §1's eventual
  discovery target. Filed as M2.5 follow-up.
- **Commventional observations migration (M3).** Independent ticket;
  same pattern, different sibling.
- **Deprecating the back-compat passthrough rule.** Fires once
  M1 + M2 + M3 ship and the passthrough summary line reads `0/3`.
  Separate work cycle, tracked in `phase-2-pronto.md` under
  "Post-Phase-2 — legacy sibling migration."
- **Rebasing TODO/broken-refs as ratio observations.** Survey
  identified that count-with-aggregate-thresholds is sensitive to
  fleet size. Acceptable for M2's three fixtures; flag as a follow-up
  if the rubric format gets a second pass post-Phase-2 and ratio
  observations would auto-scale with fleet size.

## References

- `project/plans/active/phase-2-pronto.md` — M2 sits in the
  legacy-sibling-migration arc; closes after M1 and before M3
- `project/tickets/closed/phase-2-h4-observations-aware-scorer.md` —
  the translator + rubric stanza this ticket calibrates against
- `project/tickets/open/phase-2-m1-claudit-observations-emission.md` —
  M1, the proven-shape reference for this migration
- `project/adrs/005-sibling-skill-conventions.md` §3 — observations
  vs. score split, back-compat passthrough rule
- `plugins/pronto/references/sibling-audit-contract.md` — v2 wire
  contract (envelope shape, observation entry shape)
- `plugins/pronto/references/rubric.md` `## Observation translation
  rules` `### skills-quality translation rules` — the rubric stanza
  M2 calibrates and emits against
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  the translator that consumes M2's emission
- `plugins/pronto/agents/parsers/scorers/score-skillet.sh` — the file
  M2 modifies
- `plugins/skillet/test-fixtures/snapshots/` (staged on
  `survey/m2-skillet-observations`) — pre-M2 envelope snapshots for
  invariant B regression
- `/tmp/m2-skillet-design.md` (on Batdev, also at
  `/tmp/m2-skillet-design.md` on Batcomputer) — full survey design doc
  with calibration verification
