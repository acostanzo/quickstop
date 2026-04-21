---
id: t6
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T6 — /avanti:adr skill

## Context

Third authoring skill. Drafts a new ADR from `templates/adr.md` into `project/adrs/<NNN>-<slug>.md` with `status: proposed`. Mints the next zero-padded repo-wide ADR number and walks the user through an interactive authoring pass over context, decision, and key consequences.

## What landed

`plugins/avanti/skills/adr/SKILL.md` — four phases:

- **Phase 0** — parse + validate: kebab-case slug, repo root, ADRs-dir presence, slug collision across existing ADRs.
- **Phase 1** — mint: scan `project/adrs/*.md`, extract leading numeric prefix from each filename, take max+1 zero-padded to 3 digits. Double-check no collision on the minted number.
- **Phase 2** — render + write: AskUserQuestion for title, context, decision statement, key consequences; fill placeholders; leave `status: proposed` / `superseded_by: null` / alternatives / remaining consequences for the author.
- **Phase 3** — report with promote pointer.

Error handling covers slug collision, number collision after mint, write failure (with cleanup), and missing scaffold.

## Acceptance

- Skill frontmatter complete and well-formed.
- Zero-padded 3-digit numbering (e.g., `003`).
- Default `status: proposed`, `superseded_by: null`.
- No collision with existing ADR numbers.
- No author-specific strings.

Functional acceptance exercised in A1 (correct file, frontmatter, number).

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md`
- Template: `plugins/avanti/templates/adr.md`
