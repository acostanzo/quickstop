# Quick Reference: Plugin/Skill/Sub-agent Development

## Plugin Minimal Example

```bash
mkdir my-plugin/.claude-plugin
```

```json
# my-plugin/.claude-plugin/plugin.json
{
  "name": "my-plugin",
  "description": "Brief description",
  "version": "1.0.0"
}
```

```bash
mkdir -p my-plugin/skills/hello
```

```yaml
# my-plugin/skills/hello/SKILL.md
---
description: Greet the user
disable-model-invocation: true
---

Greet the user warmly.
```

```bash
claude --plugin-dir ./my-plugin
/my-plugin:hello
```

---

## Skill Minimal Example

```bash
mkdir -p ~/.claude/skills/my-skill
```

```yaml
# ~/.claude/skills/my-skill/SKILL.md
---
name: my-skill
description: Does something useful. Use when you need to...
---

Your instructions here. Use $ARGUMENTS for user input.
```

```bash
/my-skill some argument
```

---

## Sub-agent Minimal Example

```bash
mkdir -p ~/.claude/agents
```

```markdown
# ~/.claude/agents/my-agent.md
---
name: my-agent
description: Specialized for specific tasks
tools: Read, Grep, Glob, Bash
model: haiku
---

You are specialized in X. When invoked, do Y.
```

Restart Claude Code, then ask Claude to use it.

---

## Frontmatter Cheat Sheet

### SKILL.md
```yaml
---
name: skill-id                           # Optional (uses dir name)
description: "What it does"              # REQUIRED for auto-invoke
disable-model-invocation: true           # true = manual only
user-invocable: false                    # false = Claude-only
argument-hint: "[filename]"              # UI hint
allowed-tools: Read, Grep                # Restrict tools
model: sonnet                            # Override model
context: fork                            # Run in subagent
agent: Explore                           # Which subagent type
---
```

### Subagent .md
```yaml
---
name: agent-id                           # REQUIRED
description: "When to use"               # REQUIRED
tools: Read, Bash                        # Optional (inherit all)
disallowedTools: Write                   # Optional (deny list)
model: haiku                             # sonnet/opus/haiku/inherit
permissionMode: default                  # default/acceptEdits/dontAsk/bypassPermissions/plan
maxTurns: 10                             # Max agentic turns
skills: [api-conventions]                # Preload skills
memory: user                             # user/project/local
background: false                        # Run concurrent
isolation: worktree                      # Isolated git copy
---
```

---

## Variable Substitutions

### Skills & Subagents
```
$ARGUMENTS              → All user arguments
$0, $1, $2             → Specific arguments by position
${CLAUDE_SESSION_ID}   → Current session ID (logging)
${CLAUDE_SKILL_DIR}    → Path to skill directory
!`command`             → Inject command output (skills only)
```

---

## Tool Restrictions

```yaml
# Allowlist approach
allowed-tools: Read, Grep, Glob

# Denylist approach
disallowedTools: Write, Edit

# Restrict subagent spawning (subagents only)
tools: Agent(worker, researcher), Read, Bash
```

---

## Memory (Subagents Only)

```yaml
memory: user      # ~/.claude/agent-memory/<name>/MEMORY.md
memory: project   # .claude/agent-memory/<name>/MEMORY.md
memory: local     # .claude/agent-memory-local/<name>/MEMORY.md
```

**In subagent markdown body:**
```markdown
Review your agent memory to recall patterns from previous sessions.
After each task, update MEMORY.md with key findings.
```

---

## Hooks

### In Skills/Subagents (frontmatter)
```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      command: "./validate.sh"
  PostToolUse:
    - matcher: "Write|Edit"
      command: "./lint.sh"
```

### In Project settings.json (main session events)
```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "db-agent",
        "command": "./setup-db.sh"
      }
    ],
    "SubagentStop": [
      {
        "command": "./cleanup.sh"
      }
    ]
  }
}
```

---

## Testing

```bash
# Test plugin during development
claude --plugin-dir ./my-plugin

# Test skill
/skill-name arguments

# Test subagent
/agents                          # View all
# Ask Claude to use it

# Validate versions before pushing
./scripts/check-plugin-versions.sh

# Load multiple plugins
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two

# Define agents via CLI
claude --agents '{
  "agent-name": {
    "description": "...",
    "prompt": "You are...",
    "tools": ["Read", "Bash"],
    "model": "sonnet"
  }
}'
```

---

## Common Patterns

### Deploy Workflow (Manual Invocation)
```yaml
---
name: deploy
description: Deploy to production
disable-model-invocation: true
---

Deploy $ARGUMENTS to production:
1. Run tests
2. Build
3. Deploy
4. Verify
```

### Read-only Research (Auto-invoke)
```yaml
---
name: research-code
description: Research how code works. Use when exploring a codebase.
allowed-tools: Read, Grep, Glob
---

Research $ARGUMENTS thoroughly. Summarize findings.
```

### Specialized Agent
```markdown
---
name: api-reviewer
description: Review API design and contracts
tools: Read, Grep, Glob
model: sonnet
---

Review the API for design patterns, consistency, and best practices.
Check for:
- Naming conventions
- Error handling
- Security
```

### Learning Agent
```markdown
---
name: pattern-learner
description: Learn codebase patterns for this project
memory: project
---

Update your project memory with patterns, conventions, and key
architectural decisions you discover as you explore the code.
```

---

## Checklist Before Pushing Plugin

- [ ] Version bumped in `plugin.json`
- [ ] Version bumped in `marketplace.json`
- [ ] Version updated in `README.md`
- [ ] `.claude-plugin/plugin.json` contains all fields
- [ ] Skills in `skills/` directory (not `commands/`)
- [ ] All skills have `description` field
- [ ] Reference files documented in SKILL.md
- [ ] Tested locally with `--plugin-dir`
- [ ] Ran `./scripts/check-plugin-versions.sh`
- [ ] README has installation instructions
- [ ] Commit follows convention: `PluginName vX.Y.Z: Description`

---

## Priority Locations (higher wins)

**Skills:**
1. Plugin `skills/` (namespaced)
2. `.claude/skills/` (project)
3. `~/.claude/skills/` (user)
4. Enterprise managed

**Subagents:**
1. CLI `--agents` flag
2. `.claude/agents/` (project)
3. `~/.claude/agents/` (user)
4. Plugin `agents/`

---

## Built-in Subagents

| Name | Model | Tools | Use |
|------|-------|-------|-----|
| Explore | Haiku | Read-only | Fast search & analysis |
| Plan | Inherit | Read-only | Planning phase research |
| general-purpose | Inherit | All | Complex multi-step |
| Bash | Inherit | Bash | Terminal in isolation |

---

## Common Mistakes

❌ Put files in `.claude-plugin/` → Only put `plugin.json` there
❌ Forget to bump version → Users won't get updates
❌ Nested subagents → Subagents can't spawn other subagents
❌ Large SKILL.md → Keep under 500 lines, use reference files
❌ Vague descriptions → Claude won't know when to use it
❌ Reference files not documented → Claude won't load them

---

## Official Docs

- https://code.claude.com/docs/en/plugins — Create plugins
- https://code.claude.com/docs/en/skills — Skills
- https://code.claude.com/docs/en/sub-agents — Subagents
- https://code.claude.com/docs/en/plugins-reference — Complete specs
