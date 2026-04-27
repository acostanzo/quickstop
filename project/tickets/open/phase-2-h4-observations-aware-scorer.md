---
id: h4
plan: phase-2-pronto
status: open
updated: 2026-04-27
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

`SKILL.md` Phase 4.1 captures the scorer's stdout exactly as today (the H2d direct-shell dispatch shape), then pipes that JSON through `observations-to-score.sh`, takes its `composite_score` as the dimension score, and folds entries from `dropped[]` into `sibling_integration_notes`. The translator also accumulates a passthrough count for the audit-level summary line (see Decision Q3). Pure shell + jq throughout — rules are JSON, no YAML conversion step needed.

### `rubric.md` shape — per-observation translation rules

Add a new section `## Observation translation rules` after the existing `## Mechanical vs judgment split`. Per-dimension stanzas live next to the rubric row that owns them. Each stanza is fenced JSON (parsed by `jq` directly — see Decision Q1):

````markdown
### `claude-code-config` translation rules

```json
{
  "observations": [
    {
      "id": "claude-md-redundancy-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.20, "score": 40 },
        { "gte": 0.10, "score": 70 },
        { "gte": 0.05, "score": 85 },
        { "else": 100 }
      ]
    },
    {
      "id": "mcp-server-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 6, "score": 50 },
        { "gte": 1, "score": 100 },
        { "else": 0 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```
````

`presence` rules are `{"rule": "boolean", "present": 100, "absent": 0}`. `score` rules are `{"rule": "passthrough"}`. `weight` is optional per observation; absent → equal-weight share within the dimension (see Decision Q2). Comments live in the markdown surrounding the JSON fence, not in the JSON itself.

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

## Decisions

The four architectural questions originally filed against this ticket were decided by Anthony on 2026-04-27. The agreed answers are encoded above; this section is the audit trail.

### Q1. Rules format — JSON, not YAML

**Decided: rules are JSON fenced inside `rubric.md`.** Original recommendation was YAML with a new `yq` runtime dependency (cleaner human editing). Anthony pushed back: pronto already parses JSON via `jq`; adding `yq` is a categorical not incremental dep; the only editors are him and me, and neither of us suffers over JSON braces. Co-location in `rubric.md` is preserved (the dimension stanza sits next to the rubric prose for that dimension); inline comments move to the surrounding markdown, where they're more discoverable anyway.

Net effect: drop `yq` entirely. `observations-to-score.sh` extracts the JSON fences from `rubric.md` with a small awk/sed step (or a markdown-aware extraction helper) and pipes straight into `jq` for evaluation.

### Q2. Weights — equal-share default, explicit weights as opt-in

**Decided: equal weights derived from `1/n` are the default; an observation may opt in to explicit `weight` to override.** Original recommendation was always-explicit weights matching the rubric table's per-dimension weight shape. The pushback: that table is at *dimension* level, not *observation* level — different scope, different math, internal consistency at one level doesn't require it at the next. At our scale (~2–4 observations per dimension) the rebalancing cost of explicit weights outweighs the tuning benefit. Equal-weight default keeps sibling PRs friction-free; explicit weights remain available when a dimension genuinely needs to express dominance.

The translator treats absent `weight` as `1/n` where `n` is the count of *kept* observations after drops. Mixed (some explicit, some absent) is a configuration error and rejected by the translator's stanza loader.

### Q3. Passthrough surfacing — single summary line, always on

**Decided: surface a single summary line in `sibling_integration_notes` reporting the passthrough count, always on.** Original recommendation was to gate behind a verbose flag. Anthony's read: invisible passthroughs make the migration invisible — six months later you might still have half the fleet on v1 and never notice from reading reports.

Format: `N/M siblings scored via legacy passthrough — observations[] migration pending`. When `N` reaches `0`, the migration is complete; that's the trigger point to file a follow-up deprecating the back-compat passthrough rule itself.

This replaces the per-sibling warning shape (which would noise every report with three lines today) with a single trend-tracking line that decreases as siblings migrate. Concrete, low-noise, always visible.

### Q4. Stanza coverage — three parser-driven dimensions only

**Decided: only `claude-code-config`, `skills-quality`, and `commit-hygiene` get stanzas in this ticket.** Reasoning unchanged from the original recommendation:

- The other observation-using dimensions (`code-documentation`, `lint-posture`, `event-emission`) are exactly what Phase 2 sibling PRs (2a/2b/2c) introduce. Each of those PRs owns its dimension's stanza — that's the per-PR ownership pattern, and pre-writing those stanzas here means making decisions inside another ticket's scope and calibrating against behavior that doesn't exist yet.
- `agents-md` and `project-record` are kernel- and avanti-scored respectively and don't go through observations; they don't need stanzas.
- The three covered dimensions have shipped siblings emitting v1 today, so their stanzas can be calibrated against current scorer behavior — the rules will produce identical scores to today's path on day one (the passthrough invariant).

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
- Already-shipped siblings (claudit, skillet, commventional) keep emitting v1 — they ride passthrough until tickets M1/M2/M3 migrate them. Those tickets are tracked in `phase-2-pronto.md` under "Post-Phase-2 — legacy sibling migration."
- The follow-up that deprecates the back-compat passthrough rule itself (stop accepting v1 payloads) — fires once M1/M2/M3 ship and the passthrough-count line reads `0/3`. Separate work cycle.

## References

- `project/plans/active/phase-2-pronto.md` — H4 sits in the Hardening group; closes after H3
- `project/adrs/005-sibling-skill-conventions.md` §3 — the architectural source of truth for observations + passthrough
- `project/tickets/closed/phase-2-h3-wire-contract-schema-2.md` — the wire-contract spec H4 consumes
- `plugins/pronto/references/sibling-audit-contract.md` — the v2 contract doc
- `plugins/pronto/agents/parsers/scorers/compatible-pronto-check.test.sh` — test pattern to follow for `observations-to-score.test.sh`
- `plugins/pronto/skills/audit/SKILL.md` Phase 4.1 — current scoring path the translator slots into
