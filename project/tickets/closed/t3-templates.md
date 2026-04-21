---
id: t3
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T3 — Templates

## Context

Authoring skills need shapes to copy from. Four templates cover every artifact type avanti owns: plans, tickets, ADRs, per-day pulse files. Templates must be minimal but complete — required frontmatter fields with obvious placeholders, body skeleton that prompts toward the right shape, portable (no author-specific strings).

## What landed

- `plugins/avanti/templates/plan.md` — frontmatter (phase/status/tickets/updated), pivot paragraph, model, tickets, acceptance bars, out-of-scope, DoD. Shape mirrors Phase 1 plans so the convention is self-dogfooding.
- `plugins/avanti/templates/ticket.md` — frontmatter (id/plan/status/updated), context, acceptance criteria, notes, links-to-plan.
- `plugins/avanti/templates/adr.md` — MADR-flavored: frontmatter (id/status/superseded_by/updated), context, decision, consequences (positive/negative/neutral), alternatives, links.
- `plugins/avanti/templates/pulse-day.md` — one-line date header + first-entry example with `## HH:MM` sub-header.

All placeholders use `TODO`, `TODO-DATE`, `TODO-TIME`, or `<…>` — unambiguous, greppable, never confusable with real content.

## Acceptance

- Frontmatter blocks in plan.md, ticket.md, adr.md all parse as simple key: value YAML (no quoting issues, `[]` and `null` used correctly).
- Placeholders are obvious (`TODO`, `<fill in>`, `<…>`).
- Grep for author-specific strings returns zero matches.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md`
