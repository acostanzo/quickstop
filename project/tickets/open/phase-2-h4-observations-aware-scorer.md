---
id: h4
plan: phase-2-pronto
status: open
updated: 2026-04-26
---

# H4 — Observations-aware scorer in pronto

## Scope

H3 (merged) bumped the wire contract to schema 2 and specified `observations[]` as the rubric-scoring channel. Without H4, siblings can emit `observations[]` per the new contract and pronto's scorers don't know what to do with them — the architecture exists on paper but doesn't run. New Phase 2 siblings (2a/2b/2c) all ship emitting `observations[]` from day one, so H4 is on the critical path before any sibling PR.

This ticket extends pronto's scoring path to:

- Read `observations[]` from a sibling's audit JSON.
- Look up the per-observation translation rule in `rubric.md` (keyed on observation `id`).
- Apply the rule to produce a 0–100 dimension score (`ratio >= 0.8 → 80/100`, count threshold ladders, presence boolean mapping, score passthrough).
- Fall back to the legacy `composite_score` field via the back-compat passthrough rule from ADR-005 §3 when `observations[]` is absent — treats the v1 `composite_score` as a single coarse observation of `kind: score` and lets it through unchanged.

## Architecture

A pre-implementation plan agent surveyed the current scoring path (SKILL.md Phase 4.1 + Phase 5, the existing `score-<sibling>.sh` scorers, the test harness) and produced the recommendations below. Path comparisons explicitly considered: inline jq in SKILL.md, folding into `compose-composite.sh`, and inlining into each per-sibling scorer. None of those preserve the observe-vs-score split ADR-005 §3 ratifies; a standalone shell helper is the cleanest cut.

### New helper: `plugins/pronto/agents/parsers/scorers/observations-to-score.sh`

The translator. Takes `<dimension-slug> <scorer-json-path>`, reads the rubric stanza for that dimension, applies the per-observation rules, and emits to stdout:

```json
{
  "composite_score": 78,
  "observations_applied": [
    { "id": "claude-md-redundancy-ratio", "kind": "ratio", "score": 70, "rule": "ladder" }
  ],
  "passthrough_used": false,
  "dropped": []
}
```

`SKILL.md` Phase 4.1 captures the scorer's stdout exactly as today (the H2d direct-shell dispatch shape), then pipes that JSON through `observations-to-score.sh`, takes its `composite_score` as the dimension score, and folds entries from `dropped[]` into `sibling_integration_notes`. The `passthrough_used` flag travels through unchanged for visibility but no special handling. Pure shell + jq for arithmetic, plus a YAML extractor for the rubric stanzas (see open question Q1 below).

### `rubric.md` shape — per-observation translation rules

Add a new section `## Observation translation rules` after the existing `## Mechanical vs judgment split`. Per-dimension stanzas live next to the rubric row that owns them. Each stanza is fenced YAML:

````markdown
### `claude-code-config` translation rules

```yaml
observations:
  - id: claude-md-redundancy-ratio
    kind: ratio
    rule: ladder
    bands:
      - { gte: 0.20, score: 40 }
      - { gte: 0.10, score: 70 }
      - { gte: 0.05, score: 85 }
      - { else: 100 }
    weight: 0.20
  - id: mcp-server-count
    kind: count
    rule: ladder
    bands:
      - { gte: 6, score: 50 }
      - { gte: 1, score: 100 }
      - { else: 0 }
    weight: 0.15
default_rule: passthrough   # for kind: score observations with no explicit rule
```
````

`presence` rules are `{rule: boolean, present: 100, absent: 0}`. `score` rules are `{rule: passthrough}`.

H4 ships stanzas only for the three currently parser-driven dimensions: `claude-code-config`, `skills-quality`, `commit-hygiene`. Phase 2 sibling PRs (2a/2b/2c) add stanzas for their own dimensions in their own work.

### Behavior on missing rubric rule

When an observation's `id` has no matching rubric rule, drop the observation and record it in `sibling_integration_notes` (`"<plugin>:<dimension>: dropped observation '<id>' (no rubric rule registered)"`). Score the dimension from the *remaining* observations. If after dropping there are zero observations, fall through to legacy `composite_score` passthrough; if no `composite_score` either, degrade to presence-cap.

Rationale: matches the contract's existing posture for unknown `kind` and missing-required-field cases (the H3 doc at `Validation` says "drop that entry, record the drop in sibling_integration_notes, continue scoring with the remaining observations"). Falling back to `score: 0` would punish siblings for shipping a new observation faster than pronto's rubric updates. Falling back to legacy `score` per-observation would make rule-drift undetectable.

## Implementation order

1. **`plugins/pronto/references/rubric.md`** — add the `## Observation translation rules` section with stanzas for `claude-code-config`, `skills-quality`, `commit-hygiene`. Stanzas are stub-but-syntactically-complete (real values calibrated against current scorer behavior).
2. **`plugins/pronto/agents/parsers/scorers/observations-to-score.sh`** — new helper per the contract above.
3. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** — exhaustive cases: each ratio band edge, count ladder, presence true/false, score passthrough, missing rule (drop + warn), all-dropped fallback, both `observations[]` and `composite_score` present (prefers observations), v1 payload (uses passthrough). Following the `compatible-pronto-check.test.sh` `expect_branch` pattern.
4. **`plugins/pronto/skills/audit/SKILL.md` Phase 4.1** — insert one paragraph between "Capture stdout" and "Validate": pipe scorer JSON through `observations-to-score.sh`, take its `composite_score`, append `dropped[]` entries to `sibling_integration_notes`.
5. **`plugins/pronto/agents/parsers/scorers/score-fixture-observations.sh`** — synthetic fixture script emitting a v2 payload with hand-crafted `observations[]` covering all four kinds. Used by the unit suite, not by the eval harness.
6. **Eval harness on `mid` fixture** — verify composite stddev still ≤ 1.0 and per-dimension means within ±0.5 of the H2d-closeout baseline (composite=61, all dimensions stddev=0). Shipped scorers still emit v1 today, so this run exercises the passthrough rule on every dimension; byte-equivalence to pre-H4 is the key invariant.

