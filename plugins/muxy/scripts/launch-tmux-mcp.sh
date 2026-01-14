#!/bin/bash
# Launch tmux-mcp with auto-detected shell
#
# Detects the shell that launched Claude Code by walking up the process tree.
# Falls back to MUXY_SHELL env var if set, then bash as last resort.

detect_shell() {
    # Honor explicit override
    if [[ -n "$MUXY_SHELL" ]]; then
        echo "$MUXY_SHELL"
        return 0
    fi

    # Try to detect from process tree (walk up several levels to find shell)
    # Claude Code -> terminal -> shell
    local ppid=$PPID
    local detected=""

    # Walk up to 5 levels looking for a shell
    for _ in {1..5}; do
        local comm=$(ps -o comm= -p "$ppid" 2>/dev/null)
        if [[ -z "$comm" ]]; then
            break
        fi

        # Strip path and leading dash (login shell indicator)
        comm="${comm##*/}"
        comm="${comm#-}"

        # Check if it's a known shell
        case "$comm" in
            bash|zsh|fish|sh|dash|ksh|tcsh|csh)
                detected="$comm"
                break
                ;;
        esac

        # Move up to parent
        ppid=$(ps -o ppid= -p "$ppid" 2>/dev/null | tr -d ' ')
        if [[ -z "$ppid" || "$ppid" == "1" ]]; then
            break
        fi
    done

    if [[ -n "$detected" ]]; then
        echo "$detected"
    else
        # Fallback to bash
        echo "bash"
    fi
}

SHELL_TYPE=$(detect_shell)

# Launch tmux-mcp with detected shell
exec npx -y tmux-mcp --shell-type "$SHELL_TYPE"
