# What's New/Changed: Plugin/Skill/Sub-agent Updates (March 2026)

This document highlights changes from the baseline specification to official Anthropic documentation (March 2026).

---

## Documentation Migration

**Change:** Official docs moved from `docs.anthropic.com` to `code.claude.com`

- Old: `https://docs.anthropic.com/en/docs/claude-code/plugins`
- New: `https://code.claude.com/docs/en/plugins`
- Old URLs redirect with 301 status

---

## Skill System Enhancements

### New Frontmatter Fields

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `user-invocable` | boolean | Controls menu visibility (default: true) | `user-invocable: false` |
| `model` | string | Override conversation model | `model: sonnet` |
| `context` | string | Run in isolated subagent | `context: fork` |
| `agent` | string | Which subagent type | `agent: Explore` |
| `hooks` | object | Lifecycle hooks scoped to skill | (see Hook section) |

**Baseline had:** `name`, `description`, `disable-model-invocation`, `argument-hint`, `allowed-tools`

### New Variable Substitutions

Added:
- `${CLAUDE_SKILL_DIR}` — Path to skill directory (useful for scripts in references/)
- `${CLAUDE_SESSION_ID}` — Current session ID for logging/correlation

Improved:
- `$N` shorthand now documented officially (e.g., `$0`, `$1`)

### New Feature: Shell Command Injection

Syntax: `!`command\``

Execute shell commands before Claude sees the prompt, injecting output inline:

```yaml
---
name: pr-summary
---

PR Diff: !`gh pr diff`
Comments: !`gh pr view --comments`

Summarize this PR...
```

Use for dynamic context (live data) before Claude's context window.

### Invocation Control Clarification

**Baseline:** Only documented `disable-model-invocation`

**Update:** Clarified interaction with `user-invocable`:

| Config | You invoke | Claude invokes | Description in context |
|--------|-----------|-----------------|----------------------|
| (default) | Yes | Yes | Yes (unless exceeds budget) |
| `disable-model-invocation: true` | Yes | No | No |
| `user-invocable: false` | No | Yes | Yes |

New use case: `user-invocable: false` for background knowledge Claude should know but users shouldn't invoke directly.

### Reference Files Enhancement

**Baseline:** Mentioned `references/` subdirectory

**Update:** Clarified behavior and best practice:
- Files in `references/` are loaded on demand, not automatically
- Keep SKILL.md under 500 lines, move detailed docs to reference files
- Reference supporting files in SKILL.md so Claude knows what they contain
- Supports templates, examples, scripts alongside reference docs

### Context: Fork Enhancement

**Baseline:** Not mentioned

**Update:** Officially documented running skills in isolated subagent:

```yaml
context: fork
agent: Explore  # or Plan, general-purpose, or custom
```