## Open questions (need sign-off before implementation)

These are real architectural choices that warrant Anthony's call before code lands. Recommendations are mine; defer if disagreed.

### Q1. `yq` as a runtime dependency

The fenced YAML stanzas in `rubric.md` need a YAML→JSON step in `observations-to-score.sh`. Two paths:

- **(a) Add `yq` to pronto's runtime deps.** `yq` is already in batdev's toolchain. Cleanest extractor; one tool, well-trodden CLI shape.
- **(b) Hand-rolled awk/jq YAML→JSON for the rule subset we use.** No new dep, but more code to test and maintain; deviations from spec become silent extractor bugs.

**Recommendation: (a) — add `yq`.** Plugin runtime deps already include `jq`; adding `yq` is incremental, not categorical. Hand-rolled YAML extraction in shell is the kind of code that bites later.

### Q2. Per-observation weights vs equal weights within a dimension

The example schema gives each observation an explicit `weight` summing to 1.0 within the dimension. Alternative: equal weights, derived (one observation → 1.0; two → 0.5 each; etc.). Explicit weights are more flexible but more rules to maintain; equal weights are simpler but mean adding an observation rebalances all the others.

**Recommendation: explicit weights.** Pronto's existing per-dimension rubric weights (in the `rubric.md` table) are explicit; matching that shape internally to the dimension keeps the surface consistent. Sibling PRs that add observations will need to set weights anyway; equal-weights would force them to not.

### Q3. Surfacing `passthrough_used` in the audit report

When a sibling emits v1 (no observations), `passthrough_used: true` flows through. Should pronto:

- **(a) Always surface in `sibling_integration_notes`** ("\<plugin\>: scored via legacy passthrough — no observations[] emitted").
- **(b) Gate behind a verbose flag** (`--explain` or similar).
- **(c) Not surface at all** — passthrough is the steady-state for in-flight migration.

**Recommendation: (b).** Until 2a/2b/2c ship, every audit will have three (claudit, skillet, commventional) passthroughs in the notes — that's noise on every report. Gate behind a verbose flag during the migration window; surface unconditionally once a deprecation policy is set.

### Q4. Stanza coverage in this ticket

Should H4 add observation-rule stanzas to `rubric.md` for *all* eight rubric dimensions, or only the three currently parser-driven (`claude-code-config`, `skills-quality`, `commit-hygiene`)?

**Recommendation: only the three currently parser-driven.** Phase 2 sibling PRs (2a/2b/2c) own their own dimension's stanza as part of their tickets — that's the per-PR ownership pattern. Adding stubs for `code-documentation`, `lint-posture`, `event-emission` here would land empty rules that would either need calibration before the sibling ships (out-of-order work) or shadowed-rules placeholder code in the translator (unnecessary complexity).

`agents-md` and `project-record` are kernel- and avanti-scored respectively and don't go through observations; they don't need stanzas.

## Acceptance

- Fixture with a sibling emitting `observations[]` produces a deterministic dimension score via the new path (synthetic fixture exercises this).
- Fixture with a sibling emitting only the legacy `composite_score` field produces the same score it does today via the passthrough.
- Fixture with both present prefers `observations[]`.
- Eval harness on the existing `mid` fixture set: composite stddev still ≤ 1.0 *and* per-dimension means within ±0.5 of the H2d-closeout baseline (composite=61, all dimensions stddev=0). Byte-equivalence to pre-H4 is the real invariant — passthrough must not perturb shipped-sibling scoring.
- Unit suite (`observations-to-score.test.sh`) passes with all branches covered.

## Estimated scope

**Medium.** Three files of meaningful new code (helper + tests + synthetic fixture), one section addition to `rubric.md`, one paragraph edit to `SKILL.md`, plus a harness run. Not small because the translator is real logic with four `kind` branches and a fallback ladder. Not large because no new dispatch surface, no sibling-side changes, and synthetic test fixtures don't require Phase 2 sibling work.

## Out of scope

- Phase 2 sibling PRs (2a/2b/2c) ship their own observation stanzas and emit `observations[]` against this scorer.
- Already-shipped siblings (claudit, skillet, commventional) keep emitting v1 — they ride passthrough until their own work cycle migrates them.
- A formal deprecation policy for the v1 passthrough rule (when does v1 stop being accepted?). Plan-level concern; not a Phase 2 ticket.

## References

- `project/plans/active/phase-2-pronto.md` — H4 sits in the Hardening group; closes after H3
- `project/adrs/005-sibling-skill-conventions.md` §3 — the architectural source of truth for observations + passthrough
- `project/tickets/closed/phase-2-h3-wire-contract-schema-2.md` — the wire-contract spec H4 consumes
- `plugins/pronto/references/sibling-audit-contract.md` — the v2 contract doc
- `plugins/pronto/agents/parsers/scorers/compatible-pronto-check.test.sh` — test pattern to follow for `observations-to-score.test.sh`
- `plugins/pronto/skills/audit/SKILL.md` Phase 4.1 — current scoring path the translator slots into
