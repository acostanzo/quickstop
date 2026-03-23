# Skill Specification Baseline

Canonical reference for Claude Code skill, agent, and hook authoring. Used by skillet's research agent as a starting point before fetching live docs.

## Official Documentation URLs

| Topic | URL |
|-------|-----|
| Skills | https://docs.anthropic.com/en/docs/claude-code/skills |
| Sub-agents | https://docs.anthropic.com/en/docs/claude-code/sub-agents |
| Hooks | https://docs.anthropic.com/en/docs/claude-code/hooks |
| Plugins | https://docs.anthropic.com/en/docs/claude-code/plugins |

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
| `name` | Yes | Skill identifier, must match directory name |
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
maxTurns: 30                            # Optional — limit agent iterations
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
| `maxTurns` | No | Maximum number of tool-use turns before the agent stops |

### Agent Body

Full instruction prompt. Supports the same variable substitution as skills.

## hooks.json Schema

```json
{
  "hooks": {
    "<EventType>": [
      {
        "matcher": "ToolName",
        "command": "shell command",
        "timeout": 30000
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

## Skill Directory Structure

Inside a skill directory, only SKILL.md and references/ are allowed:

```
<skill-name>/
├── SKILL.md              # REQUIRED
└── references/           # OPTIONAL — heavy content loaded on demand
    └── *.md
```

Agents, hooks, and scripts live at the parent level (plugin root or `.claude/`):
- Agents: `agents/<name>.md`
- Hooks: `hooks/hooks.json`
- Scripts: `scripts/*.sh`

## Key Rules

1. SKILL.md is the only required file in a skill directory
2. `references/` is the only allowed subdirectory
3. No empty directories — only create what has content
4. kebab-case everywhere
5. Agent `name` in frontmatter should match filename (without .md)
6. Skill `name` in frontmatter should match directory name
