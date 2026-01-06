---
description: Create a tmux session from template or custom description
argument-hint: [template-name]
---

Create a new tmux session, optionally from a template.

## If template name is provided ($ARGUMENTS)

1. Look for template file at `~/.config/muxy/templates/$ARGUMENTS.yaml`
2. If found, parse the template and create the session
3. Ask user for a session name
4. Create session named `SessionName ($ARGUMENTS)`

## If no template name provided

1. List available templates from `~/.config/muxy/templates/`
2. Use AskUserQuestion to let user choose:
   - Pick from available templates
   - Or select "Describe custom" to create on-the-fly

### If user picks a template

Follow the template creation flow above.

### If user wants custom

Ask user to describe their desired layout:
- How many windows?
- What should each window be named?
- Any pane splits needed?
- Starting directories and commands?

Then create the session using tmux-mcp tools:
1. `create-session` for the initial session
2. `create-window` for additional windows
3. `split-pane` for pane splits
4. `execute-command` to run startup commands

## Session Creation Steps

Using tmux-mcp tools:

```
1. create-session → get session ID
2. For each window (after first):
   - create-window with session ID
3. For each pane split:
   - split-pane with direction and size
4. For each startup command:
   - execute-command in target pane
```

## Session Naming

Always name sessions as `UserName (TemplateName)` when using templates, or just `UserName` for custom sessions.

Example: If user wants session "MyFeature" from template "dev", create as "MyFeature (dev)".
