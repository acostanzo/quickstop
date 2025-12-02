---
description: List all available Muxy session templates
allowed-tools: Bash, Read, Glob
---

# Muxy Template List Command

Display all available session templates.

## Your Task

### Step 1: Find Templates

Look for template files in two locations:
1. Global: `~/.config/claude-code/muxy/templates/*.json`
2. Plugin bundled: `${CLAUDE_PLUGIN_ROOT}/templates/*.json`

Use Glob to find all `.json` files in these directories.

### Step 2: Parse Each Template

For each template file found, read and parse the JSON to extract:
- `name` - Template name
- `description` - What the template is for
- `session_name` - Default session name
- Number of windows (count `windows` array)
- Total panes (sum of panes across all windows)

### Step 3: Display Table

Present the templates in a formatted table:

```
Available Muxy Templates
════════════════════════

Name          Description                      Windows  Panes
────────────────────────────────────────────────────────────
myproject     Full-stack dev environment       4        7
quickstart    Simple single-window setup       1        1
fullstack     Frontend + Backend + Services    3        5

Total: 3 templates
```

If no templates found:

```
No Muxy Templates Found
═══════════════════════

Create your first template with:
  /muxy:template-create my-template

Or check the documentation for example templates.
```

### Step 4: Offer Actions

After listing, suggest:
- `/muxy:template-create <name>` to create a new template
- `/muxy:session <name>` to start a session from a template
- Ask if user wants to see details of a specific template

If user asks for details, show the full JSON structure of that template with explanations of each window and pane.
