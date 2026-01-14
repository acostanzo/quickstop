---
name: templates
description: List available muxy session templates
allowed-tools:
  - Bash
  - Read
---

# List Muxy Templates

Display available session templates from `~/.config/muxy/templates/`.

## Steps

### 1. Check Templates Directory

```bash
ls ~/.config/muxy/templates/*.yaml 2>/dev/null
```

If directory doesn't exist or is empty, report:
```
No templates found.

To create a template, describe a tmux session and say "save this as a template".
Templates are stored in: ~/.config/muxy/templates/
```

### 2. Parse Each Template

For each `.yaml` file found, extract:
- `name` field
- `description` field
- Count of windows

Use this bash to extract info:
```bash
for f in ~/.config/muxy/templates/*.yaml; do
  echo "---"
  echo "File: $f"
  grep -E "^name:|^description:" "$f"
  grep -c "^  - name:" "$f" | xargs echo "Windows:"
done
```

### 3. Present as Table

Format output as:

```
## Available Templates

| Template | Description | Windows |
|----------|-------------|---------|
| rails | Standard Rails development environment | 3 |
| web-dev | Frontend development with hot reload | 3 |
| agent | Claude Code with supporting terminals | 2 |

**Location:** ~/.config/muxy/templates/

To use a template: "New tmux session using the rails template"
To create a template: Describe a session, then "save this as a template"
```

## Empty State

If no templates exist:

```
## Templates

No templates found yet.

**To create your first template:**
1. Describe the tmux session you want
2. Review and confirm the preview
3. Say "save this as a template called [name]"

Templates are stored in: ~/.config/muxy/templates/
```
