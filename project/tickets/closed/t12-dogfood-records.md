---
id: t12
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T12 — Dogfood execution records

## Context

Apply avanti's conventions to its own Phase 1 execution. Every T-ticket has a commit under `plugins/avanti/` AND a ticket record under `project/tickets/`. Two ADRs record the two load-bearing decisions. Pulse journal spans execution.

## What landed

### Ticket records

Each T-ticket landed its own `project/tickets/closed/t<N>-<slug>.md` in the same atomic commit as its plugin work. Tickets are filed directly to `closed/` (rather than open/ → closed/ as two commits) since every ticket in this batch was authored and completed in one execution unit. The open→in-progress→closed lifecycle is exercised end-to-end in A2 against a fresh test repo, which is the real demonstration.

Inventory:

- `t1-scaffold-avanti.md` — plugin shell
- `t2-sdlc-conventions.md` — conventions reference
- `t3-templates.md` — four templates
- `t4-plan-skill.md` — /avanti:plan
- `t5-ticket-skill.md` — /avanti:ticket
- `t6-adr-skill.md` — /avanti:adr
- `t7-promote-skill.md` — /avanti:promote
- `t8-pulse-skill.md` — /avanti:pulse
- `t9-status-skill.md` — /avanti:status
- `t10-audit-skill.md` — /avanti:audit + wire contract
- `t11-readme-thresholds.md` — README + thresholds reference
- `t12-dogfood-records.md` — this file

### ADRs

- `project/adrs/002-avanti-scope-and-model.md` — records the scope decision (avanti = SDLC work layer, sibling to pronto, inside quickstop), alternatives considered (bundle into pronto, separate repo, defer to Phase 2), and rationale.
- `project/adrs/003-lifecycle-state-machine.md` — records the folder-as-primary-with-frontmatter-mirror decision and why ADRs diverge into frontmatter-as-primary with a flat folder. Alternatives considered: frontmatter-only, folder-only, branch-based, external tracker.

Both land at `status: accepted`. Rationale: these decisions are already baked into the Phase 1 plan that Alfred reviewed through Q1-Q5 and the polish commits (4d8cd32, e9d4db2, 41fef8c). The `proposed → accepted` transition happens during author-to-reviewer handoff, which for these ADRs happened during plan review; recording them as accepted reflects that.

Numbers 002 and 003 per the plan's guidance: "if pronto's ADR 001 has already landed by then, yours are 002 and 003." Avoids collision with pronto's in-flight `001-meta-orchestrator-model.md` whether pronto's PR merges first or second.

### Pulse

`project/pulse/2026-04-21.md` spans all twelve T-tickets with a `## HH:MM` entry per landing. Hand-authored throughout — the `/avanti:pulse` skill requires a live Claude Code session to run; A1 is where it gets exercised against a fresh repo. Bootstrap note visible in the T8 entry.

## Acceptance

- All 12 ticket records filed in `project/tickets/closed/`. ✓
- Two ADRs filed in `project/adrs/` at `status: accepted`. ✓
- `project/pulse/2026-04-21.md` has entries spanning T1-T12. ✓
- Plan (`project/plans/active/phase-1-avanti.md`) remains active; stays there until A-bars pass and `/avanti:promote plan:phase-1-avanti` moves it to done/. ✓
- No author-specific strings anywhere under `plugins/avanti/` (grep confirmed). ✓

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- ADRs: `project/adrs/002-avanti-scope-and-model.md`, `project/adrs/003-lifecycle-state-machine.md`
