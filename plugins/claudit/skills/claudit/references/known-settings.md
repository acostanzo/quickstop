# Known Claude Code Settings & Configuration Reference

Static baseline derived from Anthropic's official Claude Code documentation. Research agents should fetch the latest docs and update their persistent memory with any changes.

## Official Documentation URLs

Research agents should fetch these pages to build expert context:

| Topic | URL |
|-------|-----|
| Settings | `https://docs.anthropic.com/en/docs/claude-code/settings` |
| Permissions | `https://docs.anthropic.com/en/docs/claude-code/permissions` |
| Memory & CLAUDE.md | `https://docs.anthropic.com/en/docs/claude-code/memory` |
| Best Practices | `https://docs.anthropic.com/en/docs/claude-code/best-practices` |
| MCP Servers | `https://docs.anthropic.com/en/docs/claude-code/mcp-servers` |
| Hooks | `https://docs.anthropic.com/en/docs/claude-code/hooks` |
| Skills | `https://docs.anthropic.com/en/docs/claude-code/skills` |
| Sub-agents | `https://docs.anthropic.com/en/docs/claude-code/sub-agents` |
| Plugins | `https://docs.anthropic.com/en/docs/claude-code/plugins` |
| Model Configuration | `https://docs.anthropic.com/en/docs/claude-code/model-configuration` |
| CLI Reference | `https://docs.anthropic.com/en/docs/claude-code/cli-reference` |

## settings.json Known Fields

Global settings (`~/.claude/settings.json`):

| Field | Type | Description |
|-------|------|-------------|
| `enabledPlugins` | string[] | Plugin paths or marketplace references |
| `permissions` | object | Global permission overrides |
| `model` | string | Default model selection |
| `smallModelOverride` | string | Override for haiku-class tasks |
| `apiKey` | string | API key (should NOT be in settings) |

Project settings (`.claude/settings.local.json`):

| Field | Type | Description |
|-------|------|-------------|
| `permissions` | object | Project-level permission rules |
| `allowedTools` | string[] | Tools allowed without confirmation |
| `deniedTools` | string[] | Tools that are blocked |
| `hooks` | object | Project-level hooks |

## Permission System

### Permission Modes

| Mode | Description |
|------|-------------|
| `default` | Ask for each tool use |
| `plan` | Auto-approve reads, ask for writes |
| `auto-edit` | Auto-approve file edits, ask for bash |
| `full-auto` | Auto-approve everything (use with caution) |

### Permission Pattern Formats

```
# Tool-level
"allowedTools": ["Read", "Glob", "Grep"]

# Tool with path constraints
"allowedTools": ["Edit:/src/**", "Write:/src/**"]

# Bash with command patterns
"allowedTools": ["Bash(npm test)", "Bash(git status)"]

# MCP tool patterns
"allowedTools": ["mcp__servername__toolname"]
```

### Common Anti-Patterns

- Dozens of granular `Bash(...)` rules when `auto-edit` mode would suffice
- Duplicating allow rules that a higher permission mode already covers
- Mixing `allowedTools` with a permission mode that already grants those tools

## CLAUDE.md Configuration

### Recommended Structure

A well-structured CLAUDE.md should be concise and include:

1. **Project context** - What the project is and its key technology stack
2. **Repository structure** - Brief directory layout
3. **Key conventions** - Only project-specific conventions Claude wouldn't know
4. **Build/test commands** - How to build, test, lint
5. **Important patterns** - Architectural patterns specific to this codebase

### Size Guidelines

| Size | Assessment |
|------|------------|
| < 500 tokens | Lean and effective |
| 500-1500 tokens | Good, comprehensive |
| 1500-2500 tokens | Getting verbose, review for redundancy |
| 2500+ tokens | Likely over-engineered, active performance cost |

### Common Over-Engineering Patterns

- Restating Claude's built-in behaviors ("always read files before editing")
- Prescribing exact formatting rules Claude already follows
- Long lists of "do not" instructions for things Claude wouldn't do
- Duplicating information available in package.json, tsconfig, etc.
- Embedding full API documentation instead of pointing to files
- Adding instructions that fight Claude's natural coding style

## Hooks Configuration

### Event Types

| Event | When It Fires |
|-------|---------------|
| `PreToolUse` | Before any tool is called |
| `PostToolUse` | After any tool returns |
| `Notification` | When Claude sends a notification |
| `Stop` | When Claude finishes a response |
| `SubagentStop` | When a subagent completes |
| `SessionStart` | At the beginning of a session |

### Hook Schema

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolName",
        "command": "shell command",
        "timeout": 10000
      }
    ]
  }
}
```

### Common Anti-Patterns

- Hooks that duplicate built-in Claude Code behavior
- Overly broad matchers that fire on every tool call
- Hooks with no timeout (can hang the session)
- Chains of hooks that could be a single script

## MCP Server Configuration

### Schema (.mcp.json)

```json
{
  "mcpServers": {
    "server-name": {
      "command": "binary",
      "args": ["arg1", "arg2"],
      "env": { "KEY": "value" }
    }
  }
}
```

### Health Indicators

- Command binary exists and is executable
- Server responds to tool listing
- Tools are actually used (not just configured)
- No duplicate functionality across servers

## Plugin Structure (Current Standard)

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json         # Required: name, version, description
├── agents/                  # Subagents (YAML frontmatter + markdown)
│   └── agent-name.md
├── skills/                  # Skills (current standard, replaces commands/)
│   └── skill-name/
│       ├── SKILL.md         # Skill definition
│       └── references/      # Supporting files
├── hooks/
│   └── hooks.json           # Event hooks
├── .mcp.json                # MCP server config
└── README.md
```

### Subagent Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Agent identifier |
| `description` | Yes | What the agent does (include examples) |
| `tools` | Yes | List of tools the agent can use |
| `model` | No | `inherit`, `haiku`, `sonnet`, `opus` |
| `memory` | No | `user` (persists across sessions) or `project` |
| `color` | No | Terminal color for output |

### Skill Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier |
| `description` | Yes | Trigger phrases and purpose |
| `disable-model-invocation` | No | Prevent auto-triggering (true for deliberate actions) |
| `allowed-tools` | No | Tools the skill can use |
| `context` | No | Additional context files to load |
| `agent` | No | Default agent for the skill |

### Legacy vs Current

| Legacy | Current | Migration |
|--------|---------|-----------|
| `commands/` directory | `skills/` directory | Move .md to skills/name/SKILL.md |
| Simple markdown commands | YAML frontmatter skills | Add frontmatter with name, description |
| No tool restrictions | `allowed-tools` field | Specify needed tools |
