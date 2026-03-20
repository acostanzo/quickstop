# Commventional

Enforce conventional commits, conventional comments, and engineering ownership for commits, PRs, and code reviews.

## What It Does

Commventional is a passive plugin — it activates automatically when you create commits, open pull requests, or review code. No slash commands needed.

### Three Conventions

1. **Conventional Commits** — commit messages and PR titles follow the [conventional commits](https://www.conventionalcommits.org/) spec
2. **Conventional Comments** — code review feedback uses [conventional comments](https://conventionalcomments.org/) labels and format
3. **Engineering Ownership** — engineers own their code; no automated `Co-Authored-By` trailers for AI tooling

## How It Works

Two layers of enforcement:

1. **Hook (deterministic)** — a `PreToolUse` hook intercepts every `git commit` and `gh pr create` Bash call, removing automated `Co-Authored-By` trailers and "Generated with Claude Code" footers to enforce engineering ownership. Fires on every matching call regardless of skill activation.
2. **Skill (advisory)** — when Claude recognizes a commit/PR/review scenario, it dispatches specialized agents to craft properly formatted messages.

| Scenario | What Happens |
|----------|-------------|
| Any `git commit` or `gh pr create` | Hook enforces engineering ownership by removing automated attribution |
| You ask to commit | Dispatches `commit-crafter` agent to analyze staged diffs, determine commit type, and craft a conventional message |
| You ask to create a PR | Dispatches `commit-crafter` with the full branch diff to produce a conventional PR title and structured body |
| You review code | Dispatches `review-formatter` to format feedback using conventional comment labels |

## Installation

### From Marketplace

```bash
/plugin install commventional@quickstop
```

### From Source

```bash
claude --plugin-dir /path/to/quickstop/plugins/commventional
```

## Agents

| Agent | Role | Dispatched When |
|-------|------|----------------|
| `commit-crafter` | Analyzes diffs, crafts conventional commit messages and PR titles | Commits and PRs |
| `review-formatter` | Formats review feedback with conventional comment labels | Code reviews |

## Commit Types

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Restructuring without behavior change |
| `docs` | Documentation |
| `test` | Tests |
| `chore` | Maintenance |
| `style` | Formatting |
| `perf` | Performance |
| `ci` | CI/CD |
| `build` | Build system |

## Review Labels

| Label | Blocking? |
|-------|-----------|
| `praise` | No |
| `nitpick` | No |
| `suggestion` | No |
| `issue` | Yes |
| `question` | No |
| `thought` | No |
| `chore` | Yes |
| `typo` | Yes |

## Requirements

- Claude Code CLI
- `jq` (for hook JSON parsing)
