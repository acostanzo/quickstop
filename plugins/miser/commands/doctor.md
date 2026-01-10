---
description: Diagnose mise integration and verify tool availability
allowed-tools: [Bash, Read, ListMcpResourcesTool, ReadMcpResourceTool]
---

# Miser Doctor

Diagnose the mise integration with Claude Code. Run through these checks and report status.

## Diagnostic Steps

### 1. Check mise Installation

Run `which mise` and `mise --version` to verify mise is installed and accessible.

### 2. Check Shims Directory

Verify the shims directory exists at `~/.local/share/mise/shims` and check if it's in PATH:

```bash
echo $PATH | tr ':' '\n' | grep -c mise || echo "0"
ls -la ~/.local/share/mise/shims 2>/dev/null | head -10
```

### 3. Check Current Tool Versions

Run `mise current` to see what tool versions are active in the current directory.

### 4. Check for .mise.toml or .tool-versions

Look for mise configuration files in the current directory:

```bash
ls -la .mise.toml .tool-versions mise.toml 2>/dev/null || echo "No mise config files found"
```

### 5. Verify Tool Availability

For each tool shown by `mise current`, verify the tool is accessible by running its version command (e.g., `node --version`, `ruby --version`, `python --version`).

### 6. Check MCP Server

Use the ListMcpResourcesTool to check if the mise MCP server is connected. If it is, read the `mise://tools` resource to show installed tools.

## Output Format

Present results in a clear diagnostic format:

```
Miser Doctor Results
====================

mise Installation
  Binary: /path/to/mise
  Version: X.Y.Z
  Status: OK / NOT FOUND

Shims Mode
  Directory: ~/.local/share/mise/shims
  In PATH: Yes / No
  Status: OK / WARNING

Active Tools (from mise current)
  node: 20.10.0
  ruby: 3.2.0
  ...

Tool Verification
  node --version: v20.10.0 (OK)
  ruby --version: ruby 3.2.0 (OK)
  ...

MCP Server
  Connected: Yes / No
  Resources: mise://tools, mise://env, ...
```

If any issues are found, provide specific remediation steps.
