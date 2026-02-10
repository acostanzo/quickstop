# Claudit

Audit and optimize your Claude Code configuration with dynamic best-practice research.

## What It Does

Claudit performs a comprehensive, research-backed audit of your Claude Code setup. It first builds expert knowledge from Anthropic's official documentation, then evaluates your configuration against that knowledge — identifying issues, over-engineering, and features you're not using yet.

### Key Innovations

- **Research-first architecture**: Subagents fetch official Anthropic docs before analysis begins, ensuring the audit knows the full landscape of what's possible — not just what you already have configured
- **Over-engineering detection**: Identifies where configuration complexity actively hurts performance. Claude does the heavy lifting; verbose CLAUDE.md files, excessive hooks, and MCP sprawl get in the way
- **Persistent memory**: Research agents remember findings across audit runs, getting faster and more accurate over time

## Usage

```
/claudit
```

The audit runs through 4 phases:

1. **Build Expert Context** — 3 research agents fetch official Anthropic documentation in parallel
2. **Expert-Informed Audit** — 3 audit agents analyze your global, project, and ecosystem config against expert knowledge
3. **Scoring & Synthesis** — 6 categories scored with visual health report and ranked recommendations
4. **Interactive Enhancement** — Select which recommendations to apply; changes implemented with before/after scoring

## What Gets Analyzed

### Global Configuration (`~/.claude/`)
- `settings.json` — settings fields, model config, enabled plugins
- `installed_plugins.json` — plugin versions, install paths, health
- User-level CLAUDE.md and MEMORY.md

### Project Configuration (`.claude/`, `CLAUDE.md`)
- `CLAUDE.md` — deep analysis for size, structure, over-engineering, stale references, secrets
- `settings.local.json` — permission rules, tool restrictions
- Project-level agents, skills, and memory

### Ecosystem
- MCP servers — binary health, duplicate functionality, context cost
- Plugins — structure, legacy patterns, version currency
- Hooks — event types, matchers, timeouts, redundancy

## Scoring System

| Category | Weight | What It Measures |
|----------|--------|------------------|
| Over-Engineering Detection | 20% | Unnecessary complexity, verbosity, redundancy |
| CLAUDE.md Quality | 20% | Structure, conciseness, relevance, token efficiency |
| Security Posture | 15% | Permission hygiene, secrets exposure |
| MCP Configuration | 15% | Server health, tool sprawl |
| Plugin Health | 15% | Version currency, structure patterns |
| Context Efficiency | 15% | Token budget, memory usage, config bloat |

### Grades

| Grade | Score | Label |
|-------|-------|-------|
| A+ | 95-100 | Exceptional |
| A | 90-94 | Excellent |
| B | 75-89 | Good |
| C | 60-74 | Fair |
| D | 40-59 | Needs Work |
| F | 0-39 | Critical |

## Persistent Memory

Research agents use `memory: user` to persist findings across runs. The first audit fetches all documentation from scratch. Subsequent runs consult cached knowledge and only update what may have changed — making them faster and more accurate over time.

## Requirements

- Claude Code CLI
- Internet access (for Phase 1 documentation fetching)

## Installation

From the quickstop marketplace:

```bash
/plugin install claudit@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/claudit
```
