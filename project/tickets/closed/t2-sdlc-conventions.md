---
id: t2
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T2 — SDLC conventions reference

## Context

The canonical doc consumers read to understand avanti's lifecycle model. Needs to cover state machines per artifact type, folder-as-primary, frontmatter schemas, where each artifact lives, `/avanti:promote` semantics, per-day pulse structure. Portable, no author strings, under ~400 lines.

## What landed

`plugins/avanti/references/sdlc-conventions.md` — 231 lines, covers:

- One-paragraph model
- Folder layout tree with commentary on folder-as-primary and flat ADRs
- State machines for plans, tickets, ADRs (tables + legal-transition lists)
- Frontmatter schemas for all four artifact types (plans, tickets, ADRs, pulse)
- Where each artifact lives (path + creating skill)
- Promotion semantics — what `/avanti:promote` does atomically, artifact shortcuts
- Pulse structure — why per-day, what goes in, append-only discipline
- Plan-scoped ticket IDs — why not repo-global
- Tool state (`.avanti/` reserved, nothing persistent in Phase 1)
- Common pitfalls for consumers
- Pointer to `audit-thresholds.md` (T11)

README already links to it (landed in T1 stub).

## Acceptance

- Doc exists ✓
- Linked from README ✓
- Portable — grep for author strings returns zero matches ✓
- Under ~400 lines (231) ✓

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Ticket prior: `t1-scaffold-avanti.md`
