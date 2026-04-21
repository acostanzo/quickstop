# Avanti

The SDLC work layer of the quickstop constellation.

Avanti authors and maintains the records under `project/` — plans, tickets, ADRs, and the pulse journal — and drives each record through its lifecycle. It is to `project/` what pronto is to the rubric: the plugin that owns the contents.

## Skills

| Command | Purpose |
|---|---|
| `/avanti:plan <slug>` | Draft a new plan |
| `/avanti:ticket <slug> --plan <plan-slug>` | Draft a plan-scoped ticket |
| `/avanti:adr <slug>` | Draft a new ADR |
| `/avanti:promote <artifact>` | Promote an artifact to its next lifecycle state |
| `/avanti:pulse <message>` | Append a timestamped pulse entry |
| `/avanti:status` | Summarize plans, tickets, ADRs, and recent pulse |
| `/avanti:audit` | SDLC hygiene audit — emits pronto wire contract JSON under `--json` |

## References

- `references/sdlc-conventions.md` — lifecycle model, folder layout, frontmatter schemas, promotion semantics.
- `references/audit-thresholds.md` — tunable knobs for `/avanti:audit` with defaults and override mechanism.

## Installation

From the quickstop marketplace:

```bash
/plugin install avanti@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/avanti
```
