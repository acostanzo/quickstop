# project/

SDLC records for this repo. Content-named folder; plugin-agnostic.

## Layout

| Subdir | Contents | Lifecycle |
|---|---|---|
| `plans/` | Per-initiative plans. Folder-as-primary state: `draft/`, `active/`, `done/`. Frontmatter `status:` mirrors. | draft → active → done |
| `tickets/` | Units of work scoped to a plan. IDs mint plan-scoped (`t1`, `t2`, ...). Folders: `open/`, `closed/`. | open → in-progress → closed |
| `adrs/` | Architecture decision records. Flat directory; numeric zero-padded sequence; status in frontmatter. | proposed → accepted → superseded |
| `pulse/` | Append-only journal. One file per day: `YYYY-MM-DD.md`. Entries are `## HH:MM`-headed blocks. | N/A |

## Folder-as-primary rule

For plans and tickets, the **folder** the file lives in is the authoritative state. The frontmatter `status:` field mirrors for machine-readability. Promoting an artifact moves the file between folders and updates frontmatter atomically.

ADRs are flat — the numeric sequence is the primary index, and the `status:` field is authoritative because most ADRs end at `accepted` and stay there (folder-shuffling is churn for a state that rarely changes).

## Frontmatter envelopes

**Plan:**
```yaml
---
phase: 1
status: draft|active|done
tickets: [t1, t2, ...]
updated: YYYY-MM-DD
---
```

**Ticket:**
```yaml
---
id: t1
plan: <plan-slug>
status: open|in-progress|closed
updated: YYYY-MM-DD
---
```

**ADR:**
```yaml
---
id: 002
status: proposed|accepted|superseded
superseded_by: null
updated: YYYY-MM-DD
---
```

**Pulse entries:** no per-entry frontmatter. Day file header is one line; entries append below with `## HH:MM` sub-headers.

## Authoring

This folder is the **content** surface. The `avanti` plugin owns its authoring and lifecycle (`/avanti:plan`, `/avanti:ticket`, `/avanti:adr`, `/avanti:promote`, `/avanti:pulse`). If avanti is not installed, files here are fully human-authorable by hand — the conventions above are filesystem-level, not plugin-specific.

## See also

- `../AGENTS.md` — the agent-facing map of this repo.
