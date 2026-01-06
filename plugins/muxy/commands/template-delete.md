---
description: Delete a session template with confirmation
argument-hint: [template-name]
---

Remove a session template after user confirmation.

## If template name provided ($ARGUMENTS)

Look for `~/.config/muxy/templates/$ARGUMENTS.yaml`

## If no template name provided

1. List available templates from `~/.config/muxy/templates/`
2. If no templates exist, inform user
3. Use AskUserQuestion to let user select which to delete

## Confirmation Flow

Before deleting, show template details:

```
╭─ Confirm Template Deletion ────────────────────╮
│                                                │
│  Template: dev                                 │
│  Description: Standard development setup       │
│  Windows: 3                                    │
│                                                │
│  This action cannot be undone.                 │
│                                                │
╰────────────────────────────────────────────────╯
```

Use AskUserQuestion with options:
- "Yes, delete template" - Proceed with deletion
- "No, cancel" - Abort operation

## Deletion

If confirmed:
1. Delete the file at `~/.config/muxy/templates/[name].yaml`
2. Report success: "Template 'dev' has been deleted."

If cancelled:
- Report: "Operation cancelled. Template remains available."

## Edge Cases

- Template not found: "Template 'name' not found. Use /muxy:template-list to see available templates."
- No templates exist: "No templates to delete. Use /muxy:template-create to create one first."
