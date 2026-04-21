---
id: t8
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T8 — /avanti:pulse skill

## Context

Append-only journal skill. Appends a timestamped entry to `project/pulse/YYYY-MM-DD.md`. Creates the day-file from `templates/pulse-day.md` on first invocation of the day. Never edits prior entries. Merge-friendly — different days touch different files.

## What landed

`plugins/avanti/skills/pulse/SKILL.md` — three phases:

- **Phase 0** — parse + locate: `$ARGUMENTS` is the entry body (AskUserQuestion fallback if empty); repo root via `git rev-parse`; `date +%Y-%m-%d` and `date +%H:%M` for the day-file path and entry timestamp.
- **Phase 1** — ensure day-file: glob/test for existing file; create from template with header-only (template's example entry stripped so real day-files contain only real entries) if missing.
- **Phase 2** — append: read current, build `## HH:MM\n\n<message>` block, write back. Preserve trailing whitespace.

Error handling: empty message aborts (no empty entries); missing pulse dir points to `/pronto:init` (no auto-create); duplicate HH:MM is allowed (two `## HH:MM` headers in a row is accurate, not an error).

## Acceptance

- Skill frontmatter complete and well-formed.
- First-of-day creates header-only day-file (not the template's example entry).
- Append-only: never edits prior content.
- Empty message aborts; no auto-create of pulse dir.
- No author-specific strings.

Functional acceptance exercised in A1 (first invocation creates day-file, second entry appends correctly).

## Notes

Bootstrap note: this ticket's pulse entry is hand-authored, since running the skill requires an interactive Claude Code session. Once A1 confirms the skill works on a live repo, it becomes the canonical surface for authoring pulse entries in consumer repos.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md#pulse-structure`
- Template: `plugins/avanti/templates/pulse-day.md`
