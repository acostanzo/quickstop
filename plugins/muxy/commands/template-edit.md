---
description: Modify an existing session template
argument-hint: [template-name]
---

Edit an existing tmux session template.

## If template name provided ($ARGUMENTS)

Look for `~/.config/muxy/templates/$ARGUMENTS.yaml`

## If no template name provided

1. List available templates from `~/.config/muxy/templates/`
2. Use AskUserQuestion to let user select which to edit

## Editing Flow

1. **Display current template** in a readable format:

```
╭─ Template: dev ────────────────────────────────╮
│                                                │
│  Description: Standard development setup       │
│                                                │
│  Windows:                                      │
│  ├─ editor                                     │
│  │  └─ Pane 1: ~/project → $EDITOR .          │
│  ├─ server                                     │
│  │  ├─ Pane 1: ~/project → npm run dev        │
│  │  └─ Pane 2: ~/project → npm run watch      │
│  └─ shell                                      │
│     └─ Pane 1: ~/project                       │
│                                                │
╰────────────────────────────────────────────────╯
```

2. **Ask what to modify** using AskUserQuestion:
   - "Rename template"
   - "Update description"
   - "Add a window"
   - "Remove a window"
   - "Modify a window's panes"
   - "Change paths or commands"
   - "Done editing"

3. **Apply changes** based on selection:
   - For additions: Ask for details (name, panes, commands)
   - For removals: Confirm which to remove
   - For modifications: Show current value, ask for new value

4. **Show updated template** and offer to:
   - Save changes
   - Continue editing
   - Discard changes

## Saving

When saving:
1. Write updated YAML to the template file
2. Confirm: "Template 'dev' has been updated."

## Edge Cases

- Template not found: "Template 'name' not found. Use /muxy:template-list to see available templates."
- Invalid template file: "Template 'name' appears to be corrupted. Would you like to recreate it?"
