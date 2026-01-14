#!/bin/bash
set -euo pipefail

# Launch tmux-mcp with auto-detected shell
#
# Detects the shell that launched Claude Code by walking up the process tree.
# Falls back to MUXY_SHELL env var if set, then bash as last resort.

SUPPORTED_SHELLS="bash|zsh|fish|sh|dash|ksh|tcsh|csh"

validate_shell() {
    local shell="$1"
    [[ "$shell" =~ ^($SUPPORTED_SHELLS)$ ]]
}

detect_shell() {
    # Honor explicit override
    if [[ -n "${MUXY_SHELL:-}" ]]; then
        if validate_shell "$MUXY_SHELL"; then
            echo "$MUXY_SHELL"
            return 0
        else
            echo "ERROR: Invalid MUXY_SHELL value '$MUXY_SHELL'. Supported: bash, zsh, fish, sh, dash, ksh, tcsh, csh" >&2
            exit 1
        fi
    fi

    # Try to detect from process tree (walk up several levels to find shell)
    # Claude Code -> terminal -> shell
    local ppid=$PPID
    local detected=""

    # Walk up to 5 levels looking for a shell
    for _ in {1..5}; do
        local comm
        comm=$(ps -o comm= -p "$ppid" 2>/dev/null) || true
        if [[ -z "$comm" ]]; then
            break
        fi

        # Strip path and leading dash (login shell indicator)
        comm="${comm##*/}"
        comm="${comm#-}"

        # Check if it's a known shell
        if validate_shell "$comm"; then
            detected="$comm"
            break
        fi

        # Move up to parent
        ppid=$(ps -o ppid= -p "$ppid" 2>/dev/null | tr -d ' ') || true
        if [[ -z "$ppid" || "$ppid" == "1" ]]; then
            break
        fi
    done

    if [[ -n "$detected" ]]; then
        echo "$detected"
    else
        # Fallback to bash - this is expected in some environments (containers, unusual process trees)
        echo "bash"
    fi
}

# Pre-flight checks
if ! command -v npx &>/dev/null; then
    echo "ERROR: npx not found. Install Node.js from https://nodejs.org/" >&2
    exit 1
fi

if ! command -v tmux &>/dev/null; then
    echo "ERROR: tmux not found. Install: brew install tmux (macOS) or apt install tmux (Linux)" >&2
    exit 1
fi

SHELL_TYPE=$(detect_shell)

# Launch tmux-mcp with detected shell
exec npx -y tmux-mcp --shell-type "$SHELL_TYPE"
