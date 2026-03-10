# Commventional

Conventional commits, PR conventions, and conventional comments for Claude Code.

## What It Does

Commventional teaches Claude Code three conventions that make git history readable and code reviews actionable:

1. **Conventional Commits** — structured commit messages with semantic types
2. **PR Conventions** — consistent PR titles and descriptions
3. **Conventional Comments** — labeled review feedback with clear expectations

Rules inject at session start via a SessionStart hook. Project-level CLAUDE.md instructions take precedence if they define their own conventions.

## Conventions

### Conventional Commits

All commits follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) spec:

```
<type>[(scope)]: <description>

[optional body]

[optional footer(s)]
```

| Type | Use |
|------|-----|
| feat | New feature or capability |
| fix | Bug fix |
| docs | Documentation only |
| style | Formatting, no logic change |
| refactor | Restructuring without behavior change |
| perf | Performance improvement |
| test | Adding or updating tests |
| build | Build system or dependencies |
| ci | CI/CD configuration |
| chore | Maintenance, tooling, config |

Breaking changes use `!` suffix or `BREAKING CHANGE:` footer. No AI attribution lines.

### PR Conventions

PR titles follow conventional commit format. PR descriptions use a structured template with Summary, Changes, and Test plan sections.

### Conventional Comments

Review feedback uses the [Conventional Comments](https://conventionalcomments.org/) format:

```
<label> [decorations]: <subject>

[discussion]
```

| Label | Purpose |
|-------|---------|
| praise | Highlight something positive |
| nitpick | Trivial, preference-based |
| suggestion | Propose an improvement |
| issue | Problem that needs addressing |
| todo | Small, necessary change |
| question | Ask for clarification |
| thought | Observation, no action needed |
| chore | Maintenance task |
| note | Provide context |

Decorations: `(blocking)`, `(non-blocking)`, `(if-minor)`

## Commands

| Command | Description |
|---------|-------------|
| `/commit [message]` | Stage and commit with conventional format |
| `/pr [base-branch]` | Create PR with conventional title and structured description |
| `/review <pr>` | Review a PR using conventional comments |

## Installation

### From Marketplace

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install commventional@quickstop
```

### From Source

```bash
claude --plugin-dir /path/to/quickstop/plugins/commventional
```

## Requirements

- git
- gh (GitHub CLI) — for `/pr` and `/review`
- python3 — for JSON escaping in bootstrap hook
