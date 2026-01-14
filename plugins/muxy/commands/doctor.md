---
name: doctor
description: Verify muxy plugin setup and dependencies
allowed-tools:
  - Bash
  - Read
---

# Muxy Doctor

Run diagnostics to verify the muxy plugin is properly configured.

## Checks to Perform

Execute each check and report results:

### 1. tmux Installation

```bash
tmux -V
```

**Pass:** Version string returned (e.g., "tmux 3.4")
**Fail:** Command not found

### 2. npx Availability

```bash
npx --version
```

**Pass:** Version number returned
**Fail:** Command not found

### 3. tmux MCP Server

Check if tmux-mcp is connectable by verifying MCP tools are available. Use `/mcp` or check tool availability.

**Pass:** tmux MCP tools (list-sessions, create-session, etc.) are available
**Fail:** MCP server not connected

### 4. Shell Configuration

Check if `MUXY_SHELL` override is set, otherwise shell is auto-detected at MCP startup.

```bash
echo ${MUXY_SHELL:-"(auto-detect)"}
```

**Pass:** Shows shell name or "(auto-detect)"
**Note:** Auto-detection walks the process tree to find the launching shell.

### 5. Templates Directory

```bash
ls -la ~/.config/muxy/templates/ 2>/dev/null
```

**Pass:** Directory exists (may be empty)
**Note:** If missing, offer to create it

## Output Format

Present results as a checklist:

```
## Muxy Diagnostics

✓ tmux: v3.4
✓ npx: 10.2.0
✓ tmux-mcp: Connected
✓ Shell: fish
✓ Templates: ~/.config/muxy/templates/ (3 templates)
```

Or with issues:

```
## Muxy Diagnostics

✓ tmux: v3.4
✓ npx: 10.2.0
✗ tmux-mcp: Not connected - check /mcp status
✓ Shell: fish
⚠ Templates: Directory not found

### Recommendations
- Run `/mcp` to check MCP server status
- Create templates directory: `mkdir -p ~/.config/muxy/templates`
```

## Remediation

If issues are found, provide specific fix commands:

| Issue | Fix |
|-------|-----|
| tmux not found | `brew install tmux` (macOS) or `apt install tmux` (Linux) |
| npx not found | Install Node.js from nodejs.org |
| MCP not connected | Restart Claude Code session |
| Shell not detected | Set `MUXY_SHELL` env var to your shell |
| Templates dir missing | `mkdir -p ~/.config/muxy/templates` |
