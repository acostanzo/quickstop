# Avanti

SDLC in markdown — plans, tickets, ADRs, and a pulse journal — no Jira required.

Avanti authors and maintains the records under `project/` in your repo and drives each one through its lifecycle. Plans live under `project/plans/<state>/`, tickets under `project/tickets/<state>/`, ADRs at `project/adrs/`, and the pulse journal at `project/pulse/<date>.md`. The folder a record sits in is its authoritative state; promotions move files and update frontmatter atomically.

## Quick start

```bash
/plugin install avanti@quickstop

/avanti:plan my-new-initiative                                 # scaffold a plan
/avanti:ticket first-deliverable --plan my-new-initiative      # plan-scoped ticket
/avanti:pulse "kicked off my-new-initiative"                   # journal entry
```

## Skills

| Command | Purpose |
|---|---|
| `/avanti:plan <slug>` | Draft a new plan into `project/plans/active/`. |
| `/avanti:ticket <slug> --plan <plan-slug>` | Draft a plan-scoped ticket into `project/tickets/open/`. |
| `/avanti:adr <slug>` | Draft a new ADR into `project/adrs/`. |
| `/avanti:promote <artifact>` | Move an artifact forward through its lifecycle and record the transition in pulse. |
| `/avanti:pulse <message>` | Append a timestamped entry to today's pulse day-file. |
| `/avanti:status` | Summarize active plans, open tickets, proposed ADRs, and the latest pulse entry. Read-only. |

## Example wirings

### Drafting a new initiative

```bash
/avanti:plan my-new-initiative
/avanti:ticket first-deliverable --plan my-new-initiative
/avanti:pulse "kicked off my-new-initiative"
```

### Promoting work and recording it

```bash
/avanti:promote project/tickets/open/first-deliverable.md
/avanti:pulse "shipped first-deliverable"
```

## Plugin surface

Per ADR-006 §1, this plugin ships:

- **Skills (6):** `plan`, `ticket`, `adr`, `promote`, `pulse`, `status`.
- **Commands:** none (each skill is invoked via its `/avanti:<skill>` slash).
- **Hooks:** none. Per ADR-006 §3, the hook invariants are vacuously satisfied — avanti installs no Claude Code event hooks.
- **Opinions:** avanti owns the structure, naming, and lifecycle of records under `project/`. The folder layout (`project/plans/`, `project/tickets/`, `project/adrs/`, `project/pulse/`), frontmatter schemas, and promotion semantics are encoded in `references/sdlc-conventions.md` — they are avanti's stance on how an SDLC record should look, not consumer-configurable per invocation.

ADR-006 §2 conformance (no silent mutation of consumer artefacts): avanti does not mutate consumer state at plugin-install time. Every write avanti performs is the result of a slash command the consumer typed, scoped to the `project/` path the corresponding skill documents.

## References

- `references/sdlc-conventions.md` — lifecycle model, folder layout, frontmatter schemas, promotion semantics.

## Installation

From the quickstop marketplace:

```bash
/plugin install avanti@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/avanti
```
