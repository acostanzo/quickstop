---
id: t4
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T4 — /avanti:plan skill

## Context

The first authoring skill. Drafts a new plan from `templates/plan.md` into `project/plans/active/<slug>.md`, then walks the user through an interactive pass over the frontmatter and pivot paragraph. Refuses to overwrite existing files anywhere under `project/plans/`.

## What landed

`plugins/avanti/skills/plan/SKILL.md` — slash-command skill with standard avanti-skill frontmatter. Four phases:

- **Phase 0** — parse + validate: kebab-case slug, repo-root resolution via `git rev-parse`, collision check via Glob against `project/plans/*/<slug>.md` (covers draft/active/done), presence check on `project/plans/active/` with pointer to `/pronto:init` if missing.
- **Phase 1** — interactive authoring: AskUserQuestion for title, phase number, pivot paragraph; `date +%Y-%m-%d` for `updated:`.
- **Phase 2** — render + write: simple placeholder substitution, Write to target path, intact TODO sections for model/tickets/A-bars/DoD.
- **Phase 3** — report + next-step pointers.

Error handling covers slug-validation retries, write failures (with cleanup), and missing kernel scaffold (no auto-create — kernel is pronto's domain).

## Acceptance

- SKILL.md frontmatter is complete and well-formed (verified by inspection).
- Logic refuses to overwrite existing plans anywhere under `project/plans/`.
- Collision error message names the existing path.
- No author-specific strings (verified).

Functional acceptance — that `/avanti:plan foo-feature` produces a valid file, re-run errors clearly — is exercised in A1.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md`
- Template: `plugins/avanti/templates/plan.md`
