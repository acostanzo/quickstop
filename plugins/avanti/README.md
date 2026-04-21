# Avanti

The SDLC work layer of the quickstop constellation.

Avanti authors and maintains the records under `project/` — plans, tickets, ADRs, and the pulse journal — and drives each record through its lifecycle (draft → active → done; open → closed; proposed → accepted → superseded). It is to `project/` what pronto is to the rubric: the plugin that owns the contents.

## Skills

| Command | Purpose |
|---|---|
| `/avanti:plan <slug>` | Draft a new plan |
| `/avanti:ticket <slug> --plan <plan-slug>` | Draft a plan-scoped ticket |
| `/avanti:adr <slug>` | Draft a new ADR |
| `/avanti:promote <artifact>` | Move an artifact forward through its lifecycle |
| `/avanti:pulse <message>` | Append a timestamped pulse entry |
| `/avanti:status` | Summarize active plans, open tickets, proposed ADRs, recent pulse |
| `/avanti:audit` | SDLC hygiene audit — emits pronto wire contract JSON |

## Conventions

See `references/sdlc-conventions.md` for the full lifecycle model, folder layout, and frontmatter schemas.

## Installation

From the quickstop marketplace:

```bash
/plugin install avanti@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/avanti
```
