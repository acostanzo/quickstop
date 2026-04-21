---
id: t11
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T11 — README + audit thresholds reference

## Context

Tighten the plugin's documentation surface. README refined to explain role + skill surface + point to the two references (`sdlc-conventions.md`, `audit-thresholds.md`). Thresholds reference documents the three tunable knobs, their defaults and rationales, and two override scopes (repo-wide `.avanti/config.json` + per-artifact frontmatter `audit_ignore: true`).

## What landed

### `plugins/avanti/README.md`

- 179 words (under the 200-word cap).
- Same pivot + seven-skill table from T1's stub, refined.
- New `## References` section linking both `sdlc-conventions.md` and `audit-thresholds.md`.

### `plugins/avanti/references/audit-thresholds.md`

- Table of three knobs (`STALE_PLAN_DAYS=60`, `TICKET_AGE_WARN_DAYS=45`, `PULSE_CADENCE_WARN_DAYS=30`) each with category + rationale.
- Scoring summary paragraph cross-referencing `skills/audit/SKILL.md`.
- Overrides section with two mechanisms:
  - Repo-wide: `.avanti/config.json` `thresholds:` block — JSON example.
  - Per-artifact: `audit_ignore: true` in frontmatter, with example and three use-cases.
- Calibration guidance (suggested review cadence + onboarding trigger).

### Small `/avanti:audit` amendment

Added Step 4b to the audit skill's Phase 0 to honor `audit_ignore: true` before running staleness/cadence/ticket-age deductions. Presence counts are unaffected; overrides are surfaced in verbose output so the pattern doesn't become a quiet way to hide rot.

## Acceptance

- README under 200 words (179). ✓
- Thresholds doc lists each knob with default + rationale + override. ✓
- Override mechanism is documented at both scopes (repo JSON and per-artifact frontmatter). ✓
- No author-specific strings. ✓

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md`
- Audit skill: `plugins/avanti/skills/audit/SKILL.md`
