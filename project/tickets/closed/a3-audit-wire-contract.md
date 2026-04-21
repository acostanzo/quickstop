---
id: a3
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# A3 — Audit emits pronto wire contract

## Context

Run `/avanti:audit --json` against two fixtures — the clean A2 round-trip output and a deliberately degraded project/ — and confirm:

1. JSON shape matches the pronto sibling-audit-contract (`plugin`, `dimension`, `categories[]` with name/weight/score/findings, `composite_score`, `letter_grade`, `recommendations[]`).
2. Clean fixture scores high; degraded fixture scores low with specific findings.
3. Output round-trips through a JSON parser without loss.

## Result

**PASS** — dry-run against two fixtures.

### Clean fixture (A2 output state)

```
Composite: 100/100    Grade: A+
  Plan freshness      100  (0 active plans — vacuous)
  Ticket hygiene      100  (0 open tickets — vacuous)
  ADR completeness    100  (1 accepted ADR, clean)
  Pulse cadence       100  (last entry today)
```

### Degraded fixture

Built a separate `project/` with one stale active plan (updated 90d ago), one orphan open ticket (plan link doesn't resolve), one open ticket whose plan is done, one proposed ADR with TODO-only decision, and a 40-day-old pulse file.

```
Composite: 72/100    Grade: C
  Plan freshness       80  — 1 high: 90-day stale active plan
  Ticket hygiene       50  — 1 critical (orphan), 1 high (plan done), 1 medium (90d open)
  ADR completeness     85  — 1 high: proposed with TODO decision
  Pulse cadence        80  — 1 high: 40d old journal (threshold 30d)
```

Recommendations ranked critical → high → medium (6 total). Each carries priority, action, and rationale. JSON round-tripped cleanly through `json.loads(json.dumps(output))` — no shape loss.

### Pronto integration (step 3)

Step 3 of A3 ("`/pronto:audit` with both pronto + avanti installed → composite scorecard folds avanti's project-record score in at weight 0.05") cannot be exercised until pronto's Phase 1 lands. The integration contract is:

- Avanti's `plugin.json` declares `pronto.audits[].dimension = "project-record"`, `command = "/avanti:audit --json"`, `weight_hint = 0.05`. ✓ (landed in T1)
- Pronto discovers the declaration, shells to `/avanti:audit --json`, parses the envelope. ✓ (avanti's emission matches pronto's documented schema; pronto's discovery is in pronto's Phase 1 T4.)

Post-merge verification: once pronto Phase 1 ships, running `/pronto:audit` on this repo (with both plugins installed) should surface a Project record dimension at actual depth score (not presence-only cap). A follow-up note will record the integration test.

## Acceptance

- JSON shape matches documented pronto contract ✓
- Every category has name, weight, score, findings ✓
- Every finding has level, path, message ✓
- Envelope top-level: plugin, dimension, categories, composite_score, letter_grade, recommendations ✓
- Clean fixture produces high score (100 A+) ✓
- Degraded fixture produces low score with specific findings (72 C, 6 findings) ✓
- Output round-trips through a JSON parser without loss ✓
- Cross-plugin `/pronto:audit` fold-in deferred until pronto ships (noted).

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Audit skill: `plugins/avanti/skills/audit/SKILL.md`
- Thresholds: `plugins/avanti/references/audit-thresholds.md`
- Pronto wire contract: `plugins/pronto/references/sibling-audit-contract.md` (in pronto's Phase 1)
