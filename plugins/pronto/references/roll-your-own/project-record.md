# Roll Your Own — Project Record

How to achieve the `project-record` dimension's readiness without installing `avanti`.

Avanti (Phase 1b) owns authoring and lifecycle for this dimension. This document is the manual equivalent — the filesystem conventions avanti operationalizes.

## What "good" looks like

A `project/` directory at the repo root, containing four subdirs:

| Subdir | Contents | Lifecycle states |
|---|---|---|
| `plans/` | Per-initiative plans — one md file per initiative | draft → active → done (via `draft/`, `active/`, `done/` subfolders) |
| `tickets/` | Units of work scoped to a plan | open → in-progress → closed (via `open/`, `closed/`) |
| `adrs/` | Architecture decision records | proposed → accepted → superseded (flat dir; status in frontmatter) |
| `pulse/` | Append-only daily journal | one file per day: `YYYY-MM-DD.md` |

## Minimum viable setup

```bash
mkdir -p project/{plans/{draft,active,done},tickets/{open,closed},adrs,pulse}
touch project/plans/.gitkeep project/tickets/.gitkeep project/adrs/.gitkeep project/pulse/.gitkeep
```

Then write `project/README.md` explaining the four subdirs and the lifecycle rules (see the seed at `plugins/pronto/templates/project/README.md` for a ready-to-drop version).

## Frontmatter conventions

**Plan** — `project/plans/active/<slug>.md`:

```yaml
---
phase: 1
status: draft|active|done
tickets: [t1, t2, ...]
updated: YYYY-MM-DD
---
```

**Ticket** — `project/tickets/open/<id>-<slug>.md`:

```yaml
---
id: t1
plan: <plan-slug>
status: open|in-progress|closed
updated: YYYY-MM-DD
---
```

**ADR** — `project/adrs/<NNN>-<slug>.md` (zero-padded, flat):

```yaml
---
id: 002
status: proposed|accepted|superseded
superseded_by: null
updated: YYYY-MM-DD
---
```

**Pulse entries** — `project/pulse/YYYY-MM-DD.md` — per-day file, entries append as `## HH:MM` sub-headers. No per-entry frontmatter.

## Folder-as-primary rule

For plans and tickets, the **folder** is the authoritative state; frontmatter `status:` mirrors. Promotion moves files between folders and updates frontmatter atomically. Hand-promotion works fine — `git mv` + frontmatter edit in one commit.

ADRs are flat (status in frontmatter only) because the numeric sequence is the primary index and most ADRs end at `accepted` and stay there — folder-shuffling is churn for a state that rarely changes.

## Periodic audit checklist

- Every active plan touched in the last 60 days? Stale plans suggest drift.
- Every open ticket has a linked plan that's still `active`? Orphaned tickets are red flags.
- Every proposed ADR either moved forward or explicitly kept as `proposed` with rationale?
- Last pulse entry in the last 30 days? Longer gap suggests the repo lost its rhythm.

## Common anti-patterns

- **Plans in issue trackers instead of in-repo.** Issues drift; repos don't. Keep the plan of record in `project/plans/`.
- **Standalone tickets.** Every ticket should belong to a plan. If work doesn't justify a one-paragraph plan, it doesn't justify a ticket.
- **Monolithic CHANGELOG instead of pulse.** Pulse is journal, not release notes. Release notes live in towncrier / `CHANGELOG.md`. They have different shapes and cadences.
- **ADRs that retro-document after the fact.** ADRs authored concurrently with the decision carry real tradeoffs. Retro-ADRs tend to sanitize.

## Presence check pronto uses

Pronto's kernel presence check for this dimension passes if `project/` exists AND contains all four subdirs (`plans/`, `tickets/`, `adrs/`, `pulse/`). Presence-cap is 50 until avanti ships or a hand-audit runs.

## Concrete first step

Run `/pronto:init` if you haven't — it scaffolds `project/` with the correct layout, seed README, and `.gitkeep` placeholders in one pass. If you prefer hand-authoring, the `mkdir -p` line in Minimum Viable Setup above gets you to presence-cap:50 in a single commit.
