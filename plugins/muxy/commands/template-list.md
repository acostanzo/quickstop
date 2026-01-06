---
description: List all available session templates
---

Display all available tmux session templates with their descriptions.

## Steps

1. Check if `~/.config/muxy/templates/` directory exists
2. List all `.yaml` files in the directory
3. Parse each file to extract name and description
4. Display in a formatted list

## Output Format

```
╭─ Available Templates ──────────────────────────╮
│                                                │
│  dev                                           │
│  └─ Standard development setup with editor,   │
│     server, and shell windows                  │
│                                                │
│  fullstack                                     │
│  └─ Full-stack development with frontend,     │
│     backend, and database windows              │
│                                                │
│  monitor                                       │
│  └─ System monitoring with htop, logs, and    │
│     network stats                              │
│                                                │
╰────────────────────────────────────────────────╯

Use /muxy:session [template-name] to create a session.
```

## Edge Cases

If no templates directory exists:
```
No templates found.

Templates are stored in ~/.config/muxy/templates/
Use /muxy:template-create to create your first template.
```

If directory exists but is empty:
```
No templates found in ~/.config/muxy/templates/

Use /muxy:template-create to create your first template.
```

## Template Parsing

For each `.yaml` file:
1. Read the file content
2. Parse YAML to extract `name` and `description` fields
3. If parsing fails, show filename with "[invalid template]" note
