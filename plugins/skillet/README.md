# Skillet

Build, audit, and improve Claude Code skills with research-first architecture and opinionated structure.

## Features

- **Research-first**: fetches latest Anthropic skill/agent/hook docs before every action
- **Three workflows**: build from scratch, audit existing, improve from findings
- **Opinionated directory template**: enforces consistent skill structure
- **6-category scoring rubric**: specific to skill quality assessment

## Plugin surface

Per ADR-006 §1, this plugin ships:

- **Skills (3):**
  - `build` — consumer-invoked. Scaffolds a new Claude Code skill from scratch with correct directory structure, frontmatter, and phase organization. Research-first: fetches the latest Anthropic skill/agent/hook docs before scaffolding, then presents a blueprint for approval before any file is written.
  - `audit` — consumer-invoked. Audits an existing skill's quality with a 6-category scoring rubric (Frontmatter, Instruction Quality, Agent Design, Directory Structure, Over-Engineering, Reference & Tooling). Read-only by default; only writes if the consumer accepts an interactive fix.
  - `improve` — consumer-invoked. Improves an existing skill using audit findings or manual direction; presents an improvement plan for approval, then re-scores affected categories after applying changes.
- **Commands:** none (each skill is invoked via its `/skillet:<skill>` slash).
- **Agents (2):**
  - `research-skill-spec` — fetches official Anthropic skill / agent / hook authoring documentation. Dispatched by `build` and `audit` to keep the spec baseline current. Runs on `haiku`.
  - `audit-skill` — reads and grades skill files against the scoring rubric. Dispatched by `audit`.
- **Hooks:** none. Per ADR-006 §3, the hook invariants are vacuously satisfied — skillet installs no Claude Code event hooks.
- **Opinions:** skillet enforces an opinionated directory template (`references/directory-template.md`) and a skill-quality scoring rubric (`skills/audit/references/scoring-rubric.md`). Both encode skillet's stance on what a well-shaped skill looks like and are not consumer-configurable per invocation. Writes happen only when the consumer accepts a scaffolding blueprint (`build`), an interactive fix (`audit`), or an improvement plan (`improve`); each phase pauses for explicit approval.

ADR-006 §2 conformance (no silent mutation of consumer artefacts): skillet does not mutate consumer state at plugin-install time. Every file write is the result of a slash command the consumer typed and a plan the consumer approved.

## Skills

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
