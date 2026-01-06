---
description: Destroy a tmux session with confirmation
argument-hint: [session-name]
---

Terminate a tmux session after user confirmation.

## If session name provided ($ARGUMENTS)

Use `find-session` to locate and verify the session exists.

## If no session name provided

1. Use `list-sessions` to get all active sessions
2. If no sessions exist, inform user
3. If sessions exist, use AskUserQuestion to let user select which to kill

## Confirmation Flow

Before destroying, show session details:

```
╭─ Confirm Session Termination ──────────────────╮
│                                                │
│  Session: MyFeature (dev)                      │
│  Windows: 3                                    │
│  Running processes may be terminated.          │
│                                                │
╰────────────────────────────────────────────────╯
```

Use AskUserQuestion with options:
- "Yes, destroy session" - Proceed with kill
- "No, cancel" - Abort operation

## Destruction

If confirmed:
1. Use `kill-session` with the session ID
2. Report success: "Session 'MyFeature (dev)' has been terminated."

If cancelled:
- Report: "Operation cancelled. Session remains active."

## Edge Cases

- If session doesn't exist: "Session 'name' not found. Use /muxy:list-sessions to see active sessions."
- If session is the only one and attached: Warn that killing will detach the user
