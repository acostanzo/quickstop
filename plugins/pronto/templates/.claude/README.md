# .claude/

Claude Code local configuration for this repo. Hidden by convention.

## What lives here

| Subdir / file | Contents | Scope |
|---|---|---|
| `skills/<name>/SKILL.md` | Project-scoped skills (slash commands) | team |
| `agents/<name>.md` | Project-scoped subagents | team |
| `rules/<name>.md` | Modular CLAUDE.md-style rules loaded via path frontmatter | team |
| `settings.json` | Project settings (permissions, env, hooks, MCP) | team (committed) |
| `settings.local.json` | Personal overrides | personal (gitignored) |
| `MEMORY.md` | Project memory | team |

## See also

- Claude Code configuration reference: https://docs.anthropic.com/en/docs/claude-code
- `/claudit` — audit Claude Code config health (install from the quickstop marketplace)
