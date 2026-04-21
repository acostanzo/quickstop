# SDLC Conventions

The canonical reference for avanti's lifecycle model — folder layout, state machines, frontmatter schemas, and transition semantics. Consumer repos and authors read this once and never again.

## The model in one paragraph

Every SDLC artifact lives under `project/` in the consumer repo. Three artifact types — **plans**, **tickets**, **ADRs** — each drive through their own state machine. A fourth artifact type — **pulse** — is an append-only journal, not a stateful artifact. The folder a file lives in is the authoritative state; frontmatter `status:` mirrors the folder for machine-readability. Avanti's skills (`/avanti:plan`, `/avanti:ticket`, `/avanti:adr`, `/avanti:promote`, `/avanti:pulse`) read and write these conventions; `/avanti:audit` measures how well the repo keeps to them.

## Folder layout

After `/pronto:init` scaffolds the container and avanti starts filling it:

```
project/
├── plans/
│   ├── draft/          # plans that landed but aren't ready to execute
│   ├── active/         # plans of record — zero or more in flight
│   └── done/           # terminal — every ticket closed, all A-bars pass
├── tickets/
│   ├── open/           # authored; includes both not-started and in-progress
│   └── closed/         # terminal
├── adrs/               # flat — ADRs stay in place; status in frontmatter
│   ├── 001-<slug>.md
│   ├── 002-<slug>.md
│   └── …
└── pulse/
    ├── 2026-04-21.md   # one file per calendar day, append-only
    ├── 2026-04-22.md
    └── …
```

### Folder-as-primary

The directory a file sits in is the authoritative state. `status:` in frontmatter mirrors it for machine-readability but is never the source of truth except for ADRs (where the folder is flat). `/avanti:promote` moves files between folders and updates frontmatter atomically; hand-editing `status:` without moving the file is a convention violation the audit flags.

### Why ADRs are flat

The ADR ecosystem in wide use — MADR, ADR-tools, Log4Brains — keeps ADRs in a single flat directory indexed by sequence number. Avanti follows that convention:

1. The numeric sequence (`001-…`, `002-…`) is the primary index and is meaningful in its own right (chronological, citable).
2. Most ADRs end at `accepted` and stay there — folder-shuffling would be churn for a state that rarely changes.
3. Supersession is explicit via frontmatter cross-link (`superseded_by: 007`) rather than a move.

For ADRs, `status:` in frontmatter **is** authoritative.

## State machines

### Plan: `draft → active → done`

| State | Meaning | Folder |
|---|---|---|
| `draft` | Landed but not ready to execute. Rare — the PR is usually the draft surface. | `plans/draft/` |
| `active` | Plan of record. Adopted; execution may or may not have begun. | `plans/active/` |
| `done` | Every ticket closed and acceptance bars pass. Terminal. | `plans/done/` |

**"Active" is not "currently executing."** A plan is `active` the moment it is adopted. Execution granularity is tracked at the ticket level (`open` / `in-progress` / `closed`), not by promoting the plan itself back and forth. A plan only leaves `active` when every ticket it owns is closed and its acceptance bars pass, at which point it moves to `done`.

Legal transitions:

```
draft → active
active → done
```

Reverse moves are blocked. If a plan needs rework after promotion, author a new plan.

### Ticket: `open → in-progress → closed`

| State | Meaning | Folder |
|---|---|---|
| `open` | Authored; not yet started. | `tickets/open/` |
| `in-progress` | Work underway. Folder does not change. | `tickets/open/` |
| `closed` | Done. | `tickets/closed/` |

**Open and in-progress share a folder.** The distinction lives in frontmatter `status:`. The folder transition happens only at `closed`. This keeps merge surfaces narrow and matches how tickets actually flow — most open tickets pass through in-progress briefly and the folder move would be churn.

Legal transitions:

```
open → in-progress
in-progress → closed
open → closed        # directly, for trivial closes
```

### ADR: `proposed → accepted → superseded`

| State | Meaning | Frontmatter |
|---|---|---|
| `proposed` | Decision under review. Folder is flat. | `status: proposed` |
| `accepted` | Decision ratified. Folder is flat. | `status: accepted` |
| `superseded` | Replaced by a later ADR. Folder is flat; the superseding ADR is linked. | `status: superseded`, `superseded_by: <id>` |

Legal transitions:

```
proposed → accepted
accepted → superseded   # requires --supersedes <id> pointing to the new ADR
```

Supersession is always one-directional: the old ADR records `superseded_by: <new>`; the new ADR may optionally record `supersedes: <old>`. `/avanti:promote` sets both automatically when invoked with `--supersedes`.

## Frontmatter schemas

### Plan

```yaml
---
phase: 1                            # integer — broad execution phase
status: draft|active|done
tickets: [t1, t2, …]                # plan-scoped ticket IDs; optional until tickets land
updated: YYYY-MM-DD
---
```

Required fields: `phase`, `status`, `updated`. `tickets:` is optional on draft plans; required on active/done plans once tickets have been minted.

### Ticket

```yaml
---
id: t1                              # plan-scoped identifier
plan: <plan-slug>                   # slug of the containing plan (required)
status: open|in-progress|closed
updated: YYYY-MM-DD
---
```

