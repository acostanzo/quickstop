#!/usr/bin/env python3
"""
Arborist SessionStart Hook

Detects and reports the current git worktree context when a Claude Code session begins.
Also reports symlink status if in a worktree with linked configuration files.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

# Manifest file for tracking config links (stored in .git/worktrees/<name>/ or .git/)
CONFIG_MANIFEST = "arborist-config"


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


def get_git_dir(cwd: str) -> str | None:
    """Get the git directory for the current worktree."""
    return run_git_command(["rev-parse", "--git-dir"], cwd=cwd)


def get_symlink_status(worktree_path: str) -> dict:
    """
    Get status of symlinks in a worktree by reading the manifest.

    Manifest is stored in .git/worktrees/<name>/ for linked worktrees,
    or .git/ for the main worktree.

    Returns dict with 'count', 'valid', 'broken' keys.
    """
    # Get the git directory for this worktree
    git_dir = get_git_dir(worktree_path)
    if not git_dir:
        return {"count": 0, "valid": 0, "broken": 0}

    # Convert to absolute path
    git_dir_abs = os.path.abspath(os.path.join(worktree_path, git_dir))
    manifest_path = os.path.join(git_dir_abs, CONFIG_MANIFEST)

    if not os.path.exists(manifest_path):
        return {"count": 0, "valid": 0, "broken": 0}

    try:
        with open(manifest_path, "r") as f:
            manifest = json.load(f)

        symlinks = manifest.get("symlinks", [])
        valid = 0
        broken = 0

        for symlink in symlinks:
            target_path = os.path.join(worktree_path, symlink.get("target", ""))
            if os.path.islink(target_path):
                if os.path.exists(target_path):
                    valid += 1
                else:
                    broken += 1

        return {
            "count": len(symlinks),
            "valid": valid,
            "broken": broken,
        }
    except (json.JSONDecodeError, OSError):
        return {"count": 0, "valid": 0, "broken": 0}


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

    # Check for symlink manifest if in a worktree
    symlink_count = 0
    symlink_valid = 0
    symlink_broken = 0
    if is_worktree and toplevel:
        symlink_info = get_symlink_status(toplevel)
        symlink_count = symlink_info.get("count", 0)
        symlink_valid = symlink_info.get("valid", 0)
        symlink_broken = symlink_info.get("broken", 0)

    return {
        "is_worktree": is_worktree,
        "branch": branch or "unknown",
        "repo_name": repo_name,
        "current_path": toplevel,
        "main_worktree": main_worktree,
        "worktree_count": worktree_count,
        "symlink_count": symlink_count,
        "symlink_valid": symlink_valid,
        "symlink_broken": symlink_broken,
    }


def format_message(info: dict) -> str:
    """Format the worktree notification message."""
    if info["is_worktree"]:
        msg = f"Arborist: In worktree '{info['repo_name']}' ({info['branch']})"
        if info["main_worktree"]:
            msg += f"\n   Main: {info['main_worktree']}"

        # Add symlink status
        if info["symlink_count"] > 0:
            if info["symlink_broken"] > 0:
                msg += f"\n   Symlinks: {info['symlink_valid']}/{info['symlink_count']} valid ({info['symlink_broken']} broken)"
            else:
                msg += f"\n   Symlinks: {info['symlink_count']} files linked"
        else:
            msg += "\n   Symlinks: none (run 'link my config files' to set up)"
    else:
        msg = f"Arborist: In main repo '{info['repo_name']}' ({info['branch']})"

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
