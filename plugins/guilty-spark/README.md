# Guilty Spark

> "I am 343 Guilty Spark, the Monitor of Installation 04."

Autonomous documentation management for Claude Code projects. Guilty Spark maintains living documentation that tracks features, architecture, and design decisions with minimal user intervention.

## Philosophy

- **Code as source of truth** - Documentation references and validates against actual code
- **Asynchronous operation** - Background agents prevent context window bloat
- **Minimal interruption** - Hooks trigger silently; user only interacts when needed
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

### Automatic Capture

Guilty Spark automatically captures documentation at two key moments:

1. **Session End** - When you exit Claude Code, Guilty Spark analyzes the session for documentation-worthy work
2. **Before /clear** - When you clear context, Guilty Spark captures first to preserve knowledge

If meaningful work was done (new features, architecture decisions), a Sentinel is dispatched in the background to update documentation.

### The Monitor Skill

Ask Claude about documentation and The Monitor skill activates:

- "Document this feature" → Dispatches Sentinel-Feature
- "Update architecture docs" → Dispatches Sentinel-Architecture
- "How does X work?" → Dispatches Sentinel-Research (The Consultant)
- "What's documented?" → Navigates existing documentation

### Sentinels

Sentinels are autonomous agents that maintain documentation:

| Sentinel | Purpose |
|----------|---------|
| **Sentinel-Feature** | Documents features, updates feature index |
| **Sentinel-Index** | Keeps INDEX.md files current |
| **Sentinel-Architecture** | Analyzes and documents system design |
| **Sentinel-Research** | Deep codebase research for questions |

## Commands

| Command | Description |
|---------|-------------|
| `/spark:doctor` | Verify plugin setup and documentation health |

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

1. **Let it work** - Guilty Spark captures automatically; manual intervention is optional
2. **Answer questions** - When asked about features, the captured docs make research faster
3. **Review periodically** - Run `/spark:doctor` to check documentation health
4. **Trust the process** - Sentinels validate code references and keep docs current

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

## License

MIT