All fields required. `plan:` is what makes the ticket plan-scoped — standalone tickets are not supported.

### ADR

```yaml
---
id: 002                             # zero-padded, repo-wide sequence
status: proposed|accepted|superseded
superseded_by: null                 # or another ADR id (e.g., "007")
updated: YYYY-MM-DD
---
```

Required: `id`, `status`, `updated`. `superseded_by:` is `null` until supersession happens.

### Pulse

**Pulse entries carry no per-entry frontmatter.** Each day-file has a one-line date header followed by entries:

```markdown
# Pulse — YYYY-MM-DD

## HH:MM

<entry body — one paragraph, free-form markdown>

## HH:MM

<next entry>
```

Timestamps are 24-hour local time. Entries append below the header; earlier entries are never edited.

## Where each artifact lives

| Artifact | Default path | Created by |
|---|---|---|
| Plan | `project/plans/<state>/<slug>.md` | `/avanti:plan <slug>` |
| Ticket | `project/tickets/<state>/<id>-<slug>.md` | `/avanti:ticket <slug> --plan <plan-slug>` |
| ADR | `project/adrs/<NNN>-<slug>.md` | `/avanti:adr <slug>` |
| Pulse day-file | `project/pulse/YYYY-MM-DD.md` | `/avanti:pulse <message>` on first call of the day |

## Promotion semantics

`/avanti:promote <artifact>` resolves current state from folder + frontmatter, proposes the next legal transition, and on confirmation:

1. For plans and tickets: moves the file to the new folder.
2. Updates frontmatter `status:` to match.
3. Bumps frontmatter `updated:` to today.
4. For ADRs: updates frontmatter only (folder is flat). With `--supersedes <id>`, cross-links both ADRs.
5. Appends a pulse entry noting the transition (timestamped, free-form, mentions the artifact and new state).

Illegal transitions (e.g., `done → draft`, promoting a closed ticket, accepting an already-accepted ADR without supersession) error clearly with the legal-transition set.

### Artifact shortcuts

`/avanti:promote` accepts either a full path or a shortcut:

- `plan:<slug>` → resolves to the plan at `project/plans/*/<slug>.md`
- `ticket:<id-slug>` → resolves to the ticket at `project/tickets/*/<id-slug>.md`
- `adr:<NNN-slug>` → resolves to the ADR at `project/adrs/<NNN-slug>.md`

## Pulse structure

One file per calendar day. Filename is `YYYY-MM-DD.md` (ISO date). Each day-file is append-only:

- First invocation of a day creates the file from `templates/pulse-day.md`.
- Subsequent invocations append a new `## HH:MM` section plus the entry body.
- Prior entries are never edited — `/avanti:pulse` has no `--edit` mode.

**Why per-day files?** Per-day files:

- Scope merge conflicts to agents pulsing on the same day.
- Scale indefinitely without growing any single file.
- Match the append-only journal pattern in wide use elsewhere.

**What goes in pulse?** Terse notes about what happened — ticket transitions, plan promotions, decisions, blockers, handoffs. Not a replacement for commit messages or plan bodies; a running log of what the humans and agents working this repo are thinking.

## Plan-scoped ticket IDs

Ticket IDs are plan-scoped, not repo-global. Every plan has its own `t1`, `t2`, … sequence. When `/avanti:ticket <slug> --plan <plan-slug>` runs:

1. It reads the plan's frontmatter `tickets:` array.
2. Mints the next unused ID in the sequence (first is `t1`; if `[t1, t2, t3]` is present, next is `t4`).
3. Appends the new ID to the plan's `tickets:` array.
4. Writes the ticket file at `project/tickets/open/<id>-<slug>.md` with `plan: <plan-slug>` in frontmatter.

**Why plan-scoped?** Ticket IDs are meaningful only in the context of their plan. Repo-global IDs (like `proj-142`) devolve into issue-tracker keys; plan-scoped IDs keep the ticket anchored to the work they execute.

## Tool state

Phase 1 ships no persistent tool state. The `.avanti/` directory is reserved — mirroring pronto's `.pronto/` pattern — for future needs (cached audit results, per-repo config overrides). If it lands, it follows the same rules: hidden, tool-named, git-committable or git-ignored per need, never user-authored content.

## Common pitfalls

- **Hand-editing `status:` without moving the file.** The audit flags this as a folder/frontmatter mismatch. Use `/avanti:promote` instead.
- **Standalone tickets.** `/avanti:ticket` requires `--plan`. If work doesn't justify a plan, it doesn't justify a ticket.
- **Reusing ADR numbers.** ADR numbers are repo-wide and monotonic. Superseded ADRs keep their original number; the superseding ADR takes the next unused number.
- **Editing past pulse entries.** Pulse is append-only. Corrections go in a new timestamped entry referencing the earlier one.
- **Skipping pulse entries at transitions.** `/avanti:promote` appends one automatically. If you do a manual promotion, add a pulse entry by hand.

## Audit thresholds

What counts as stale, orphaned, or cadence-breaking is configurable — see `audit-thresholds.md` for the knobs and defaults. Phase 1 ships lenient defaults (60-day stale plans, 30-day pulse-cadence warning) and expects consumers to tighten once usage data accumulates.
