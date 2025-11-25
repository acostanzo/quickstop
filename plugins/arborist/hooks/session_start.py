#!/usr/bin/env python3
"""
Arborist SessionStart Hook

Detects and reports the current git worktree context when a Claude Code session begins.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys


def run_git_command(args: list[str], cwd: str | None = None) -> str | None:
    """Run a git command and return output, or None on failure."""
    try:
        result = subprocess.run(
            ["git"] + args,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None


def is_git_repo(path: str) -> bool:
    """Check if path is inside a git repository."""
    return run_git_command(["rev-parse", "--git-dir"], cwd=path) is not None


def get_worktree_info(cwd: str) -> dict | None:
    """Get information about the current worktree."""
    if not is_git_repo(cwd):
        return None

    # Get git directories
    git_dir = run_git_command(["rev-parse", "--git-dir"], cwd=cwd)
    common_dir = run_git_command(["rev-parse", "--git-common-dir"], cwd=cwd)

    if not git_dir or not common_dir:
        return None

    # Normalize paths for comparison
    git_dir_abs = os.path.abspath(os.path.join(cwd, git_dir))
    common_dir_abs = os.path.abspath(os.path.join(cwd, common_dir))

    # If git-dir equals git-common-dir, we're in the main worktree
    is_worktree = git_dir_abs != common_dir_abs

    # Get current branch
    branch = run_git_command(["rev-parse", "--abbrev-ref", "HEAD"], cwd=cwd)

    # Get repository name
    toplevel = run_git_command(["rev-parse", "--show-toplevel"], cwd=cwd)
    repo_name = os.path.basename(toplevel) if toplevel else "unknown"

    # Get main worktree path if we're in a worktree
    main_worktree = None
    if is_worktree:
        # The common dir's parent is the main worktree
        main_worktree = os.path.dirname(common_dir_abs)
        if main_worktree.endswith(".git"):
            main_worktree = os.path.dirname(main_worktree)

    # Get list of all worktrees
    worktree_list = run_git_command(["worktree", "list", "--porcelain"], cwd=cwd)
    worktree_count = 0
    if worktree_list:
        worktree_count = worktree_list.count("worktree ")

    return {
        "is_worktree": is_worktree,
        "branch": branch or "unknown",
        "repo_name": repo_name,
        "current_path": toplevel,
        "main_worktree": main_worktree,
        "worktree_count": worktree_count,
    }


def format_message(info: dict) -> str:
    """Format the worktree notification message."""
    if info["is_worktree"]:
        msg = f"Arborist: Working in worktree '{info['repo_name']}' (branch: {info['branch']})"
        if info["main_worktree"]:
            msg += f"\n   Main repo: {info['main_worktree']}"
    else:
        msg = f"Arborist: Working in main repo '{info['repo_name']}' (branch: {info['branch']})"

    if info["worktree_count"] > 1:
        msg += f"\n   {info['worktree_count']} worktrees available"

    return msg


def main():
    """Main hook entry point."""
    try:
        # Read hook data from stdin
        hook_data = json.load(sys.stdin)

        # Get current working directory
        cwd = os.getcwd()

        # Get worktree information
        info = get_worktree_info(cwd)

        if info:
            message = format_message(info)
            # Output message - this will be shown to the user
            print(message)

        # Always exit successfully
        sys.exit(0)

    except json.JSONDecodeError:
        # No valid JSON input, exit silently
        sys.exit(0)
    except Exception as e:
        # Log error but don't block Claude
        print(f"Arborist hook error: {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
