# Avanti

The SDLC work layer of the quickstop constellation.

Avanti authors and maintains the records under `project/` — plans, tickets, ADRs, and the pulse journal — and drives each record through its lifecycle. It is to `project/` what pronto is to the rubric: the plugin that owns the contents.

## Plugin surface

Per ADR-006 §1, this plugin ships:

- **Skills (7):**
  - `plan` — drafts a new plan from the avanti template into `project/plans/active/`.
  - `ticket` — drafts a new plan-scoped ticket from the avanti template into `project/tickets/open/`. Requires `--plan <plan-slug>`.
  - `adr` — drafts a new ADR from the avanti template into `project/adrs/`.
  - `promote` — moves a plan, ticket, or ADR forward through its lifecycle (e.g. `active` → `closed`, `proposed` → `accepted`, supersession) and records the transition as a pulse entry.
  - `pulse` — appends a timestamped entry to today's pulse day-file under `project/pulse/`.
  - `status` — summarizes active plans, open tickets, proposed ADRs, and the latest pulse entry. Read-only.
  - `audit` — scores SDLC hygiene across plan freshness, ticket hygiene, ADR completeness, and pulse cadence against thresholds from `references/audit-thresholds.md`. Default output is a markdown scorecard; with `--json`, emits the pronto wire-contract JSON on stdout for sibling composition.
- **Commands:** none (each skill is invoked via its `/avanti:<skill>` slash).
- **Hooks:** none. Per ADR-006 §3, the hook invariants are vacuously satisfied — avanti installs no Claude Code event hooks.
- **Opinions:** avanti owns the structure, naming, and lifecycle of records under `project/`. The folder layout (`project/plans/`, `project/tickets/`, `project/adrs/`, `project/pulse/`), frontmatter schemas, promotion semantics, and audit thresholds are encoded in `references/sdlc-conventions.md` and `references/audit-thresholds.md` — they are avanti's stance on how an SDLC record should look, not consumer-configurable per invocation. The `audit` skill emits a pronto-compatible wire contract under `--json` (declared via the `pronto` block in `plugin.json`); pronto consumes it for the `project-record` audit dimension.

ADR-006 §2 conformance (no silent mutation of consumer artefacts): avanti does not mutate consumer state at plugin-install time. Every write avanti performs is the result of a slash command the consumer typed, scoped to the `project/` path the corresponding skill documents.

## Example wirings

Per ADR-006 §6, capabilities ship without triggers; the consumer composes them. Common sequences:

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

### SDLC hygiene check

```bash
/avanti:audit              # human-readable scorecard, on demand
/avanti:audit --json       # pronto wire contract for sibling consumption
```

When both pronto and avanti are installed, pronto consumes `/avanti:audit --json` automatically for its `project-record` dimension — no additional consumer wiring needed for that path. Periodic audits (nightly, pre-release, on `SessionStart`) are the consumer's to schedule.

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
