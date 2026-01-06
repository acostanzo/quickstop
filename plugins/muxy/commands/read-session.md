---
description: Show detailed layout and running processes of a tmux session
argument-hint: [session-name]
---

Display a comprehensive overview of a tmux session including all windows, panes, and running processes.

## If session name provided ($ARGUMENTS)

Use `find-session` to locate the session.

## If no session name provided

1. Use `list-sessions` to get all active sessions
2. If only one session, use it automatically
3. If multiple sessions, use AskUserQuestion to let user pick

## Information to Gather

For the selected session:

1. **Session info**: Name, ID, creation time, attached status
2. **Windows**: Use `list-windows` to get all windows
3. **Panes per window**: Use `list-panes` for each window
4. **Pane content preview**: Use `capture-pane` to see last few lines

## Output Format

Display a visual representation of the session:

```
╭─ Session: MyFeature (dev) ─────────────────────╮
│  Status: attached │ Windows: 3                 │
╰────────────────────────────────────────────────╯

Window 1: code [active]
┌─────────────────────────────────────────┐
│ Pane 1 (100%)                           │
│ > nvim .                                │
│ [editing src/main.ts]                   │
└─────────────────────────────────────────┘

Window 2: server
┌──────────────────┬──────────────────────┐
│ Pane 1 (50%)     │ Pane 2 (50%)         │
│ > npm run dev    │ > npm run watch      │
│ [server:3000]    │ [watching files...]  │
└──────────────────┴──────────────────────┘

Window 3: shell
┌─────────────────────────────────────────┐
│ Pane 1 (100%)                           │
│ ~/project $                             │
│ [idle]                                  │
└─────────────────────────────────────────┘
```

## Pane Content Preview

For each pane, capture the last 5-10 lines to show:
- The running command (if visible)
- Current state/output
- Mark as [idle] if just a shell prompt
