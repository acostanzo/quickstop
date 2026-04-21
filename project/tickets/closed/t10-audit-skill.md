---
id: t10
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T10 — /avanti:audit skill + pronto wire contract emission

## Context

The depth-audit surface. Walks `project/`, scores four SDLC-hygiene categories against tunable thresholds, emits a markdown scorecard by default and a pronto-wire-contract JSON under `--json`. This is how pronto's "Project record" rubric dimension stops being presence-only and picks up real hygiene measurement.

## What landed

`plugins/avanti/skills/audit/SKILL.md` — four phases:

- **Phase 0** — parse + locate: `--json` flag; repo root; missing `project/` degrades to a valid-envelope response; threshold load from `references/audit-thresholds.md` (T11) with per-repo `.avanti/config.json` override.
- **Phase 1** — measure, four categories with findings and 0-100 scores:
  - **Plan freshness (0.30)** — days since last commit per active plan vs STALE_PLAN_DAYS; deduct 20 per high finding capped at −60; vacuously 100 if no active plans.
  - **Ticket hygiene (0.30)** — unlinked tickets (critical −30); tickets whose plan is done (high −15); open tickets past TICKET_AGE_WARN_DAYS (medium −5); vacuously 100 if no open tickets.
  - **ADR completeness (0.20)** — proposed ADRs with TODO-only decisions (high −15); dangling `superseded_by` (high); missing reverse `supersedes` cross-link (low −5); vacuously 100 if no ADRs.
  - **Pulse cadence (0.20)** — empty pulse dir → 0; days past PULSE_CADENCE_WARN_DAYS deducts 20 per warn-threshold block; header-only day-file deducts 10.
- **Phase 2** — composite-score formula and letter-grade bands (A+ 95-100, A 90-94, B 75-89, C 60-74, D 40-59, F 0-39, matching pronto contract).
- **Phase 3** — recommendations ranked critical→high→medium→low, tie-broken by category weight so ticket/plan tier surfaces first.
- **Phase 4** — emit: markdown scorecard with visual bars by default; JSON-only stdout in `--json` mode.

Error handling: `project/` missing, thresholds missing, malformed frontmatter, git log unavailable, malformed `.avanti/config.json` — each degrades without crashing; JSON mode stays pristine (no debug in stdout).

## Acceptance

- Skill frontmatter complete and well-formed.
- Four categories all documented with scoring rules and example findings.
- JSON shape matches the pronto wire contract documented in T10's SKILL body — top-level envelope (`plugin`, `dimension`, `categories[]`, `composite_score`, `letter_grade`, `recommendations[]`) and per-category (`name`, `weight`, `score`, `findings[]`).
- Thresholds come from `references/audit-thresholds.md` (T11), not hardcoded, with documented defaults as fallback.
- No author-specific strings.

Functional acceptance (score high on clean repo, low on degraded fixture; JSON round-trips) exercised in A3.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md`
- Thresholds: `plugins/avanti/references/audit-thresholds.md` (ships in T11)
- Pronto contract: `plugins/pronto/references/sibling-audit-contract.md` (in pronto's Phase 1)
