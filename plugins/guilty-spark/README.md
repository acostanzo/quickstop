# Guilty Spark

> "I am 343 Guilty Spark, the Monitor of Installation 04."

Proactive documentation management for Claude Code projects. Guilty Spark maintains living documentation that tracks features, architecture, and design decisions through an intelligent, conversation-aware approach.

## Philosophy

- **Code as source of truth** - Documentation references and validates against actual code
- **Proactive awareness** - The Monitor suggests documentation at natural pause points
- **User in control** - Documentation happens when you ask, not silently in the background
- **Atomic commits** - Documentation commits are separate from code commits
- **Current state only** - Git history is the changelog; docs show what exists now

## Installation

```bash
/plugin install guilty-spark@quickstop
```

## Documentation Structure

Guilty Spark maintains documentation in `docs/`:

```
docs/
├── INDEX.md              # Main entry point
├── architecture/
│   ├── OVERVIEW.md       # System design + key decisions
│   └── components/       # Component documentation
└── features/
    ├── INDEX.md          # Feature inventory
    └── [feature-name]/   # Per-feature documentation
```

## How It Works

### Session Initialization

On session start, Guilty Spark:
- Creates `docs/` directory if missing
- Reports staleness warnings if docs are >7 days old

### The Monitor Skill (Proactive)

The Monitor is conversation-aware and will:
- Track significant work being done (features, architecture decisions)
- Suggest documentation at natural pause points
- Offer to capture docs before you switch to new work

You're always in control - The Monitor suggests, you decide.

### Explicit Documentation

Ask Claude directly:

- "Document this feature" → Dispatches Sentinel-Feature
- "Update architecture docs" → Dispatches Sentinel-Architecture
- "How does X work?" → Dispatches Sentinel-Research for deep analysis
- "What's documented?" → Navigates existing documentation

### Checkpoint Command

Use `/guilty-spark:checkpoint` to capture documentation:
- Before running `/clear`
- At the end of a work session
- When switching to a different feature

### Pre-Commit Reminder

When Claude runs a `git commit` command via the Bash tool, Guilty Spark displays a reminder to consider documentation. Use `/guilty-spark:checkpoint` or say "document this" if needed.

### Sentinels

Sentinels are autonomous agents that maintain documentation:

| Sentinel | Purpose |
|----------|---------|
| **Sentinel-Feature** | Documents features, updates feature index |
| **Sentinel-Index** | Keeps INDEX.md files current |
| **Sentinel-Architecture** | Analyzes and documents system design |
| **Sentinel-Research** | Deep codebase research for questions |

Sentinels run in the background so you can continue working.

## Commands

| Command | Description |
|---------|-------------|
| `/guilty-spark:checkpoint` | Capture documentation for current session work |
| `/guilty-spark:doctor` | Verify plugin setup and documentation health |

## Atomic Commits

Documentation is always committed separately from code:

- Sentinels check for staged code changes before committing
- If code is staged, docs changes wait (you commit when ready)
- Commit messages use `docs(spark):` prefix

Example commit:
```
docs(spark): Document authentication feature
```

## Best Practices

1. **Use checkpoints** - Run `/guilty-spark:checkpoint` before `/clear` or ending your session
2. **Follow the prompts** - When The Monitor suggests documentation, it's usually a good time
3. **Review periodically** - Run `/guilty-spark:doctor` to check documentation health
4. **Trust the Sentinels** - They validate code references and keep docs current

## Requirements

- Git repository (documentation is tracked and committed)
- Claude Code with plugin support

## The Halo Theme

| Halo Concept | Plugin Component |
|--------------|------------------|
| **343 Guilty Spark** | The Monitor skill |
| **The Library** | `docs/` folder |
| **Sentinels** | Autonomous agents |
| **Containment** | Atomic commits |

## v2.0.0 Changes

This version redesigns the plugin architecture:

- **Removed**: SessionEnd and UserPromptSubmit hooks (they couldn't dispatch agents)
- **Added**: Proactive Monitor skill that suggests documentation during conversation
- **Added**: `/guilty-spark:checkpoint` command for explicit documentation capture
- **Added**: Pre-commit reminder hook
- **Changed**: From "autonomous background capture" to "proactive suggestion with user control"

## License

MIT
