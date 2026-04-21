---
id: t9
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T9 — /avanti:status skill

## Context

The at-a-glance read of what's in flight. Counts active plans, open tickets (broken down by `open` vs `in-progress` via frontmatter), proposed ADRs, and the latest pulse entry. Two-line summary by default; `--verbose` expands to a full ranked dump.

## What landed

`plugins/avanti/skills/status/SKILL.md` — three phases:

- **Phase 0** — parse + locate: `--verbose` flag; repo root; early exit on missing `project/` with pointer to `/pronto:init`.
- **Phase 1** — gather: globs for `plans/active/*`, `tickets/open/*`, `adrs/*` (filter to proposed), and `pulse/*` (lexicographic max = most recent ISO date). Frontmatter reads for status/updated/plan/id. `git log -1 --format=%cI` for last-touched; frontmatter `updated:` fallback for uncommitted files.
- **Phase 2** — render: two-line summary with empty-state variants; verbose listing sorted by "most relevant first" per category (plans by last-touched desc; tickets by age desc so stale ones surface; ADRs by id asc). `(none)` shown for empty categories rather than omitting them.

Error handling: malformed frontmatter doesn't crash — bad files listed in a `MALFORMED (N):` section in verbose output.

## Acceptance

- Skill frontmatter complete and well-formed.
- Empty-state reports without error (no exceptions on zero active plans, zero open tickets, zero ADRs, or zero pulse files).
- Two-line default + `--verbose` full dump.
- Malformed files surface but don't break the scan.
- No author-specific strings.

Functional acceptance (populated and empty project/ both produce coherent output) exercised in A1/A2 fixtures.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md`
