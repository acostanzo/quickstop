---
description: Interactively create a new session template
---

Guide the user through creating a new tmux session template.

## Workflow

1. Ask user to describe their desired session layout in natural language
2. Propose a YAML template based on their description
3. Let user review and request modifications
4. Save to `~/.config/muxy/templates/`

## Step 1: Gather Requirements

Ask user to describe their session:

"Describe your ideal tmux session layout. Include:
- How many windows do you need?
- What should each window be named?
- Do any windows need multiple panes (splits)?
- What commands should run when the session starts?
- What directories should panes start in?"

Example user response:
"I want 3 windows: one for my editor, one split horizontally for server and logs, and one for general shell work. The project is at ~/myproject."

## Step 2: Propose Template

Based on the description, generate a YAML template:

```yaml
name: suggested-name
description: Based on user's description
windows:
  - name: editor
    panes:
      - path: ~/myproject
        command: $EDITOR .
  - name: server
    layout: even-horizontal
    panes:
      - path: ~/myproject
        command: npm run dev
      - path: ~/myproject
        command: tail -f logs/app.log
  - name: shell
    panes:
      - path: ~/myproject
```

Display the proposed template and ask:
"Here's the template I've created. Would you like to:
- Save as-is
- Make modifications
- Start over"

## Step 3: Modifications (if requested)

If user wants changes, ask what to modify:
- Window names
- Pane arrangements
- Commands
- Paths
- Layout style

Update the template and show again.

## Step 4: Save Template

1. Ask for template name (suggest based on description)
2. Ensure `~/.config/muxy/templates/` directory exists
3. Write the YAML file
4. Confirm: "Template 'template-name' saved! Use `/muxy:session template-name` to create a session from it."

## Template Format Reference

```yaml
name: template-name
description: What this template is for
windows:
  - name: window-name
    layout: even-horizontal  # optional
    panes:
      - path: /start/directory
        command: startup command  # optional
```

Layout options: `even-horizontal`, `even-vertical`, `main-horizontal`, `main-vertical`, `tiled`
