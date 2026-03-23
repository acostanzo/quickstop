# Quickstop

A Claude Code plugin marketplace.

## Plugins

### Bifrost (v1.0.0)

Memory system for AI agents — capture, consolidate, and recall knowledge across sessions and machines.

- Automatic memory injection at session start, transcript capture at session end
- Two-agent consolidation pipeline (extractor + consolidator) via `/heimdall`
- Progressive memory search via `/odin` — quick grep first, deep agent search if needed
- Feedback loop prevention — hooks skip when session is inside the memory repo

**Commands:** `/setup`, `/status`, `/heimdall`, `/odin <topic>`

### Commventional (v1.1.0)

Enforce conventional commits, conventional comments, and engineering ownership for commits, PRs, and code reviews.

- Passive auto-invocation — activates on commit, PR, and review context without explicit commands
- Sub-agent architecture: commit-crafter for diffs, review-formatter for feedback
- Three conventions: conventional commits, conventional comments, engineering ownership
- Reference specs bundled for consistent enforcement

**Auto-invokes on:** commits, pull requests, code reviews

### Claudit (v2.2.0)

Audit and optimize Claude Code configurations with dynamic best-practice research.

- Research-first architecture: subagents fetch official Anthropic docs before analysis
- Over-engineering detection as highest-weighted scoring category
- 6-category health scoring with interactive fix selection
- Persistent memory on research agents for faster subsequent runs

**Command:** `/claudit` — run a comprehensive configuration audit

### Skillet (v0.1.1)

Build, audit, and improve Claude Code skills with research-first architecture and opinionated structure.

- Research-first: fetches latest Anthropic skill/agent docs before every action
- Three workflows: build from scratch, audit existing, improve from findings
- Opinionated directory template enforcement for consistent skill structure
- 6-category scoring rubric specific to skill quality

**Commands:** `/skillet:build <name>`, `/skillet:audit <path>`, `/skillet:improve <path>`

## Dev Tools

Repo-level skills for plugin authors (not distributable plugins — these live in `.claude/`):

| Command | Purpose |
|---------|---------|
| `/smith <name>` | Scaffold a new plugin with correct structure and conventions |
| `/hone <name>` | Audit an existing plugin's quality (8-category scoring with interactive fixes) |

Both tools dispatch research agents to fetch the latest Anthropic plugin docs before operating, ensuring scaffolds and audits reflect the current spec.

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
