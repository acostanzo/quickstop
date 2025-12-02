---
description: Delete a Muxy session template
argument-hint: [template-name]
allowed-tools: Bash, Read, Glob, AskUserQuestion
---

# Muxy Template Delete Command

Delete an existing session template.

## Parameters

**Arguments**: `$ARGUMENTS`

- Optional template name to delete
- If not provided, will list templates and ask user to choose

## Your Task

### Step 1: Select Template

If `$ARGUMENTS` contains a template name:
- Look for `~/.config/claude-code/muxy/templates/{name}.json`
- If not found, show error and list available templates

If no name provided:
- List all templates from `~/.config/claude-code/muxy/templates/*.json`
- Use AskUserQuestion to let user select one

### Step 2: Show Template Details

Before deletion, show what will be deleted:

```
Template to Delete: myproject
═════════════════════════════

Description: Full-stack development environment
Windows: 4
Total Panes: 7

This action cannot be undone.
```

### Step 3: Confirm Deletion

Use AskUserQuestion with explicit confirmation:
- "Are you sure you want to delete 'myproject'?"
- Options: "Yes, delete it", "No, cancel"

User must explicitly confirm - do not delete on ambiguous response.

### Step 4: Delete Template

If confirmed:
```bash
rm ~/.config/claude-code/muxy/templates/{name}.json
```

### Step 5: Confirm Result

```
✓ Template 'myproject' deleted.

Remaining templates: 2
  - quickstart
  - fullstack

Create a new template with:
  /muxy:template-create
```

Or if no templates remain:

```
✓ Template 'myproject' deleted.

No templates remaining.

Create a new template with:
  /muxy:template-create my-template
```

## Error Handling

- Template not found: List available templates
- Permission denied: Show error and suggest checking file permissions
- User cancels: Acknowledge and exit without deleting
