---
id: t7
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T7 — /avanti:promote skill

## Context

The single lifecycle-transition skill. Drives plans, tickets, and ADRs forward through their legal state transitions. Moves files between folders for plans/tickets, updates frontmatter atomically, appends a pulse entry recording the transition. Supports ADR supersession via `--supersedes <id>`.

## What landed

`plugins/avanti/skills/promote/SKILL.md` — five phases:

- **Phase 0** — parse + resolve: accept full path, absolute path, or shortcut (`plan:<slug>`, `ticket:<id-slug>`, `adr:<NNN-slug>`). Glob under repo root; zero/multiple matches error clearly.
- **Phase 1** — determine current state and next transition: folder is authoritative for plans/tickets (frontmatter distinguishes `open` vs `in-progress` inside `tickets/open/`); frontmatter is authoritative for ADRs. Legal-transition table codified. `open → {in-progress, closed}` ambiguity resolved via AskUserQuestion. Terminal states error explicitly. ADR supersede requires `--supersedes <id>`.
- **Phase 2** — confirm: show proposed transition and request user confirmation; decline aborts cleanly.
- **Phase 3** — execute: plans and tickets `mv` between folders with frontmatter edits; ADRs frontmatter-only; supersession sets `superseded_by` on old and `supersedes` on new.
- **Phase 4** — pulse the transition via `/avanti:pulse` (bootstrap fallback: append directly).
- **Phase 5** — report.

Error handling covers missing artifacts, terminal states, folder/frontmatter mismatch (pause + surface), missing supersede target, and move failure (best-effort frontmatter revert).

## Acceptance

- Skill frontmatter complete and well-formed.
- Legal-transition table matches conventions reference.
- Supports all three artifact types + shortcuts.
- Pulse-on-transition is explicit.
- No author-specific strings.

Functional acceptance (round-trip draft → active → done, ADR supersession cross-link, illegal transitions error) exercised in A2.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md` (state machines + promotion semantics)