When combined with `agent` field:
- Skill content becomes the task (subagent's prompt)
- Subagent receives no conversation history
- Specified agent type determines model and tools
- Results summarized back to main conversation

### New Bundled Skills

**Baseline:** Not documented

**Update:** Documented built-in skills available in every session:

| Skill | Purpose |
|-------|---------|
| `/simplify` | Review recent files for code reuse/quality/efficiency (spawns 3 parallel agents) |
| `/batch <instruction>` | Large-scale codebase changes (decomposes work, uses git worktrees) |
| `/debug [description]` | Troubleshoot session using debug logs |
| `/loop [interval] <prompt>` | Run prompt repeatedly on interval (e.g., polling) |
| `/claude-api` | Load Claude API reference for your language |

### Automatic Nested Directory Discovery

**Baseline:** Not mentioned

**Update:** Claude Code automatically discovers skills from nested `.claude/skills/` directories:

- Editing `packages/frontend/file.ts` → Discovers `packages/frontend/.claude/skills/`
- Supports monorepo setups
- Live change detection during session

---

## Sub-agent System Major Enhancements

### New Frontmatter Fields

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `background` | boolean | Run as background task (concurrent) | `background: true` |
| `isolation` | string | Isolated git worktree per agent | `isolation: worktree` |
| `maxTurns` | number | Maximum agentic turns before stop | `maxTurns: 10` |
| `memory` | string | Persistent cross-session memory | `memory: user` or `project` or `local` |

**Baseline had:** `name`, `description`, `tools`, `model`

### Memory Persistence Enhancement

**Baseline:** Not mentioned

**Update:** Full persistent memory system with three scopes:

| Scope | Location | Use when |
|-------|----------|----------|
| `user` | `~/.claude/agent-memory/<name>/` | Memory applies across all projects |
| `project` | `.claude/agent-memory/<name>/` | Project-specific, shareable via version control |
| `local` | `.claude/agent-memory-local/<name>/` | Project-specific, not version controlled |

**Behavior:**
- MEMORY.md auto-included in context (first 200 lines)
- System prompt includes instructions for updating memory
- Read/Write/Edit tools auto-enabled for memory management
- Agent learns across conversations

### Background Execution

**Baseline:** Not mentioned

**Update:** Subagents can run concurrent with main conversation:

```yaml
background: true
```

**Foreground (default):**
- Blocks main conversation until complete
- Permission prompts shown to user

**Background:**
- Concurrent with main work
- Pre-approved permissions upfront
- Auto-denies unpre-approved tools
- Can be resumed in foreground

**Control:**
- Ask Claude: "Run this in the background"
- Press Ctrl+B to background running task
- Add `background: true` to frontmatter

### Worktree Isolation

**Baseline:** Not mentioned

**Update:** Subagents can run in isolated git worktrees:

```yaml
isolation: worktree
```

**Benefits:**
- Fully isolated repository copy
- Subagent can't affect main repo
- Auto-cleaned up if no changes
- Useful for parallel implementation

### Hook Events for Subagents

**Baseline:** Not mentioned

**Update:** New hook events for subagent lifecycle:

**In subagent frontmatter:**
- `PreToolUse` (matcher: tool name) → Before tool call
- `PostToolUse` (matcher: tool name) → After tool returns
- `Stop` hook (converted to `SubagentStop` in main session)

**In project settings.json (main session):**
- `SubagentStart` (matcher: agent name) → When subagent begins
- `SubagentStop` (matcher: agent name) → When subagent completes

### Preloaded Skills in Subagents

**Baseline:** Not mentioned

**Update:** Inject skill content into subagent's context at startup:

```yaml
skills:
  - api-conventions
  - error-handling-patterns
```

**Key behavior:**
- Full skill content injected at startup (not just descriptions)
- Subagents don't inherit parent conversation's skills
- Must list explicitly
- Inverse of `context: fork` in skills

### Permission Modes Enhancement

**Baseline:** Not mentioned

**Update:** Formally documented permission modes:

| Mode | Behavior |
|------|----------|
| `default` | Standard permission checking with prompts |
| `acceptEdits` | Auto-accept file edits, prompt for others |
| `dontAsk` | Auto-deny prompts (allowed tools still work) |
| `bypassPermissions` | Skip all permission checks (dangerous) |
| `plan` | Read-only plan mode |

### Tool Restrictions Enhancement

**Baseline:** Mentioned `allowed-tools` for skills

**Update:** Clarified for subagents:

**Allowlist approach:**
```yaml
tools: Read, Grep, Glob, Bash
```

**Denylist approach:**
```yaml
disallowedTools: Write, Edit
```

**Restrict subagent spawning (new):**
```yaml
tools: Agent(worker, researcher), Read, Bash
```

Only specified subagents can be spawned. Use `Agent` alone to allow any.

### Built-in Subagent Updates

**Baseline had:** Explore, general-purpose

**Update adds:**
- **Plan:** For research phase in plan mode
- **Bash:** For running terminal commands in separate context
- **statusline-setup:** Sonnet, for `/statusline` configuration
- **Claude Code Guide:** Haiku, answers questions about Claude Code features

**Explore agent enhancement:** Supports three thoroughness levels: quick, medium, very thorough

### Subagent Context Management

**Baseline:** Not mentioned

**Update:** Detailed subagent context management:

- **Resume subagents:** Ask Claude to "continue that work" after completion
- **Auto-compaction:** Triggers at ~95% capacity, can override with environment variable
- **Transcript persistence:** Separate files, persist within session, 30-day cleanup
- **Can't nest subagents:** Subagents cannot spawn other subagents

---

## Plugin System Additions

### LSP Server Support

**Baseline:** Not mentioned

**Update:** New `.lsp.json` for Language Server Protocol:

```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": {
      ".go": "go"
    }
  }
}
```

Provides real-time code intelligence for languages. Users must have language server binary installed.

### Settings.json Enhancements

**Baseline:** Not mentioned

**Update:** Plugins can ship `settings.json` for default configuration:

```json
{
  "agent": "security-reviewer"
}
```

Activates a custom agent as the main thread when plugin is enabled. Takes priority over plugin.json settings.

### Plugin CLI Enhancements

**Baseline:** Mentioned `--plugin-dir`

**Update:** New CLI capabilities:

```bash
# Multiple plugins
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two

# Define agents via CLI (session-only)
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

## Marketplace & Distribution

### Marketplace Entry Format

**Baseline:** Mentioned basic format

**Update:** Clarified full format:

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief description",
  "source": "./plugins/plugin-name",
  "keywords": ["keyword1", "keyword2"]
}
```

`source` field is REQUIRED and must match version.

---

## Best Practices Updates

### Context Optimization (New)

- Run exploration in subagents to keep verbose output out of main context
- Use skill descriptions for discovery; full content loads on invoke
- Reference supporting files to load on demand
- Start fresh conversations for new topics

### Skill Design (Enhanced)

- Use `disable-model-invocation: true` for workflows with side effects
- Use `user-invocable: false` for background knowledge
- Keep SKILL.md under 500 lines
- Move detailed reference material to separate files
- Use `context: fork` for self-contained tasks

### Subagent Design (Enhanced)

- Design focused agents (one specific task)
- Write detailed descriptions (used for delegation)
- Limit tool access (grant only necessary permissions)
- Use `memory` for learning across conversations
- Preload domain-specific skills
- Use `background: true` for long-running tasks
- Check project agents into version control

---

## Breaking Changes / Deprecations

### `commands/` Directory (Deprecated)

**Baseline:** Mentioned both `commands/` and `skills/`

**Update:** `commands/` files still work but skills are preferred:

- `commands/deploy.md` and `skills/deploy/SKILL.md` both create `/deploy`
- Skills add optional features (directory structure, frontmatter)
- If both exist, skill takes precedence
- New plugins should use `skills/` exclusively

### Variable Substitution Changes

**Baseline:** Had `$ARGUMENTS`, `${SKILL_ROOT}`, `${CLAUDE_PLUGIN_ROOT}`

**Update:**
- `${SKILL_ROOT}` → Now `${CLAUDE_SKILL_DIR}` (more consistent)
- `${CLAUDE_PLUGIN_ROOT}` → Still works but not mentioned in new docs
- Added `${CLAUDE_SESSION_ID}`

---

## Summary of Strategic Changes

| Category | Impact | Key Change |
|----------|--------|-----------|
| Skills | Medium | Frontmatter fields for model, context, hooks |
| Skills | Medium | Shell injection (`!`command\``) for dynamic context |
| Subagents | High | Memory persistence with three scopes |
| Subagents | High | Background execution and isolation |
| Subagents | Medium | Lifecycle hooks (SubagentStart/Stop) |
| Plugins | Low | LSP server support |
| Distribution | Low | Enhanced CLI agent definition |
| Docs | High | Moved to code.claude.com |

---

## Files Updated in Quickstop

Based on these changes:

1. **`.claude/skills/smith/references/plugin-spec.md`** — Baseline, was accurate but missing new features
2. **`.claude/skills/smith/references/expert-knowledge.md`** — NEW, comprehensive guide with all updates
3. **`.claude/skills/smith/references/quickstart-reference.md`** — NEW, quick reference with checklists
4. **`.claude/skills/smith/references/what-changed.md`** — NEW (this file), change summary

---

## Next Steps for Quickstop

1. **Update `/smith` scaffolding** to use new SKILL.md frontmatter fields
2. **Update `/hone` auditing** to check for new features
3. **Test with new skill features** (user-invocable, context: fork, hooks)
4. **Create example plugins** demonstrating new capabilities
5. **Update quickstop marketplace registration** to leverage new plugin features
