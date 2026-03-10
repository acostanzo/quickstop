# Claude Code Plugin/Skill/Sub-agent Expert Knowledge

Built from official Anthropic documentation (March 2026). This is the authoritative reference for plugin authoring, skill development, and sub-agent configuration.

**Documentation source:** https://code.claude.com/docs/en/

---

## Plugin System Expert Knowledge

### Plugin vs Standalone Configuration

| Aspect | Standalone (`.claude/`) | Plugin |
|--------|-------------------------|--------|
| Skill names | `/hello` | `/plugin-name:hello` |
| Best for | Personal workflows, quick experiments | Sharing, versioned releases, community distribution |
| Configuration files | `.claude/commands/`, `.claude/skills/`, `.claude/hooks/` | `plugin-name/commands/`, `plugin-name/skills/`, `plugin-name/hooks/` |
| Distribution | Manual copy to share | Marketplaces with versioning |

**Use plugins when:**
- Sharing with teammates or community
- Need version control and easy updates
- Distributing through marketplace
- Code is reusable across multiple projects

### Plugin Directory Structure

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json                 # REQUIRED — metadata and version
├── skills/
│   └── skill-name/
│       ├── SKILL.md                # Skill definition
│       └── references/             # Optional reference files (loaded on demand)
│           ├── api.md
│           └── examples.md
├── agents/
│   └── agent-name.md              # Custom subagent definitions
├── commands/                       # DEPRECATED — migrate to skills/
│   └── name.md
├── hooks/
│   └── hooks.json                 # Event handlers
├── .mcp.json                      # MCP server configuration
├── .lsp.json                      # LSP server configuration (NEW)
├── settings.json                  # Default settings when plugin enabled
└── README.md                       # Plugin documentation
```

### plugin.json Schema

```json
{
  "name": "kebab-case-identifier",  // REQUIRED — namespace for skills
  "description": "Brief description", // REQUIRED — shown in marketplace
  "version": "1.0.0",               // REQUIRED — semver format
  "author": {                       // Recommended
    "name": "Author Name",
    "url": "https://example.com"
  },
  "homepage": "https://...",        // Optional
  "repository": "https://...",      // Optional
  "license": "MIT"                  // Optional
}
```

**Critical:** Plugin names become the namespace prefix for all skills (`/plugin-name:skill-name`).

### Plugin Cache & Versioning

- **Cache key:** version number in `plugin.json`
- **Users won't receive updates** unless version is bumped
- **Marketplace registration requires version consistency:**
  1. `plugins/<name>/.claude-plugin/plugin.json` — version
  2. `.claude-plugin/marketplace.json` — version in `source` field
  3. `README.md` — displayed version

### Plugin Installation & Discovery

- Local testing: `claude --plugin-dir ./my-plugin`
- Multiple plugins: `claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two`
- Marketplace plugins: `/plugin install` command
- Team marketplaces: Configure via settings

### Quickstart Recap
1. Create `.claude-plugin/plugin.json` with `name`, `description`, `version`
2. Add skills in `skills/` directory (each skill is a folder with `SKILL.md`)
3. Test with `--plugin-dir` flag
4. Add `disable-model-invocation: true` to prevent automatic invocation
5. Use `$ARGUMENTS` for user input

---

## Skill System Expert Knowledge

### SKILL.md Format & Location

**Location hierarchy** (higher priority wins; plugins use namespace):

| Location | Scope | Priority |
|----------|-------|----------|
| Plugin `skills/` | Where plugin enabled | Lowest (namespaced: `/plugin:name`) |
| `.claude/skills/` | Project only | Medium |
| `~/.claude/skills/` | All user projects | Higher |
| Enterprise managed | Organization | Highest |

**Directory structure:**
```
skill-name/
├── SKILL.md               # REQUIRED — frontmatter + instructions
├── template.md            # Optional — template for Claude to fill
├── examples.md            # Optional — example output
├── reference.md           # Optional — detailed reference docs
└── scripts/
    └── helper.py         # Optional — executable scripts
```

Each skill is a **directory** containing at minimum a `SKILL.md` file.

### SKILL.md Frontmatter (Complete Schema)

```yaml
---
name: skill-identifier                    # Optional if dir name matches
description: "What this skill does..."    # REQUIRED — used for auto-invocation
disable-model-invocation: true            # Optional — prevent auto-invocation
user-invocable: true                      # Optional — show in /menu (default: true)
argument-hint: "[arg1] [arg2]"           # Optional — hint for /command completion
allowed-tools: Read, Grep, Bash          # Optional — restrict tool access
model: sonnet                             # Optional — override model (sonnet/haiku/opus)
context: fork                             # Optional — run in isolated subagent
agent: Explore                            # Optional — which subagent type
hooks:                                    # Optional — scoped lifecycle hooks
  PreToolUse:
    - matcher: "Bash"
      command: "validate.sh"
