---
id: t5
plan: inkwell-expansion
status: open
updated: 2026-05-05
---

# t5 — M5: subagent corroboration layer + conditional audit scorers

## Context

Implements milestone M5 — the killer feature. Wires the inference-time corroboration layer into `/inkwell:query` (Tiers 1–3) and lands the three new conditional audit scorers. The architectural rationale — why corroboration is `/inkwell:query`-only and the audit stays deterministic — is recorded in `project/adrs/007-inkwell-corroboration-architecture.md`; this ticket implements that decision.

Plan sections implemented: "Inference-time code corroboration" and "Audit additions — conditional scorers" in `project/plans/active/inkwell-expansion.md`.

## Acceptance criteria

**Corroboration layer wired into `/inkwell:query`:**

- `plugins/inkwell/bin/inkwell-corroborate.sh` is the subagent dispatcher. `/inkwell:query` invokes it during answer-shaping; no other skill calls it directly.
- Tier 1 (deterministic name-resolution): inline code spans (`functionName`, `path/to/file.ts`) are verified by grep / `ast-grep` for symbol/file existence. No LLM dispatch on this tier.
- Tier 2 (LLM-judged behavioural verification): behavioural assertions ("when X, returns Y", "the default is Z") dispatch one `Explore`-class subagent per claim batch. Bounded; parallelisable across independent claims.
- Tier 3 (annotated "could not corroborate"): conceptual statements, design rationale, and narrative are tagged `could not corroborate` with no penalty — these are the things docs *should* carry that code can't express.
- Each cited claim in the response carries one of three tags: `verified`, `drift detected (see file.ts:N)`, or `could not corroborate`. The tag is surfaced prominently in the answer.
- The corroboration field in the response contract — locked at M3 as `not yet implemented` — is now populated with real verdicts. The contract shape (field names, ordering, citation format) is unchanged from M3.
- Subagent failure (unreachable, timeout) returns `could not corroborate` for the affected claims. `/inkwell:query` ships its answer regardless — corroboration never blocks the response.

**Conditional audit scorers under `plugins/inkwell/scorers/`:**

- `score-template-compliance.sh` — % of inkwell-marked docs with valid `template:` frontmatter and required sections.
- `score-backlink-coverage.sh` — % of inkwell-marked docs that terminate with a non-empty `## Related` block.
- `score-duplicate-density.sh` — title + content-overlap pairs and near-duplicate count.
- All three scorers gate on "did inkwell's doc model show up in this repo?" — detected by presence of inkwell frontmatter on any `docs/**/*.md`. If markers absent, scorers emit empty-scope: no contribution to the composite, no warning, no penalty.
- All three scorers stay deterministic — pure shell + grep + awk + jq, no LLM dispatch. The audit does not call `inkwell-corroborate.sh`.
- Existing scorers (`score-readme-quality.sh`, `score-docs-coverage.sh`, `score-doc-staleness.sh`, `score-link-health.sh`) are unchanged.
- Running `/inkwell:audit` against a non-inkwell consumer (no doc frontmatter) produces an identical composite letter grade to today's audit.

## Notes

The "no corroboration scorer" decision is load-bearing — see ADR-007's rejected alternative "Subagent-in-audit-scorers." The audit measures things that don't need an LLM; corroboration needs an LLM. Keeping them separate keeps the audit fast, reproducible, and CI-friendly.

The M6 stretch work (sharper Tier-2 claim extraction, subagent prompt iteration, parallel batching) is **not** part of this ticket — it ships as its own plan if and when it lands.

## Links

- Plan: `project/plans/active/inkwell-expansion.md`
- ADR: `project/adrs/007-inkwell-corroboration-architecture.md`
