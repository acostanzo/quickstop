---
id: t5
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T5 — /avanti:ticket skill

## Context

Second authoring skill. Drafts a new plan-scoped ticket from the ticket template, mints the next monotonic ID from the containing plan's `tickets:` array, writes to `project/tickets/open/<id>-<slug>.md`, and updates the plan's frontmatter to include the new ID. Enforces the plan-scoped-only rule — no standalone tickets.

## What landed

`plugins/avanti/skills/ticket/SKILL.md` — five phases:

- **Phase 0** — parse + validate: `<slug> --plan <plan-slug>` argument form; hard-error if `--plan` missing; resolve plan via `project/plans/*/<plan-slug>.md` glob.
- **Phase 1** — mint: read plan's `tickets:`, parse integer suffixes, `NEW_ID = t${max+1}`. Collision guards on both NEW_ID file and slug-already-in-use.
- **Phase 2** — render + write: AskUserQuestion for title and context, fill placeholders, write to `open/`.
- **Phase 3** — update plan: Edit the plan's frontmatter to append NEW_ID to `tickets:` and bump `updated:` to today.
- **Phase 4** — report with promote pointer.

Error handling covers the missing-plan, missing-scaffold, slug-collision, and write-failure-after-edit cases (with best-effort rollback of the plan edit).

## Acceptance

- Skill frontmatter complete and well-formed.
- `--plan` is required; explicit error with usage pointer when missing.
- Non-existent plan errors with the slug named and pointer to `/avanti:plan`.
- Monotonic ID mint from plan's frontmatter array.
- Cross-folder collision detection on both ID and slug.
- No author-specific strings.

Functional acceptance exercised in A1 (correct file, frontmatter, plan cross-link).

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md`
- Template: `plugins/avanti/templates/ticket.md`