---
```

### Frontmatter Fields Reference

| Field | Required | Values | Description |
|-------|----------|--------|-------------|
| `name` | No | kebab-case, max 64 chars | Uses directory name if omitted |
| `description` | Recommended | string | Claude uses this to auto-invoke; omit = uses first paragraph |
| `disable-model-invocation` | No | true/false | true = only `/name` invocation works, not auto |
| `user-invocable` | No | true/false (default true) | false = hidden from menu but Claude can still invoke |
| `argument-hint` | No | string | Displayed during `/` autocomplete |
| `allowed-tools` | No | Comma-separated list | Restricts which tools Claude can use |
| `model` | No | sonnet, haiku, opus | Overrides main conversation model |
| `context` | No | fork | Run in isolated subagent context |
| `agent` | No | Explore, Plan, general-purpose, or custom | Which subagent type when `context: fork` |
| `hooks` | No | Hook configuration | Lifecycle hooks scoped to skill |

### Invocation Control Logic

| Config | You invoke | Claude invokes | Context loaded |
|--------|-----------|-----------------|-----------------|
| (default) | Yes | Yes | Description always in context; full skill on invoke |
| `disable-model-invocation: true` | Yes | No | Description NOT in context; skill loads on invoke |
| `user-invocable: false` | No | Yes | Description in context; skill loads on invoke |

**Use cases:**
- `disable-model-invocation: true` → workflows with side effects (`/deploy`, `/commit`)
- `user-invocable: false` → background knowledge Claude should know but users shouldn't invoke

### Skill Body (Content after frontmatter)

The markdown content after `---` is the **full instruction prompt**. It supports dynamic substitutions:

| Substitution | Description | Example |
|--------------|-------------|---------|
| `$ARGUMENTS` | All user-provided arguments | "Fix issue $ARGUMENTS" → "Fix issue 123" |
| `$ARGUMENTS[N]` | Specific argument by index | "$ARGUMENTS[0] and $ARGUMENTS[1]" |
| `$N` | Shorthand for `$ARGUMENTS[N]` | "$0 component from $1 to $2" |
| `${CLAUDE_SESSION_ID}` | Current session ID | For logging/correlation |
| `${CLAUDE_SKILL_DIR}` | Path to skill directory | Reference scripts bundled with skill |
| `!`command\`` | Shell command injection | `!`gh pr diff\`` injects PR diff inline |

**Important:** Arguments not in prompt are auto-appended as `ARGUMENTS: <value>`.

### Supporting Files Pattern

Keep `SKILL.md` under 500 lines. Reference other files:

```markdown
---
name: api-docs
description: Reference for our API
---

# API Documentation

For complete details, see [reference.md](reference.md)
For examples, see [examples.md](examples.md)
```

Claude loads reference files on demand when mentioned, not automatically in context.

### Dynamic Context Injection

Use `!`command\`` syntax to inject live data before Claude sees the prompt:

```yaml
---
name: pr-summary
description: Summarize a pull request
context: fork
agent: Explore
---

## PR Context
- Diff: !`gh pr diff`
- Comments: !`gh pr view --comments`
- Status: !`gh pr status`

Summarize this PR...
```

**How it works:**
1. Commands execute immediately (before Claude sees anything)
2. Output replaces the placeholder
3. Claude receives final prompt with actual data

This is **preprocessing** — Claude doesn't execute these commands.

### Running Skills in Subagents

Add `context: fork` to run a skill in isolated subagent context:

```yaml
---
name: deep-research
description: Research topics thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS:
1. Find relevant files with Glob/Grep
2. Read and analyze code
3. Summarize findings
```

