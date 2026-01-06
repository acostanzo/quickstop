---
description: List all active tmux sessions with their template info
---

List all active tmux sessions and display them in a formatted table.

## Steps

1. Use `list-sessions` MCP tool to get all active sessions
2. Parse session names to extract template info from `(TemplateName)` suffix
3. Display in a formatted table

## Output Format

Display sessions in a clear table:

```
╭─ Active Tmux Sessions ─────────────────────────╮
│                                                │
│  Session Name         Template      Windows   │
│  ─────────────────────────────────────────────│
│  MyFeature (dev)      dev           3         │
│  Hotfix (minimal)     minimal       2         │
│  Scratch              (custom)      1         │
│                                                │
╰────────────────────────────────────────────────╯
```

## Session Name Parsing

- If session name contains ` (TemplateName)`, extract template name
- If no parentheses, mark as "(custom)"

## Additional Info

For each session, also show:
- Number of windows (from `list-windows`)
- Whether session is attached

If no sessions are active, display:
```
No active tmux sessions. Use /muxy:session to create one.
```
