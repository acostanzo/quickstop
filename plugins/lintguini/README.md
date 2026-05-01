# Lintguini

Audits lint-posture for Claude Code consumer repos: linter config strictness, formatter presence, CI lint enforcement, and rule-suppression count.

## Plugin surface

This plugin ships:
- Skills: `audit`
- Commands: none
- Agents: `parse-lintguini` (transitional, per ADR-005 §5)
- Hooks: none
- Opinions: none

This plugin does not ship: cross-plugin automation, consumer config edits, or any
flow that silently mutates artefacts the consumer owns. Consumers compose automation
against this plugin's capabilities per ADR-006 §6.

## What this sibling audits

This plugin audits the **Lint / format / language rules** dimension of pronto's readiness rubric.

## Standalone invocation

```bash
/lintguini:audit --json
```

Emits a v2 wire-contract JSON envelope to stdout. The `data` field contains
observations pronto's rubric translates into a dimension score.

## Pronto handshake

This plugin declares `compatible_pronto: ">=0.2.0"` in `plugin.json`.
Pronto checks this at dispatch time — if the installed pronto is outside the declared
range, pronto skips this sibling's audit and scores the dimension by presence only.

## Installation

### From marketplace

```bash
/plugin install lintguini@quickstop
```

### From source

```bash
claude --plugin-dir /path/to/quickstop/plugins/lintguini
```

## Architecture

1 skill (`audit`), 1 transitional parser agent (`parse-lintguini`). No commands, no hooks, no MCP servers. Scorers and language-detection logic land in 2b2/2b3.

## License

MIT. See [LICENSE](LICENSE).
