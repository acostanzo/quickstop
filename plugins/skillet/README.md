# Skillet

Build, audit, and improve Claude Code skills with research-first architecture and opinionated structure.

## Features

- **Research-first**: fetches latest Anthropic skill/agent/hook docs before every action
- **Three workflows**: build from scratch, audit existing, improve from findings
- **Opinionated directory template**: enforces consistent skill structure
- **6-category scoring rubric**: specific to skill quality assessment

## Commands

### `/skillet:build <name>`

Scaffold a new skill with correct structure, frontmatter, and phase organization.

- Gathers requirements (agents, hooks, references, tools)
- Presents a blueprint for approval before creating any files
- Creates SKILL.md, agents, hooks, and references following the directory template
- Includes TODO markers for domain-specific logic

### `/skillet:audit <path>`

Audit an existing skill's quality with a 6-category scoring rubric.

- Discovers all related files (SKILL.md, agents, hooks, references)
- Dispatches a research agent for latest spec, then an audit agent for analysis
- Scores across: Frontmatter, Instruction Quality, Agent Design, Directory Structure, Over-Engineering, Reference & Tooling
- Offers interactive fix selection with before/after score delta

### `/skillet:improve <path>`

Improve a skill using audit findings or manual direction.

- Bridges audit results to implementation
- Can run a fresh audit or accept manual improvement descriptions
- Presents an improvement plan for approval
- Re-scores affected categories after changes

## Architecture

```
plugins/skillet/
├── .claude-plugin/plugin.json          # Plugin metadata
├── skills/
│   ├── build/SKILL.md                  # Build orchestrator (5 phases)
│   ├── audit/
│   │   ├── SKILL.md                    # Audit orchestrator (4 phases)
│   │   └── references/scoring-rubric.md
│   └── improve/SKILL.md               # Improve orchestrator (4 phases)
├── agents/
│   ├── research-skill-spec.md          # haiku — fetches latest Anthropic docs
│   └── audit-skill.md                  # inherit — reads and grades skill files
└── references/
    ├── skill-spec-baseline.md          # Baseline skill/agent/hook spec
    └── directory-template.md           # Opinionated directory structure
```

## Installation

### From Marketplace

```bash
/plugin install skillet@quickstop
```

### From Source

```bash
claude --plugin-dir /path/to/quickstop/plugins/skillet
```

## License

MIT
