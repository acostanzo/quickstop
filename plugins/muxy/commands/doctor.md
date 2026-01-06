---
description: Verify tmux and MCP server setup for Muxy
allowed-tools: Bash, Read
---

Diagnose the Muxy plugin setup and verify all dependencies are properly configured.

## Checks to Perform

### 1. Tmux Installation

Check if tmux is installed:
```bash
which tmux && tmux -V
```

Report:
- ✓ tmux installed (version X.X)
- ✗ tmux not found - install with `brew install tmux` or `apt install tmux`

### 2. Tmux Server Running

Check if tmux server is running:
```bash
tmux list-sessions 2>&1
```

Report:
- ✓ tmux server running (X active sessions)
- ○ tmux server not running (will start when needed)

### 3. Node.js / npx Available

Check if npx is available (needed for tmux-mcp):
```bash
which npx && npx --version
```

Report:
- ✓ npx available (version X.X.X)
- ✗ npx not found - install Node.js from https://nodejs.org

### 4. tmux-mcp Server

Try to verify tmux-mcp can be loaded:
```bash
npx -y tmux-mcp --help 2>&1 || echo "UNAVAILABLE"
```

Report:
- ✓ tmux-mcp available
- ✗ tmux-mcp not available - check npm/network access

### 5. Shell Configuration

Check shell configuration:
```bash
echo "MUXY_SHELL=${MUXY_SHELL:-not set}"
```

Report:
- ✓ Shell: fish (from MUXY_SHELL)
- ○ Shell: fish (default) - set MUXY_SHELL if using different shell

### 6. Templates Directory

Check templates directory:
```bash
ls ~/.config/muxy/templates/*.yaml 2>/dev/null | wc -l
```

Report:
- ✓ Templates directory exists (X templates)
- ○ Templates directory empty
- ○ Templates directory doesn't exist (will be created on first template)

## Output Format

```
╭─ Muxy Doctor ──────────────────────────────────╮
│                                                │
│  ✓ tmux 3.4 installed                          │
│  ✓ tmux server running (2 sessions)            │
│  ✓ npx available                               │
│  ✓ tmux-mcp server available                   │
│  ✓ Shell configured: fish (env var)            │
│  ○ Templates: 0 (directory will be created)    │
│                                                │
│  Status: Ready to use!                         │
│                                                │
╰────────────────────────────────────────────────╯
```

## Status Summary

At the end, provide overall status:
- **Ready to use!** - All required checks pass
- **Setup incomplete** - Missing required dependencies (tmux, npx)
- **Partially configured** - Optional items missing but functional

## Recommendations

If issues found, provide specific fix instructions:
- Missing tmux: "Install tmux: `brew install tmux` (macOS) or `apt install tmux` (Ubuntu)"
- Missing npx: "Install Node.js from https://nodejs.org"
- Different shell: "Set your shell with: `export MUXY_SHELL=zsh` (or bash, fish, etc.)"
