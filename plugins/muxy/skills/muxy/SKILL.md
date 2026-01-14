---
name: Muxy
description: This skill should be used when the user asks to "create a tmux session", "new tmux", "tmux for my project", "make a tmux layout", "set up tmux windows", "save as template", "load template", "tmux template", or describes a multi-window terminal setup. Provides natural language tmux session creation with template support.
---

# Tmux Session Management

Muxy enables natural language creation of tmux sessions. Users describe their desired layout and this skill translates that into tmux commands via the tmux MCP server.

## Core Workflow

### Session Creation Flow

1. **Parse user description** - Extract windows, panes, paths, and commands
2. **Infer project directories** - Detect paths from user prompt, project names, or cwd
3. **Present preview table** - Show structured plan for confirmation
4. **Execute on approval** - Create session via MCP tools
5. **Offer to save** - Optionally save as template for reuse

### Preview Table Format

Always present session plans in this markdown table format before creating:

```markdown
**Session: [Session Name]**

| Window | Name | Layout | Panes |
|--------|------|--------|-------|
| 1 | Servers | single | `/path/to/project` → `yarn start` |
| 2 | IDE | vertical | `/path/to/project`, `~/notes` |
| 3 | Console | horizontal | `/path` → `rails c`, `/path` → `claude` |
```

**Layout values:**
- `single` - One pane (default)
- `vertical` - Side-by-side panes (even-horizontal in tmux)
- `horizontal` - Stacked panes (even-vertical in tmux)

**Pane notation:**
- Path only: `/path/to/dir`
- Path with command: `/path/to/dir` → `command`

### Variable Inference

When loading templates or interpreting descriptions, infer values for common variables:

| Variable | Inference Logic |
|----------|-----------------|
| `${project_dir}` | 1. Project name mentioned in prompt → search working directories<br>2. Current working directory |
| `${notes_dir}` | `~/notes` if exists, else `~/Documents/notes`, else ask |

Always show inferred values in the preview table for user confirmation.

## MCP Tools Reference

Use these tmux MCP tools for session management:

| Tool | Purpose |
|------|---------|
| `list-sessions` | List active tmux sessions |
| `create-session` | Create new session (first window included) |
| `create-window` | Add window to existing session |
| `split-pane` | Split existing pane vertically or horizontally |
| `execute-command` | Run command in a pane |
| `kill-session` | Terminate a session |
| `read-pane` | Read content from a pane |
| `send-keys` | Send keystrokes to a pane |

### Session Creation Sequence

To create a multi-window session:

```
1. create-session (name, first window name, path)
2. For each additional window:
   - create-window (session, name, path)
3. For each pane split needed:
   - split-pane (session, window, direction, path)
4. For each startup command:
   - execute-command (session, window, pane, command)
```

## Template System

Templates are YAML files stored in `~/.config/muxy/templates/`.

### Template Operations

**Save a template:** After confirming a session preview, offer to save:
- "Would you like to save this as a template?"
- Write YAML to `~/.config/muxy/templates/{name}.yaml`

**Load a template:** When user mentions a template name:
- Read from `~/.config/muxy/templates/{name}.yaml`
- Parse YAML and infer variable values
- Show preview with resolved values

**List templates:** Read directory contents of `~/.config/muxy/templates/`

For template YAML format, see `references/template-format.md`.

## Conversational Patterns

### User Says: Create session from description

Example: "Create a tmux session for my rails project with servers, console, and IDE windows"

Response flow:
1. Parse: 3 windows (servers, console, IDE)
2. Infer: project_dir from cwd or prompt mention
3. Present preview table
4. Wait for "looks good" or adjustments
5. Execute via MCP tools

### User Says: Use a template

Example: "New tmux for rails"

Response flow:
1. Load `~/.config/muxy/templates/rails.yaml`
2. Infer variable values
3. Present preview with resolved paths
4. Execute on confirmation

### User Says: Save as template

Example: "Save this as a template called 'fullstack'"

Response flow:
1. Take the last confirmed session plan
2. Identify paths that should become variables
3. Write YAML to templates directory
4. Confirm save location

### User Says: Basic tmux operation

Examples: "List my sessions", "Kill the dev session", "What's running in tmux?"

Response: Use MCP tools directly (`list-sessions`, `kill-session`, `read-pane`) without preview workflow.

## Best Practices

- **Always preview before creating** - Never create sessions without user confirmation
- **Show inferred values** - Make variable resolution transparent
- **Offer adjustments** - After preview, accept modifications before executing
- **Name sessions descriptively** - Include project name when relevant
- **Preserve user terminology** - Use their window names exactly as specified

## Additional Resources

### Reference Files

For detailed template YAML format and examples, see:
- **`references/template-format.md`** - Complete template specification with examples
