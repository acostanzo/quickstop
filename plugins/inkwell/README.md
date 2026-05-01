# Inkwell

Audits code-documentation depth for Claude Code consumer repos: README quality, docs coverage, staleness, and internal link health.

## Plugin surface

This plugin ships:
- Skills: `audit`
- Commands: none
- Agents: `parse-inkwell` (transitional, per ADR-005 §5)
- Hooks: none
- Opinions: none

This plugin does not ship: cross-plugin automation, consumer config edits, or any
flow that silently mutates artefacts the consumer owns. Consumers compose automation
against this plugin's capabilities per ADR-006 §6.

## What this sibling audits

This plugin audits the **Code documentation** dimension of pronto's readiness rubric.

## Standalone invocation

```bash
/inkwell:audit --json
```

Emits a v2 wire-contract JSON envelope to stdout. The `observations[]` field
carries entries pronto's rubric translates into a dimension score.

## Pronto handshake

This plugin declares `compatible_pronto: ">=0.3.0"` in `plugin.json`.
Pronto checks this at dispatch time — if the installed pronto is outside the declared
range, pronto skips this sibling's audit and scores the dimension by presence only.

## Installation

### From marketplace

```bash
/plugin install inkwell@quickstop
```

### From source

```bash
claude --plugin-dir /path/to/quickstop/plugins/inkwell
```

## Architecture

1 skill (`audit`), 1 transitional parser agent (`parse-inkwell`). No commands, no hooks, no MCP servers. The 2a1 scaffold emits an empty `observations[]` envelope; the four deterministic shell scorers (README quality, docs coverage, staleness, internal link health) and the rubric stanza land in 2a2/2a3.

## License

MIT. See [LICENSE](LICENSE).
