---
name: smith
description: Scaffold a new Quickstop plugin with correct structure and conventions
disable-model-invocation: true
argument-hint: plugin-name
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, WebSearch, WebFetch, AskUserQuestion
---

# Smith: Plugin Scaffolder

You are the Smith orchestrator. When the user runs `/smith <plugin-name>`, scaffold a new Quickstop plugin with correct structure, frontmatter, and marketplace registration. Follow each phase in order.

## Phase 0: Validation

### Step 1: Parse Plugin Name

Extract the plugin name from `$ARGUMENTS`. If empty or missing, use AskUserQuestion to ask:
- "What should the plugin be named? (kebab-case, e.g. `my-plugin`)"

### Step 2: Validate Name

1. **Kebab-case**: Name must match `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. If not, reject and ask for a valid name.
2. **No conflicts**: Glob for `plugins/$ARGUMENTS/` — if it exists, tell the user and abort.
3. **PROJECT_ROOT**: Run `git rev-parse --show-toplevel` via Bash to get the repo root.

Tell the user:
```
Scaffolding plugin: <name>
Phase 1: Building expert context from official plugin documentation...
```

---

## Phase 1: Build Expert Context

Dispatch **2 research subagents in parallel** using the Task tool. Both must be foreground.

### Dispatch Both Simultaneously

In a single message, dispatch both Task tool calls:

**Research Plugin Spec:**
- `description`: "Research plugin spec docs"
- `subagent_type`: "research-plugin-spec"
- `prompt`: "Build expert knowledge on Claude Code plugin, skill, and sub-agent authoring. Read the baseline from .claude/skills/smith/references/plugin-spec.md first, then fetch official Anthropic documentation. Return structured expert knowledge."

**Research Hooks & MCP:**
- `description`: "Research hooks/MCP docs"
- `subagent_type`: "research-hooks-mcp"
- `prompt`: "Build expert knowledge on Claude Code hooks and MCP server configuration. Fetch official Anthropic documentation. Return structured expert knowledge."

### Assemble Expert Context

Once both return, combine their results:

```
=== EXPERT CONTEXT ===

## Plugin System Knowledge
[Results from research-plugin-spec]

## Hooks & MCP Knowledge
[Results from research-hooks-mcp]

=== END EXPERT CONTEXT ===
```

Tell the user:
```
Expert context assembled. Gathering requirements...
```

---

## Phase 2: Gather Requirements

Use AskUserQuestion for each question. Skip questions that don't apply based on previous answers.

### Question 1: Description
"What does this plugin do? (1-2 sentence description)"

### Question 2: Components
Use AskUserQuestion with options to ask:
"What components does this plugin need?"
Options (allow multiple selections):
- Skills (slash commands)
- Agents (sub-agents for parallel work)
- Hooks (event-driven automation)
- MCP servers (external tool integration)
- Reference files (heavy docs/schemas loaded on demand)

### Question 3: Skills (if selected)
"List the skills this plugin needs. For each, provide a name and brief description. Format: `name: description` (one per line)"

### Question 4: Agents (if selected)
"List the agents this plugin needs. For each, provide a name and brief description. Format: `name: description` (one per line)"

### Question 5: Agent Model (if agents selected)
Use AskUserQuestion with options:
"What model should agents default to?"
- `haiku` — fast and cheap, good for research/fetch tasks
- `inherit` — use parent's model, good for analysis tasks
- `sonnet` — balanced, good for complex analysis

### Question 6: Hook Events (if hooks selected)
Use AskUserQuestion with options (allow multiple):
"What hook events does this plugin need?"
- SessionStart — run at session initialization
- PreToolUse — run before a tool is called
- PostToolUse — run after a tool returns
- Notification — run on notifications
- Stop — run when agent stops
- SubagentStop — run when a subagent stops

### Question 7: Keywords
"What keywords describe this plugin? (comma-separated, for marketplace discovery)"

---

## Phase 3: Scaffold

Using Expert Context and the user's answers, create all files. Use the official spec from Expert Context to ensure correct frontmatter and structure.

### 3.1: plugin.json

Create `plugins/<name>/.claude-plugin/plugin.json`:
```json
{
  "name": "<name>",
  "version": "0.1.0",
  "description": "<user's description>",
  "author": {
    "name": "Anthony Costanzo",
    "url": "https://github.com/acostanzo"
  }
}
```

### 3.2: Skills

For each skill the user listed, create `plugins/<name>/skills/<skill-name>/SKILL.md`:

```yaml
---
name: <skill-name>
description: <user's description for this skill>
disable-model-invocation: true
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit
---
```

Body should include:
- A header comment: `# <Skill Name>: <description>`
- A TODO section prompting the author to fill in instructions
- If the plugin has agents, include a skeleton Phase structure showing how to dispatch them

