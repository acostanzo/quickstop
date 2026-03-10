# Plugin Specification Baseline

Canonical reference for Quickstop plugin structure. Used by both `/smith` (scaffolding) and `/hone` (auditing).

## Official Documentation URLs

| Topic | URL |
|-------|-----|
| Plugins | https://docs.anthropic.com/en/docs/claude-code/plugins |
| Skills | https://docs.anthropic.com/en/docs/claude-code/skills |
| Sub-agents | https://docs.anthropic.com/en/docs/claude-code/sub-agents |
| Hooks | https://docs.anthropic.com/en/docs/claude-code/hooks |
| MCP Servers | https://docs.anthropic.com/en/docs/claude-code/mcp |

## Required Plugin Directory Structure

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json          # REQUIRED — plugin metadata
├── skills/                  # Skills (preferred over commands/)
│   └── <skill-name>/
│       ├── SKILL.md         # Skill definition with frontmatter
│       └── references/      # Optional reference files loaded on demand
│           └── *.md
├── agents/                  # Sub-agent definitions
│   └── <agent-name>.md     # Agent with frontmatter
├── hooks/                   # Event hooks
│   └── hooks.json           # Hook definitions
├── .mcp.json                # MCP server config (if needed)
└── README.md                # Plugin documentation
```

### Legacy Structure (deprecated)

```
commands/           # DEPRECATED — migrate to skills/
  └── <name>.md     # Old slash command format
```

## plugin.json Schema

```json
{
  "name": "plugin-name",           // REQUIRED — kebab-case identifier
  "version": "1.0.0",             // REQUIRED — semver
  "description": "Brief desc",    // REQUIRED — shown in marketplace
  "author": {                     // Recommended
    "name": "Author Name",
    "url": "https://example.com"
  }
}
```

## SKILL.md Frontmatter Schema

```yaml
---
name: skill-name                        # REQUIRED — matches directory name
description: What this skill does       # REQUIRED — used for model auto-invocation
disable-model-invocation: true          # Optional — prevents auto-invocation, requires explicit /command
argument-hint: arg-name                 # Optional — hint shown in /command completion
allowed-tools: Tool1, Tool2            # Optional — restricts available tools
---
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier, matches directory name |
| `description` | Yes | Natural language description; used for LLM matching unless disabled |
| `disable-model-invocation` | No | `true` prevents auto-invocation; skill only runs via explicit `/name` |
| `argument-hint` | No | Placeholder text shown after `/name` in completion UI |
| `allowed-tools` | No | Comma-separated tool list; restricts what tools the skill can use |

### Skill Body

The body after frontmatter is the full instruction prompt. It supports:
- `$ARGUMENTS` — substituted with user-provided arguments
- `${SKILL_ROOT}` — resolves to the skill's directory path
- `${CLAUDE_PLUGIN_ROOT}` — resolves to the plugin root directory
- Reference files in `references/` subdirectory — loaded on demand, not always in context

## Agent .md Frontmatter Schema

```yaml
---
name: agent-name                        # REQUIRED
description: "What this agent does"     # REQUIRED
tools:                                  # REQUIRED — list of available tools
  - Read
  - Glob
  - Grep
model: haiku                            # Optional — haiku, sonnet, opus, inherit
memory: user                            # Optional — user (persistent) or project
---
```

### Agent Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Agent identifier |
| `description` | Yes | Description shown in agent registry; used for `subagent_type` matching |
| `tools` | Yes | List of tools the agent can access |
| `model` | No | Model to use: `haiku` (fast/cheap), `sonnet`, `opus`, `inherit` (parent's model) |
| `memory` | No | `user` = persistent across sessions; `project` = project-scoped; omit = no memory |

### Agent Body

Full instruction prompt. Supports the same variable substitution as skills.

## hooks.json Schema

```json
{
  "hooks": {
    "<EventType>": [
      {
        "matcher": "ToolName",           // Optional — filter by tool name (PreToolUse/PostToolUse only)
        "command": "shell command",      // REQUIRED — shell command to execute
        "timeout": 30000                 // Recommended — timeout in ms (default varies by event)
      }
    ]
  }
}
```

### Hook Event Types

| Event | Matcher | Fires When |
|-------|---------|------------|
| `PreToolUse` | tool name | Before a tool is called |
| `PostToolUse` | tool name | After a tool returns |
| `Notification` | notification type | On notifications |
| `Stop` | — | When agent stops |
| `SubagentStop` | — | When a subagent stops |
| `SessionStart` | — | At session initialization |

### Hook Output Handling

- stdout → shown to Claude as context
- stderr → shown to user in terminal
- Exit code 0 → proceed
- Exit code 2 → block the action (PreToolUse only)

## .mcp.json Schema

```json
{
  "mcpServers": {
    "server-name": {
      "command": "binary",
      "args": ["arg1", "arg2"],
      "env": {
        "KEY": "value"
      }
    }
  }
}
```

## Marketplace Registration

Entry in quickstop's `.claude-plugin/marketplace.json`:

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief description",
  "source": "./plugins/plugin-name",
  "keywords": ["keyword1", "keyword2"]
}
```

## Quickstop Conventions

### Version Consistency

Three files must have matching versions:
1. `plugins/<name>/.claude-plugin/plugin.json`
2. `.claude-plugin/marketplace.json`
3. `README.md`

Run `./scripts/check-plugin-versions.sh` before pushing.

### Commit Format

```
PluginName vX.Y.Z: Brief description

- Change 1
- Change 2
```

### Testing

```bash
claude --plugin-dir /path/to/quickstop/plugins/plugin-name
```

### Naming

- Plugin names: kebab-case
- Skill directories: match skill name
- Agent files: kebab-case.md
- Hook files: always `hooks.json`
