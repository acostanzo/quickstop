# Quickstop

A Claude Code plugin marketplace.

## Plugins

### Bifrost (v1.2.0)

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

### Claudit (v2.6.0)

Audit and optimize Claude Code configurations with dynamic best-practice research.

- Research-first architecture: subagents fetch official Anthropic docs before analysis
- **Knowledge cache**: research results cached at `~/.cache/claudit/` with version-based + 7-day TTL invalidation
- **Knowledge skill**: `/claudit:knowledge` exposes cached research to other plugins — auto-refreshes stale domains
- **Decision memory**: stores audit decisions so future runs annotate recommendations with past context (team-shared, committable)
- Over-engineering detection as highest-weighted scoring category
- 6-category health scoring with interactive fix selection
- Persistent memory on research agents for faster subsequent runs
- Cross-tool synergy: cached knowledge speeds up skillet, smith, and hone

**Commands:** `/claudit` — run audit, `/claudit:refresh` — refresh cache, `/claudit:status` — show cache state, `/claudit:knowledge` — retrieve cached research

### Skillet (v0.2.1)

Build, audit, and improve Claude Code skills with research-first architecture and opinionated structure.

- Research-first: fetches latest Anthropic skill/agent docs before every action
- **Claudit cache integration**: uses claudit's cached ecosystem knowledge when available, falls back to own research
- Three workflows: build from scratch, audit existing, improve from findings
- Opinionated directory template enforcement for consistent skill structure
- 6-category scoring rubric specific to skill quality

**Commands:** `/skillet:build <name>`, `/skillet:audit <path>`, `/skillet:improve <path>`

### Inkwell (v0.3.4)

Automatic documentation-as-code engine. Maintains project documentation as a side effect of development — config-driven, no manual invocation needed.

- Config-driven: `.inkwell.json` controls all detection patterns and output paths — no hardcoded assumptions
- `/inkwell:prime` setup wizard detects your stack and generates config with sensible defaults
- Queue-based architecture: PostToolUse hook reads config, matches changes, queues doc tasks
- Automatic changelog, API reference, architecture, api-contract, env-config, and domain-scaffold generation
- Architecture Decision Records (ADRs) with auto-numbering and index updates
- Staleness detection — finds docs that are out of date relative to source code changes
- Bundled `code-comments` rule enforces meaningful comments across source files

**Commands:** `/inkwell:prime`, `/inkwell:capture`, `/inkwell:adr <title>`, `/inkwell:changelog`, `/inkwell:index`, `/inkwell:stale`

## Dev Tools

Repo-level skills for plugin authors (not distributable plugins — these live in `.claude/`):

| Command | Purpose |
|---------|---------|
| `/smith <name>` | Scaffold a new plugin with correct structure and conventions |
| `/hone <name>` | Audit an existing plugin's quality (8-category scoring with interactive fixes) |

Both tools dispatch research agents to fetch the latest Anthropic plugin docs before operating, ensuring scaffolds and audits reflect the current spec.

## Using Claudit's Knowledge Cache

If you're building a plugin or skill that needs Claude Code ecosystem knowledge (plugin specs, skill authoring, MCP, hooks), you can consume claudit's cached research instead of fetching docs yourself.

### Available Domains

| Domain | Content |
|--------|---------|
| `ecosystem` | Plugin system, skills, agents, hooks, MCP servers |
| `core-config` | Settings, permissions, CLAUDE.md, memory system |
| `optimization` | Performance patterns, over-engineering detection |

### Consumer Pattern

In your skill's research phase, invoke the knowledge skill and fall back to your own research if claudit isn't installed:

```markdown
### Step 1: Load Expert Context

Invoke `/claudit:knowledge ecosystem` to retrieve ecosystem knowledge.

**If the skill runs successfully** (outputs `=== CLAUDIT KNOWLEDGE: ecosystem ===` block):
- Use its output as Expert Context
- Also read your own domain-specific supplement for depth
- Skip research phase

**If the skill is not available** (claudit not installed — the invocation produces an error, is not recognized as a command, or produces no knowledge output):
- Fall back to your own research agents
```

The knowledge skill checks cache freshness and auto-refreshes stale domains transparently. Your plugin doesn't need to understand the cache protocol — just invoke and use the output.

Output is wrapped in delimiters for easy identification:

```
=== CLAUDIT KNOWLEDGE: ecosystem ===
[cached research content]
=== END CLAUDIT KNOWLEDGE ===

Knowledge source: cache (fresh, fetched 2026-03-22) | Domains: ecosystem
```

### Refreshing the Cache

Users can manually refresh with `/claudit:refresh [domain|all]` or check status with `/claudit:status`. The cache auto-refreshes on any `/claudit` or `/claudit:knowledge` invocation when stale.

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
