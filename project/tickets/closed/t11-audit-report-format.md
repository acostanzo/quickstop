---
id: t11
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T11 — Audit report format

## Context

`plugins/pronto/references/report-format.md` — the shape of `/pronto:audit` output. Two surfaces share the same underlying state: the markdown scorecard (human default) and the JSON composite (`--json`). Written ahead of T4 (audit orchestrator) so the orchestrator implements against a pinned spec rather than inventing shape as it goes.

## Acceptance

- **Markdown scorecard** fits in under 30 rows for a full 8-dimension repo; composite score + grade in a header box; weakest-first dimension ordering; source markers (`✓` sibling-audited, `⊘` presence-capped, `×` presence-fail); kernel-health strip + sibling-integration-notes footer.
- **JSON composite** top-level fields enumerated with types and semantics: `schema_version` (1), `repo`, `timestamp` (ISO 8601 UTC), `composite_score`, `composite_grade`, `composite_label`, `dimensions[]`, `kernel`, `sibling_integration_notes[]`.
- `dimensions[]` entries include `source` enum (`sibling` | `kernel-presence-cap` | `presence-fail` | `kernel-owned`) and an optional embedded `source_audit` carrying the sibling's full contract-conformant emission for drill-down.
- Validation rules documented: `weighted_contribution` sum equals `composite_score` within ±1; partial-failure paths surface in `sibling_integration_notes` (no tracebacks); schema_version bumps on breaking shape changes.
- Linked from plugin README alongside rubric + contract + recommendations.

## Decisions recorded

- **Dimension ordering is score-ascending** — weakest first. Ties broken by rubric weight (heavier first). The rationale is psychological: the first thing the user sees is what to fix.
- **Source enum with four values** — `sibling` / `kernel-presence-cap` / `presence-fail` / `kernel-owned`. Distinct from each other semantically:
  - `kernel-owned` covers dimensions that are always kernel-driven (`agents-md`), not just fallback cases.
  - `kernel-presence-cap` covers the sibling-missing-but-kernel-passed path at the 50 cap.
  - `presence-fail` covers the sibling-missing-and-presence-failed path at 0.
- **Markdown is a summary; JSON is the drill-down surface.** The markdown report intentionally omits per-finding detail; everything granular lives in `dimensions[].source_audit`. Keeps the scorecard skimmable.
- **Size target**: full JSON under 12 KB, markdown under 30 rows. If either is blown past by a future rubric expansion, the rubric weight or the report-format needs rebalancing, not the audit orchestrator.
- `weighted_contribution` is stored pre-computed (not just derivable) so consumers that want to re-rank or re-weight can start from per-contribution values without re-running the rubric math.
