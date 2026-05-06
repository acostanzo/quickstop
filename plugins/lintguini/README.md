# Lintguini

Audits lint-posture for Claude Code consumer repos: linter config strictness, formatter presence, CI lint enforcement, and rule-suppression count.

## Status — toolkit expansion in flight

Lintguini is expanding from a Pronto-sibling auditor into a full lint toolkit — `/lintguini:configure`, `/lintguini:lint`, `/lintguini:format`, `/lintguini:fix` — alongside the existing `/lintguini:audit`. The new skills and bin/ surface land milestone-by-milestone; today's shipped surface is still the audit only. Tracking plan: [`project/plans/active/lintguini-expansion.md`](../../project/plans/active/lintguini-expansion.md).

## Plugin surface

This plugin ships:
- Skills: `audit`
- Commands: none
- Agents: none
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

Emits a v2 wire-contract JSON envelope to stdout. The `observations[]` field
carries entries pronto's rubric translates into a dimension score.

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

1 skill (`audit`). No commands, no hooks, no MCP servers. Scorers and language-detection logic land in 2b2/2b3.

## Templates

Per-language config templates live under [`templates/`](templates/), one subdirectory per supported language (Python, JavaScript, TypeScript, Rust, Ruby, Go) with `strict`, `lenient`, and `minimal` band variants. The M2 `/lintguini:configure` skill projects these into consumer repos when it ships; today they are the published reference for what each band looks like.

The lint-posture rubric at [`plugins/pronto/references/roll-your-own/lint-posture.md`](../pronto/references/roll-your-own/lint-posture.md) is the source of truth — the templates are mechanical projections of it. ADR-008 (`project/adrs/008-lintguini-rubric-authority.md`) pins the contract: when the rubric and a template disagree, the rubric wins; the template is the bug.

A full README rewrite is held until the writer/runner surface (M3) lands and the README has more concrete behaviour to describe.

## License

MIT. See [LICENSE](LICENSE).
