# Quickstop

A Claude Code plugin marketplace.

## Plugins

### Claudit (v1.0.0)

Audit and optimize Claude Code configurations with dynamic best-practice research.

- Research-first architecture: subagents fetch official Anthropic docs before analysis
- Over-engineering detection as highest-weighted scoring category
- 6-category health scoring with interactive fix selection
- Persistent memory on research agents for faster subsequent runs

**Command:** `/claudit` — run a comprehensive configuration audit

## Installation

### From Marketplace

Add quickstop as a plugin marketplace, then install:

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install claudit@quickstop
```

### From Source

```bash
git clone https://github.com/acostanzo/quickstop.git
claude --plugin-dir /path/to/quickstop/plugins/claudit
```

## Documentation

See the [Claude Code plugin documentation](https://docs.anthropic.com/en/docs/claude-code/plugins) for plugin authoring and marketplace details.

## License

MIT