### 3.3: Agents

For each agent the user listed, create `plugins/<name>/agents/<agent-name>.md`:

```yaml
---
name: <agent-name>
description: "<user's description for this agent>"
tools:
  - Read
  - Glob
  - Grep
model: <user's chosen model>
---
```

Body should include:
- A header: `# Agent: <name>`
- A purpose section
- A TODO section for instructions
- An output format skeleton

### 3.4: Hooks

If hooks were selected, create `plugins/<name>/hooks/hooks.json`:

```json
{
  "hooks": {
    "<EventType>": [
      {
        "matcher": "",
        "command": "echo 'TODO: implement hook'",
        "timeout": 30000
      }
    ]
  }
}
```

Include each event type the user selected. Omit `matcher` for events that don't use it (SessionStart, Stop, SubagentStop, Notification).

### 3.5: MCP Config

If MCP was selected, create `plugins/<name>/.mcp.json`:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "TODO",
      "args": [],
      "env": {}
    }
  }
}
```

### 3.6: README

Create `plugins/<name>/README.md`:

```markdown
# <Name>

<description>

## Commands

[List each skill with description]

## Installation

### From Marketplace

\`\`\`bash
/plugin install <name>@quickstop
\`\`\`

### From Source

\`\`\`bash
claude --plugin-dir /path/to/quickstop/plugins/<name>
\`\`\`

## Architecture

[Brief overview of components: N skills, N agents, hooks, etc.]
```

---

## Phase 4: Register

### 4.1: Marketplace Entry

Read `.claude-plugin/marketplace.json`, add a new entry to the `plugins` array:

```json
{
  "name": "<name>",
  "version": "0.1.0",
  "description": "<description>",
  "source": "./plugins/<name>",
  "keywords": [<user's keywords>]
}
```

Use Edit to add the entry — do not overwrite the entire file.

### 4.2: Root README

Read `README.md` and add a new plugin section following the existing format (look at Bifrost and Claudit entries for the pattern). Add it after the last plugin entry with version v0.1.0.

---

## Phase 5: Summary

Present the created files:

```
=== SMITH COMPLETE ===
Plugin: <name> v0.1.0

Created:
  plugins/<name>/.claude-plugin/plugin.json
  plugins/<name>/skills/<skill>/SKILL.md        (per skill)
  plugins/<name>/agents/<agent>.md               (per agent)
  plugins/<name>/hooks/hooks.json                (if applicable)
  plugins/<name>/.mcp.json                       (if applicable)
  plugins/<name>/README.md

Registered:
  .claude-plugin/marketplace.json   ✓
  README.md                         ✓

Next steps:
  1. Fill in skill instructions (the TODO sections)
  2. Fill in agent instructions
  3. Test: claude --plugin-dir plugins/<name>
  4. Run ./scripts/check-plugin-versions.sh to verify versions
  5. Run /hone <name> to check quality
  6. Bump to v1.0.0 when ready for release
=== END ===
```

---

## Error Handling

- If a research agent fails, continue with the local baseline from `plugin-spec.md`
- If file creation fails, report the error and continue with remaining files
- If marketplace.json can't be read, create the entry and tell the user to add it manually
- Never leave a half-scaffolded plugin — if a critical step fails, clean up created files