**Key differences:**
- Skill content becomes the task (subagent's prompt)
- `agent` field specifies which subagent type
- Subagent receives no conversation history
- Results are summarized back to main conversation

Built-in agent types: `Explore` (read-only), `Plan` (read-only), `general-purpose` (full tools).

### Skill Tool Restrictions

Limit which tools Claude can use with `allowed-tools`:

```yaml
---
name: safe-reader
description: Read files without modifying
allowed-tools: Read, Grep, Glob
---
```

Tools listed in `allowed-tools` can be used without permission prompts. Unlisted tools require approval.

### Bundled Skills (Built-in)

Claude Code ships with these skills available in every session:

| Skill | Purpose |
|-------|---------|
| `/simplify` | Review recent files for code reuse, quality, efficiency; spawns parallel agents |
| `/batch <instruction>` | Large-scale changes across codebase; decomposes work, creates git worktrees |
| `/debug [description]` | Troubleshoot current session using debug logs |
| `/loop [interval] <prompt>` | Run prompt repeatedly on interval (e.g., `/loop 5m check deploy`) |
| `/claude-api` | Load Claude API reference material for your language |

### Automatic Skill Discovery

Claude Code automatically discovers skills from nested `.claude/skills/` directories:

- Editing `packages/frontend/file.ts` → Claude also loads `packages/frontend/.claude/skills/`
- Supports monorepo setups where packages have their own skills
- Live change detection during session

### Skill vs Command vs Subagent

| Approach | Invocation | When to use |
|----------|-----------|-----------|
| Skill | `/name` or auto | Reference content, task instructions, moderate complexity |
| Bundled skill | `/simplify`, `/batch` | Parallel agents, large-scale changes |
| Subagent | Automatic or explicit | Task produces verbose output, needs tool restrictions, self-contained work |
| Standalone config | `/name` | Personal project-specific workflows |

---

## Sub-agent System Expert Knowledge

### Subagent File Format

Subagents are markdown files with YAML frontmatter:

```markdown
---
name: code-reviewer
description: "Reviews code for quality and best practices"
tools: Read, Glob, Grep, Bash
model: sonnet
memory: user
---

You are a senior code reviewer. When invoked:
1. Analyze recent changes
2. Check code quality
3. Provide actionable feedback
```

**Location hierarchy** (higher priority wins):

| Location | Scope | Priority |
|----------|-------|----------|
| CLI `--agents` flag | Current session only | Highest |
| `.claude/agents/` | Current project | Higher |
| `~/.claude/agents/` | All user projects | Medium |
| Plugin `agents/` | Where plugin enabled | Lowest |

### Subagent Frontmatter (Complete Schema)

```yaml
---
name: agent-identifier                      # REQUIRED — lowercase + hyphens
description: "When to use this agent..."    # REQUIRED — used for delegation
tools: Read, Grep, Glob, Bash              # Optional — inherit all if omitted
disallowedTools: Write, Edit               # Optional — deny specific tools
model: sonnet                               # Optional — sonnet, opus, haiku, inherit (default: inherit)
permissionMode: default                     # Optional — default/acceptEdits/dontAsk/bypassPermissions/plan
maxTurns: 10                                # Optional — max agentic turns
skills:                                     # Optional — preload skill content
  - api-conventions
  - error-handling
mcpServers:                                # Optional — MCP server access
  slack: {}
hooks:                                     # Optional — lifecycle hooks
  PreToolUse:
    - matcher: "Bash"
      command: "validate.sh"
memory: user                               # Optional — user/project/local
background: false                          # Optional — run in background
isolation: worktree                        # Optional — use isolated git worktree
---

Your system prompt instructions here...
```

### Subagent Frontmatter Fields Reference

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | Yes | string | Unique identifier, lowercase + hyphens |
| `description` | Yes | string | When Claude should delegate to this agent |
| `tools` | No | list | Tools available to subagent; inherits all if omitted |
| `disallowedTools` | No | list | Tools to deny/remove from inherited list |
| `model` | No | string | Model: sonnet, opus, haiku, inherit (default: inherit) |
| `permissionMode` | No | string | default, acceptEdits, dontAsk, bypassPermissions, plan |
| `maxTurns` | No | number | Maximum agentic turns before stopping |
| `skills` | No | list | Skill names to preload at startup |
| `mcpServers` | No | object | MCP server configs available to agent |
| `hooks` | No | object | Event hooks scoped to subagent lifetime |
| `memory` | No | string | Persistent memory scope: user, project, local |
| `background` | No | boolean | Run as background task (concurrent) |
| `isolation` | No | string | `worktree` = isolated git worktree per agent |

### Model Selection Guidance

| Model | Use when |
|-------|----------|
| `haiku` | Fast, cheap analysis; read-only exploration; low-latency needed |
| `sonnet` | Balances capability & speed; code analysis; most general use |
| `opus` | Complex reasoning; heavyweight analysis; quality critical |
| `inherit` | Use parent conversation's model (default) |

### Available Built-in Subagents

| Name | Model | Tools | Purpose |
|------|-------|-------|---------|
| **Explore** | Haiku | Read-only | Fast codebase search; supports quick/medium/very thorough |
| **Plan** | Inherit | Read-only | Research phase in plan mode |
| **general-purpose** | Inherit | All | Complex multi-step tasks |
| **Bash** | Inherit | Bash | Terminal commands in separate context |
| **statusline-setup** | Sonnet | — | Configure `/statusline` |
| **Claude Code Guide** | Haiku | — | Answer questions about Claude Code |

### Memory Persistence

Enable with `memory` field for persistent cross-session learning:

```yaml
---
name: code-reviewer
description: Proactive code reviewer
memory: user
---

You are a code reviewer. As you review code, update your agent memory
with patterns and conventions you discover.
```

**Scopes:**

| Scope | Location | Use when |
|-------|----------|----------|
| `user` | `~/.claude/agent-memory/<agent-name>/` | Memory applies to all projects |
| `project` | `.claude/agent-memory/<agent-name>/` | Knowledge is project-specific and shareable |
| `local` | `.claude/agent-memory-local/<agent-name>/` | Project-specific but not version controlled |

**Memory behavior:**
- System prompt includes instructions for reading/writing to memory directory
- First 200 lines of `MEMORY.md` auto-loaded into context
- Read/Write/Edit tools auto-enabled for memory management
- Subagent should maintain `MEMORY.md` as knowledge base

### Permission Modes

Control how subagent handles permission prompts:

| Mode | Behavior |
|------|----------|
| `default` | Standard permission checking with user prompts |
| `acceptEdits` | Auto-accept file edits, prompt for other operations |
| `dontAsk` | Auto-deny prompts (explicitly allowed tools still work) |
| `bypassPermissions` | Skip all permission checks (use with caution) |
| `plan` | Plan mode: read-only exploration |

**Warning:** `bypassPermissions` removes all safety checks — use only for trusted operations.

### Tool Access Control

**Allowlist with `tools`:**
```yaml
tools: Read, Grep, Glob, Bash
```

**Denylist with `disallowedTools`:**
```yaml
tools: # inherit all
disallowedTools: Write, Edit
```

**Restrict subagent spawning:**
```yaml
tools: Agent(worker, researcher), Read, Bash
```

Only `worker` and `researcher` subagents can be spawned. Use `Agent` (no parens) to allow any. Omit `Agent` entirely to block all spawning.

### Preloaded Skills

Inject full skill content into subagent's context at startup:

```yaml
---
name: api-developer
description: Implement API endpoints following team conventions
skills:
  - api-conventions
  - error-handling-patterns
---

Implement endpoints. Follow the conventions from preloaded skills.
```

**Key differences:**
- Full skill content injected at startup (unlike main conversation where descriptions load)
- Subagents don't inherit skills from parent conversation
- Inverse of `context: fork` in skills (where skill controls the agent)

### Background vs Foreground Execution

**Foreground (blocking):**
- Blocks main conversation until complete
- Permission prompts passed through to user
- Best for interactive work

**Background (concurrent):**
- Runs while you continue working
- Pre-approved permissions upfront
- Auto-denies unpre-approved tools
- Can be resumed in foreground if it fails

**Control:**
- Add `background: true` to subagent frontmatter
- Ask Claude: "Run this in the background"
- Press **Ctrl+B** to background a running task

### Worktree Isolation

Use `isolation: worktree` for independent repository copies:

```yaml
---
name: worker
description: Implement features in isolation
isolation: worktree
---
```

**Behavior:**
- Creates temporary git worktree for subagent
- Fully isolated copy of repository
- Auto-cleaned up if subagent makes no changes
- Subagent can't affect main repository

**Use cases:**
- Parallel implementation without conflicts
- Safe experimentation
- Integration with CI/CD

### Hooks in Subagents

**In subagent frontmatter** (only while agent active):
```yaml
---
name: code-reviewer
hooks:
  PreToolUse:
    - matcher: "Bash"
      command: "./validate.sh"
  PostToolUse:
    - matcher: "Edit|Write"
      command: "./lint.sh"
---
```

**In project `settings.json`** (respond to subagent events in main session):
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

**Events:**
- `PreToolUse` (matcher: tool name) — before tool call
- `PostToolUse` (matcher: tool name) — after tool result
- `Stop` in frontmatter (becomes `SubagentStop` in main session)
- `SubagentStart` (matcher: agent name) — when subagent begins
- `SubagentStop` (matcher: agent name) — when subagent completes

### Automatic Delegation

Claude automatically delegates based on:
1. Task description in your request
2. `description` field in subagent configurations
3. Current context

**Encourage delegation:**
- Include phrases like "use proactively" in description
- Make descriptions specific and task-focused
- Request explicitly: "Use the code-reviewer subagent to..."

### Context Management

**Resume subagents:**
- Each invocation creates fresh context
- Ask Claude to "continue that work" to resume previous subagent
- Resumed subagent has full previous conversation history

**Auto-compaction:**
- Subagents support automatic compaction like main conversation
- Default: ~95% capacity triggers compaction
- Set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` to trigger earlier

**Transcript persistence:**
- Subagent transcripts stored separately: `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`
- Persist within session
- Can resume after restart by resuming session
- Auto-cleaned up after 30 days (configurable)

### Common Anti-patterns

❌ **Nested subagents:** Subagents cannot spawn other subagents
✅ **Solution:** Chain subagents from main conversation or use skills

❌ **Undefined `context: fork` without task:** Subagent receives guidelines but no actionable prompt
✅ **Solution:** Include explicit instructions that become the task

❌ **Subagents returning too much context:** Multiple detailed subagent outputs consume main context
✅ **Solution:** Ask subagents to summarize, or run fewer in parallel

### CLI Agent Definition

Pass agents as JSON when launching Claude Code:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Review code for quality",
    "prompt": "You are a code reviewer...",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

Fields map to frontmatter (use `prompt` for markdown body). Session-only; not persisted.

### Agent Teams (Experimental)

For coordinated work across separate sessions with sustained parallelism. Each worker has independent context. Use when:
- Multiple agents work on independent tasks that need sustained runtime
- Context windows aren't sufficient for parallel results to aggregate
- Workers communicate asynchronously

See [agent teams documentation](/en/agent-teams) for details.

---

## Best Practices

### Plugin Authoring

✅ **Start focused:** One clear purpose per plugin
✅ **Namespace skills:** Use descriptive plugin name to avoid conflicts
✅ **Test locally first:** Use `--plugin-dir` during development
✅ **Document thoroughly:** README.md with examples and installation
✅ **Version consistently:** Update all three version locations before pushing
✅ **Use disable-model-invocation:** For workflows with side effects
✅ **Leverage reference files:** Keep SKILL.md under 500 lines
✅ **Preload skills in subagents:** When subagent needs domain knowledge

❌ **Don't put files in `.claude-plugin/`:** Only `plugin.json` goes there
❌ **Don't forget marketplace registration:** Version mismatches break updates
❌ **Don't create deeply nested plugin structures:** Keep it simple

### Skill Development

✅ **Write clear descriptions:** Claude uses these to auto-invoke
✅ **Use $ARGUMENTS for user input:** More flexible than fixed prompts
✅ **Reference supporting files:** Load details on demand, not always in context
✅ **Control invocation explicitly:** Use `disable-model-invocation` or `user-invocable`
✅ **Restrict tools when possible:** Safer and more focused
✅ **Use shell injection for live data:** Fetch actual data before Claude sees it
✅ **Keep SKILL.md focused:** Use supporting files for reference material

❌ **Don't embed large reference docs in SKILL.md:** Move to separate files
❌ **Don't assume skills are always in context:** Only descriptions are
❌ **Don't rely on side effects without disabling model invocation:** Users must control deployment, commits, etc.

### Sub-agent Configuration

✅ **Design focused agents:** Excel at one specific task
✅ **Write detailed descriptions:** Claude decides when to delegate based on these
✅ **Limit tool access:** Grant only necessary permissions
✅ **Use `memory` for learning:** Build institutional knowledge across conversations
✅ **Preload domain-specific skills:** Improve specialized agents
✅ **Check into version control:** Share project agents with team
✅ **Use `background: true` for long tasks:** Don't block main conversation
✅ **Validate tool calls with PreToolUse hooks:** Conditional restrictions

❌ **Don't nest subagents:** Subagents can't spawn other subagents
❌ **Don't return verbose output from subagents:** Summarize and return only relevant findings
❌ **Don't run too many subagents in parallel:** Context consumption on return
❌ **Don't use `bypassPermissions` casually:** Only for trusted operations

### Context Optimization

✅ **Run exploration in subagents:** Keeps verbose output out of main context
✅ **Start fresh conversations for new topics:** Cleaner context
✅ **Use git diff to minimize scope:** Focused diffs instead of full files
✅ **Leverage skill descriptions:** Loaded for discovery, full content on invoke
✅ **Reference supporting files:** Load on demand, not always in context

❌ **Don't load everything upfront:** Be selective about what's always available
❌ **Don't return large results from subagents:** Summarize findings
❌ **Don't preload all skills in subagents:** Only load necessary ones

---

## Testing & Validation

### Testing Plugins

```bash
# Load plugin during development
claude --plugin-dir ./my-plugin

# Test skills
/my-plugin:skill-name

# Check skill is registered
/help | grep my-plugin

# List all skills
/help
```

### Testing Skills

1. **Direct invocation:** `/skill-name args`
2. **Auto-invocation:** Ask Claude to do work matching description
3. **Arguments:** Test with `$ARGUMENTS` substitution
4. **Reference files:** Verify files are loaded when referenced
5. **Tool restrictions:** Confirm `allowed-tools` are enforced

### Testing Subagents

1. **Delegation:** Ask Claude to use the subagent
2. **Tool access:** Verify `tools` and `disallowedTools` work
3. **Memory:** Check `MEMORY.md` is created and updated
4. **Hooks:** Verify `PreToolUse`/`PostToolUse` events
5. **Background:** Test with `background: true`

### Version Validation

Run before committing:
```bash
./scripts/check-plugin-versions.sh
```

Checks that versions match across:
- `plugin.json`
- `marketplace.json`
- `README.md`

---

## Common Issues & Troubleshooting

### Skill not auto-invoking

**Symptom:** Claude doesn't use your skill when expected

**Solutions:**
1. Check description includes keywords matching your request
2. Run `/help` to verify skill is registered
3. Rephrase request to match description more closely
4. Check `disable-model-invocation: false` (default)

### Skill description too generic

**Symptom:** Claude invokes skill too often or at wrong times

**Solutions:**
1. Make description more specific
2. Include domain-specific keywords
3. Specify exact use cases
4. Add `disable-model-invocation: true` if only manual invocation wanted

### Plugin skills not namespaced

**Symptom:** Skill appears as `/name` instead of `/plugin:name`

**Reason:** Skills must be in `skills/` directory (not `commands/` or `.claude/`)

**Solution:** Move to `plugin-name/skills/skill-name/SKILL.md`

### Subagent not delegating

**Symptom:** Claude doesn't use subagent even when appropriate

**Solutions:**
1. Make description more task-specific
2. Include "use proactively" if should trigger automatically
3. Check `tools` field isn't blocking needed tools
4. Test explicit request: "Use the X subagent to..."

### Memory not persisting

**Symptom:** Subagent `MEMORY.md` doesn't persist between sessions

**Reason:** Memory not enabled or scope not set correctly

**Solutions:**
1. Check `memory: user` or `memory: project` in frontmatter
2. Verify subagent is actually writing to memory
3. Check permissions allow Write tool
4. For `project` scope, ensure `.claude/agent-memory/` is readable

---

## Documentation URLs

**Official Anthropic Documentation:**
- https://code.claude.com/docs/en/plugins — Create plugins
- https://code.claude.com/docs/en/skills — Extend with skills
- https://code.claude.com/docs/en/sub-agents — Create subagents
- https://code.claude.com/docs/en/plugins-reference — Complete technical specs
- https://code.claude.com/docs/en/mcp — MCP server integration
- https://code.claude.com/docs/en/hooks — Event hooks and automation

**Note:** Old `docs.anthropic.com` URLs redirect (301) to `code.claude.com`

---

## Version History

**Last updated:** March 2026
**Knowledge cutoff:** February 2025
**Documentation source:** https://code.claude.com/docs/en/

**Recent changes (March 2026):**
- Documentation moved to `code.claude.com`
- New skill frontmatter: `user-invocable`, `model`, `context`, `agent`, `hooks`
- New subagent frontmatter: `background`, `isolation: worktree`, `memory` with three scopes
- New subagent hook events: `SubagentStart`, `SubagentStop`
- New LSP server support: `.lsp.json` configuration
- Subagent teams (experimental)
- Enhanced variable substitution: `${CLAUDE_SKILL_DIR}`, `${CLAUDE_SESSION_ID}`
- Shell command injection for dynamic context: `!`command\``
