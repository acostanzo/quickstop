---
description: Verify tmux and MCP server setup for Muxy
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Muxy Doctor Command

Verify that tmux and the MCP server are properly configured for Muxy to function.

## Your Task

Perform a comprehensive health check of the Muxy environment:

### Step 1: Check tmux Installation

Run `tmux -V` to verify tmux is installed:
- If installed: Report version
- If not installed: Provide installation instructions based on OS:
  - macOS: `brew install tmux`
  - Ubuntu/Debian: `sudo apt install tmux`
  - Fedora: `sudo dnf install tmux`

### Step 2: Check MCP Server Availability

The tmux MCP server is bundled with the Muxy plugin and should start automatically when the plugin is enabled.

Try to use the tmux MCP tools. Look for tools with names like:
- `mcp__tmux__list_sessions` or similar
- `mcp__tmux-mcp__list_sessions` or similar

If MCP tools are available:
- Report success
- List available tmux MCP tools

If MCP tools are NOT available:
- Explain that the MCP server should be bundled with the plugin
- Suggest the user restart Claude Code to load the MCP server
- Note: MCP server changes require a Claude Code restart to take effect

### Step 3: Check Template Directory

Check if the template directory exists at `~/.config/claude-code/muxy/templates/`:
- If exists: Report how many templates are found
- If not exists: Create the directory

### Step 4: Summary Report

Present a summary like:

```
Muxy Health Check
═════════════════

✓ tmux installed (v3.3a)
✓ MCP server connected
  - list_sessions
  - create_window
  - split_pane
  - send_keys
  - capture_pane
✓ Template directory ready
  Found 3 templates

Muxy is ready to orchestrate!
```

Or if there are issues:

```
Muxy Health Check
═════════════════

✓ tmux installed (v3.3a)
✗ MCP server not found
  → See setup instructions above
✓ Template directory ready

Fix the issues above to use Muxy.
```

Use checkmarks (✓) for passing checks and crosses (✗) for failures.
