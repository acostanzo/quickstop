---
id: h3
plan: phase-2-pronto
status: open
updated: 2026-04-26
---

# H3 — Bump wire contract to schema 2 with `observations[]`

## Scope

ADR-004 (Consequences > Neutral) flagged the follow-up explicitly: *"versioning the wire contract itself — adding a schema-version header to `sibling-audit-contract.md` — is a follow-up."* ADR-005 §3 then specified the field that the version bump carries: a top-level `observations: []` array, deliberately distinct from the existing `categories[].findings[]` array (the existing array carries triaged human-readable issues with severity `critical|high|medium|low|info`; observations are raw signal that pronto's scorers translate into a rubric score). The two changes belong in the same wire-contract revision — versioning without a payload change is busywork, and the payload change without a version bump leaves consumers unable to negotiate.

This ticket lands the doc-level half of that work. The consumer-side scoring path is H4.

## Change

In `plugins/pronto/references/sibling-audit-contract.md`:

1. Add a parseable `$schema_version: 2` marker. Frontmatter is the chosen form (a top-level YAML block at the head of the doc) — it parses cleanly without forcing readers through a section-header convention, and it pairs naturally with the `updated:` field already used elsewhere in this repo's reference docs.
2. Add the top-level `observations: []` array specification per ADR-005 §3:
   - `id` — string, stable identifier (e.g. `structured-log-ratio`).
   - `kind` — enum, one of `ratio | count | presence | score`.
   - `evidence` — object, free-form per `kind` (a `ratio` observation typically carries `numerator`, `denominator`, and the computed `ratio`; a `count` observation carries an integer; etc.).
   - `summary` — string, human-readable one-line description.
3. Document the relationship to the existing `categories[].findings[]` channel: observations are the rubric-scoring channel; findings are the triaged-issue channel. Different consumers, parallel concepts.
4. Document the back-compat passthrough rule from ADR-005 §3: the existing `composite_score` and per-category `score` fields remain optional. Siblings that haven't migrated to observations can keep emitting scores; pronto's scorer treats a `score` as a single coarse observation of `kind: score` and applies a passthrough rule.

The wire payload itself gains `$schema_version` as a top-level field too — it's not just a doc marker but a runtime negotiation hint.

## Out of scope

- **Consumer-side scoring path.** H4 ticket — extend pronto's scorers to read `observations[]`, apply rubric translation rules per dimension (`ratio >= 0.8 → 80/100`, threshold ladders, count-based scoring), fall back to legacy `score` via the passthrough rule.
- **Sibling migration.** Phase 2 sibling PRs (2a/2b/2c) ship emitting `observations[]` from day one against the new schema. Already-shipped siblings (claudit, skillet, commventional) keep emitting `score` until their own work migrates them — the back-compat rule covers the gap.
- **Validation code.** No new runtime validation in this ticket; the doc is the schema, and H4 lands the consumer code that exercises the new fields.

## Acceptance

- The doc carries the `$schema_version: 2` marker (parseable from the YAML frontmatter).
- The `observations[]` spec is fully specified at the top level — field reference table for the array, field reference table for the per-observation entry shape, an example payload that includes observations.
- The relationship to `categories[].findings[]` is documented in prose.
- The back-compat passthrough rule is documented for v1-shaped siblings.
- ADR-005 §3 cross-reference resolves cleanly (the doc says what the ADR says it should say).
- ADR-004's earlier "version exists in the registry but not on the contract doc itself" gap closes.

No harness run required — the deliverable is a documentation update, not a code change. Acceptance is a read-through against this ticket's checklist.

## References

- `project/plans/active/phase-2-pronto.md` — H3 sits in the Hardening group, parallel with H2 (now closed)
- `project/adrs/004-sibling-composition-contract.md` — the "version exists in the registry but not on the contract doc itself" follow-up this ticket closes
- `project/adrs/005-sibling-skill-conventions.md` §3 — the authoritative spec for `observations[]`, the four `kind` values, and the passthrough rule
- `plugins/pronto/references/sibling-audit-contract.md` — the file under change
