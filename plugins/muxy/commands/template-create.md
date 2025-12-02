---
description: Create a new Muxy session template interactively
argument-hint: [template-name]
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Muxy Template Create Command

Create a new session template through an interactive wizard.

## Parameters

**Arguments**: `$ARGUMENTS`

- Optional template name
- If not provided, will ask for it

## Template Schema Reference

Templates are JSON files with this structure:

```json
{
  "name": "template-name",
  "description": "What this template is for",
  "version": "1.0",
  "base_directory": "/path/to/project",
  "session_name": "session-name",
  "windows": [
    {
      "name": "window-name",
      "description": "Window purpose",
      "layout": "main-horizontal",
      "base_directory": null,
      "panes": [
        {
          "id": "pane-id",
          "command": "command to run",
          "split": "horizontal",
          "size": "50%",
          "description": "Pane purpose"
        }
      ]
    }
  ]
}
```

### Template Variables

These placeholders are resolved at session creation:
- `{{worktree:branch-name}}` - Resolves to worktree path via Arborist
- `{{project_name}}` - Current project directory name
- `{{date}}` - Current date (YYYY-MM-DD)
- `{{timestamp}}` - Unix timestamp

### Tmux Layouts

Available layouts:
- `even-horizontal` - Panes side by side, equal width
- `even-vertical` - Panes stacked, equal height
- `main-horizontal` - One large pane on top, others below
- `main-vertical` - One large pane on left, others on right
- `tiled` - Panes in a grid

## Your Task

Guide the user through template creation:

### Step 1: Get Template Name

If `$ARGUMENTS` contains a name, use it. Otherwise ask:
- Must be lowercase, alphanumeric, hyphens allowed
- Will be used as filename: `{name}.json`

### Step 2: Get Basic Info

Use AskUserQuestion to gather:

1. **Description**: "What is this template for?"
   - Free text description

2. **Base Directory**: "What's the base directory for sessions?"
   - Options: Current directory, Specify path, Use variable
   - Default to current working directory

3. **Session Name**: "How should sessions be named?"
   - Options: Same as template, Custom name, Include date/timestamp
   - Can include variables like `{{project_name}}-dev`

### Step 3: Window Creation Loop

For each window, ask:

1. **Window Name**: Short name for the window tab
2. **Description**: What this window is for
3. **Working Directory**:
   - Same as session base
   - Specific path
   - Worktree: `{{worktree:branch-name}}`
4. **Layout**: Choose from tmux layouts

Then for panes in this window:

1. **Pane ID**: Unique identifier (e.g., "server", "shell", "logs")
2. **Command**: What to run (or empty for shell)
3. **Description**: What this pane is for

For second+ panes, also ask:
- **Split Direction**: horizontal or vertical
- **Size**: Percentage (e.g., "50%") or leave default

After each window, ask: "Add another window?"

### Step 4: Preview Template

Show the complete JSON that will be created:

```json
{
  "name": "myproject",
  "description": "Development environment for MyProject",
  ...
}
```

Ask: "Does this look correct? (yes/edit/cancel)"

### Step 5: Save Template

Save to `~/.config/claude-code/muxy/templates/{name}.json`

Create the directory if it doesn't exist:
```bash
mkdir -p ~/.config/claude-code/muxy/templates
```

### Step 6: Confirm and Next Steps

```
✓ Template 'myproject' created!

Saved to: ~/.config/claude-code/muxy/templates/myproject.json

Start a session with:
  /muxy:session myproject

Edit this template with:
  /muxy:template-edit myproject
```

## Example Interaction

```
User: /muxy:template-create fullstack