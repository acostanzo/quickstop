#!/usr/bin/env python3
"""
Config manager for Arborist worktree plugin.

This module provides utilities for creating, managing, and tracking configuration
file links (symlinks or copies) between git worktrees.
"""

import fnmatch
import json
import os
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

MANIFEST_FILE = "arborist-config"  # Stored in .git/worktrees/<name>/, not worktree root
MANIFEST_VERSION = "2.2"

# Valid link types
LINK_TYPE_SYMLINK = "symlink"
LINK_TYPE_COPY = "copy"

# Patterns to NEVER symlink (regenerate via package managers instead)
ALWAYS_SKIP_PATTERNS = [
    # Node.js
    "node_modules/",
    "node_modules/**",
    # PHP
    "vendor/",
    "vendor/**",
    # Python
    "__pycache__/",
    "__pycache__/**",
    "*.pyc",
    "*.pyo",
    ".venv/",
    ".venv/**",
    "venv/",
    "venv/**",
    "env/",
    "env/**",
    ".env/",  # Note: .env FILE is symlinked, .env/ DIRECTORY is skipped
    "site-packages/",
    "site-packages/**",
    # iOS
    "Pods/",
    "Pods/**",
    # Java/Kotlin
    ".gradle/",
    ".gradle/**",
    # Rust/Java
    "target/",
    "target/**",
    # Elixir
    "deps/",
    "deps/**",
    "_build/",
    "_build/**",
    # Ruby
    ".bundle/",
    ".bundle/**",
    # Legacy
    "bower_components/",
    "bower_components/**",
    # pnpm
    ".pnpm-store/",
    ".pnpm-store/**",
    # Build output
    "dist/",
    "dist/**",
    "build/",
    "build/**",
    "out/",
    "out/**",
    "output/",
    "output/**",
    # Framework builds
    ".next/",
    ".next/**",
    ".nuxt/",
    ".nuxt/**",
    ".svelte-kit/",
    ".svelte-kit/**",
    # Test coverage
    "coverage/",
    "coverage/**",
    ".nyc_output/",
    ".nyc_output/**",
    # Bundled assets
    "*.bundle.js",
    "*.min.js",
    "*.min.css",
    # Bundler caches
    ".parcel-cache/",
    ".parcel-cache/**",
    ".turbo/",
    ".turbo/**",
    ".webpack/",
    ".webpack/**",
    # Caches
    ".cache/",
    ".cache/**",
    "cache/",
    "cache/**",
    "caches/",
    "caches/**",
    # Temporary
    "tmp/",
    "tmp/**",
    "temp/",
    "temp/**",
    ".tmp/",
    ".tmp/**",
    ".temp/",
    ".temp/**",
    # Logs
    "*.log",
    "logs/",
    "logs/**",
    "*.log.*",
    # Linter caches
    ".eslintcache",
    ".stylelintcache",
    ".prettiercache",
    # Editor swap files
    "*.swp",
    "*.swo",
    "*~",
    # OS artifacts
    ".DS_Store",
    "Thumbs.db",
    # Git internals
    ".git/",
    ".git/**",
]

# Patterns to ALWAYS symlink (shared configuration)
ALWAYS_SYMLINK_PATTERNS = [
    # Environment files
    ".env",
    ".env.*",
    ".env.local",
    # Credentials
    "credentials*.json",
    "serviceAccount*.json",
    "*.pem",
    "*.key",
    # Package manager configs
    ".npmrc",
    ".yarnrc",
    ".yarnrc.yml",
    ".nvmrc",
    ".node-version",
    ".tool-versions",
    "pnpm-workspace.yaml",
    # IDE settings
    ".vscode/",
    ".vscode/**",
    ".idea/",
    ".idea/**",
    # Project configuration
    "config/",
    "config/**",
    "conf/",
    "conf/**",
    "*.local",
    "*.local.*",
    "settings.local.json",
    "appsettings.local.json",
]

# Threshold for asking user about large files (in bytes)
ASK_THRESHOLD_BYTES = 10 * 1024 * 1024  # 10MB


def matches_pattern(path: str, patterns: List[str]) -> bool:
    """Check if a path matches any of the given glob patterns."""
    # Preserve original path for directory pattern matching
    original_path = path
    path_normalized = path.rstrip("/")

    for pattern in patterns:
        original_pattern = pattern
        pattern_normalized = pattern.rstrip("/")

        # Direct match
        if fnmatch.fnmatch(path_normalized, pattern_normalized):
            return True

        # Also check basename for file patterns (but not directory patterns)
        if not original_pattern.endswith("/") and not original_pattern.endswith("/**"):
            basename = os.path.basename(path_normalized)
            if fnmatch.fnmatch(basename, pattern_normalized):
                return True

        # Check if path is inside a directory that matches
        # Only if pattern is explicitly a directory pattern (ends with / or /**)
        if original_pattern.endswith("/") or original_pattern.endswith("/**"):
            dir_pattern = pattern_normalized.rstrip("/*")
            # Match if path is inside the directory OR path IS the directory
            # But only match "path IS directory" if the original path had a trailing slash
            if path_normalized.startswith(dir_pattern + "/"):
                return True
            if original_path.endswith("/") and path_normalized == dir_pattern:
                return True

    return False


def should_skip(path: str) -> bool:
    """Check if path should be skipped (not symlinked)."""
    return matches_pattern(path, ALWAYS_SKIP_PATTERNS)


def should_symlink(path: str) -> bool:
    """Check if path should always be symlinked."""
    return matches_pattern(path, ALWAYS_SYMLINK_PATTERNS)


def get_file_size(path: str) -> int:
    """Get file size in bytes, returns 0 for directories or errors."""
    try:
        if os.path.isfile(path):
            return os.path.getsize(path)
        return 0
    except OSError:
        return 0


def is_large_file(path: str) -> bool:
    """Check if file exceeds the ask threshold."""
    return get_file_size(path) > ASK_THRESHOLD_BYTES


def get_gitignored_files(repo_path: str) -> List[str]:
    """
    Get list of gitignored files that exist in the repository.

    Args:
        repo_path: Path to the git repository

    Returns:
        List of relative paths to gitignored files
    """
    try:
        result = subprocess.run(
            ["git", "ls-files", "--others", "--ignored", "--exclude-standard"],
            cwd=repo_path,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            files = [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
            return files
        return []
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, OSError):
        return []


def categorize_files(
    files: List[str], source_path: str
) -> Dict[str, List[Tuple[str, str]]]:
    """
    Categorize files into symlink, skip, and ask categories.

    Args:
        files: List of file paths to categorize
        source_path: Base path for calculating file sizes

    Returns:
        Dict with keys 'symlink', 'skip', 'ask' containing lists of (path, reason) tuples
    """
    result = {"symlink": [], "skip": [], "ask": []}

    for file in files:
        full_path = os.path.join(source_path, file)

        # Check symlink patterns first - they take precedence
        # This handles cases like ".env" file vs ".env/" directory
        if should_symlink(file):
            result["symlink"].append((file, "shared config"))
        elif should_skip(file):
            # Determine skip reason
            if "node_modules" in file:
                reason = "npm install"
            elif "vendor" in file:
                reason = "package manager install"
            elif "__pycache__" in file or file.endswith((".pyc", ".pyo")):
                reason = "Python cache (regenerates)"
            elif any(d in file for d in ["venv", ".venv", "env"]):
                reason = "virtual environment"
            elif any(d in file for d in ["dist", "build", "out", "target"]):
                reason = "build output"
            elif any(d in file for d in [".next", ".nuxt", ".svelte-kit"]):
                reason = "framework cache"
            elif any(d in file for d in ["coverage", ".nyc_output"]):
                reason = "test coverage"
            elif any(d in file for d in [".cache", "cache", "tmp", "temp"]):
                reason = "cache/temp files"
            elif file.endswith(".log") or "logs" in file:
                reason = "log files"
            else:
                reason = "regeneratable artifact"
            result["skip"].append((file, reason))
        elif is_large_file(full_path):
            size_mb = get_file_size(full_path) / (1024 * 1024)
            result["ask"].append((file, f"large file ({size_mb:.1f}MB)"))
        elif file.endswith((".sqlite", ".db", ".sqlite3")):
            result["ask"].append((file, "database file"))
        else:
            # Default to asking for unknown patterns
            result["ask"].append((file, "unknown pattern"))

    return result


def calculate_relative_path(source: str, target: str) -> str:
    """
    Calculate the relative path from target to source for symlink creation.

    Args:
        source: Absolute path to the source file
        target: Absolute path where the symlink will be created

    Returns:
        Relative path from target's directory to source
    """
    source = os.path.abspath(source)
    target = os.path.abspath(target)
    target_dir = os.path.dirname(target)
    return os.path.relpath(source, target_dir)


def copy_file(
    source: str, target: str, dry_run: bool = False
) -> Tuple[bool, str]:
    """
    Copy a file from source to target.

    Args:
        source: Absolute path to the source file/directory
        target: Absolute path where the copy will be created
        dry_run: If True, don't actually copy the file

    Returns:
        Tuple of (success, message)
    """
    import shutil

    try:
        source = os.path.abspath(source)
        target = os.path.abspath(target)

        # Check source exists
        if not os.path.exists(source):
            return False, f"Source does not exist: {source}"

        # Check target doesn't already exist
        if os.path.exists(target) or os.path.islink(target):
            if os.path.islink(target):
                return False, f"Symlink already exists at target: {target}"
            return False, f"File already exists: {target}"

        if dry_run:
            return True, f"Would copy: {source} -> {target}"

        # Create parent directories
        target_dir = os.path.dirname(target)
        os.makedirs(target_dir, exist_ok=True)

        # Copy file or directory
        if os.path.isdir(source):
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)

        return True, f"Copied: {source} -> {target}"

    except OSError as e:
        return False, f"Error copying file: {e}"


def create_symlink(
    source: str, target: str, dry_run: bool = False
) -> Tuple[bool, str]:
    """
    Create a symlink from target to source.

    Args:
        source: Absolute path to the source file/directory
        target: Absolute path where the symlink will be created
        dry_run: If True, don't actually create the symlink

    Returns:
        Tuple of (success, message)
    """
    try:
        source = os.path.abspath(source)
        target = os.path.abspath(target)

        # Check source exists
        if not os.path.exists(source):
            return False, f"Source does not exist: {source}"

        # Check target doesn't already exist
        if os.path.exists(target) or os.path.islink(target):
            if os.path.islink(target):
                return False, f"Symlink already exists: {target}"
            return False, f"File already exists: {target}"

        # Calculate relative path
        rel_path = calculate_relative_path(source, target)

        if dry_run:
            return True, f"Would create: {target} -> {rel_path}"

        # Create parent directories
        target_dir = os.path.dirname(target)
        os.makedirs(target_dir, exist_ok=True)

        # Create symlink
        os.symlink(rel_path, target)
        return True, f"Created: {target} -> {rel_path}"

    except OSError as e:
        return False, f"Error creating symlink: {e}"


def create_links(
    source_repo: str,
    target_worktree: str,
    files: List[Dict[str, str]],
    dry_run: bool = False,
) -> Dict[str, List[Dict]]:
    """
    Create symlinks or copies from worktree to source repo for a list of files.

    Args:
        source_repo: Path to the source repository (main worktree)
        target_worktree: Path to the target worktree
        files: List of dicts with 'path' and optional 'type' (symlink|copy, default: symlink)
        dry_run: If True, don't actually create links

    Returns:
        Dict with 'success' and 'failed' lists containing file info dicts
    """
    result = {"success": [], "failed": []}

    source_repo = os.path.abspath(source_repo)
    target_worktree = os.path.abspath(target_worktree)

    for file_entry in files:
        # Support both dict format and string format for backward compatibility
        if isinstance(file_entry, str):
            file_path = file_entry
            link_type = LINK_TYPE_SYMLINK
        else:
            file_path = file_entry.get("path", file_entry.get("target", ""))
            link_type = file_entry.get("type", LINK_TYPE_SYMLINK)

        source = os.path.join(source_repo, file_path)
        target = os.path.join(target_worktree, file_path)
        rel_path = calculate_relative_path(source, target)

        if link_type == LINK_TYPE_COPY:
            success, message = copy_file(source, target, dry_run)
        else:
            success, message = create_symlink(source, target, dry_run)

        info = {
            "target": file_path,
            "source": rel_path,
            "type": link_type,
            "message": message,
        }

        if success:
            result["success"].append(info)
        else:
            result["failed"].append(info)

    return result


def create_symlinks(
    source_repo: str,
    target_worktree: str,
    files: List[str],
    dry_run: bool = False,
) -> Dict[str, List[Dict]]:
    """
    Create symlinks from worktree to source repo for a list of files.

    This is a convenience wrapper around create_links for backward compatibility.

    Args:
        source_repo: Path to the source repository (main worktree)
        target_worktree: Path to the target worktree
        files: List of relative file paths to symlink
        dry_run: If True, don't actually create symlinks

    Returns:
        Dict with 'success' and 'failed' lists containing file info dicts
    """
    # Convert simple file list to file entries
    file_entries = [{"path": f, "type": LINK_TYPE_SYMLINK} for f in files]
    return create_links(source_repo, target_worktree, file_entries, dry_run)


def get_manifest_path(worktree_path: str) -> Optional[str]:
    """
    Get the path where the manifest should be stored.

    For linked worktrees, stores in .git/worktrees/<name>/arborist-symlinks.
    For main worktree, stores in .git/arborist-symlinks.

    Args:
        worktree_path: Path to the worktree root

    Returns:
        Absolute path to the manifest file, or None if not in a git repo
    """
    git_dir = get_worktree_git_dir(worktree_path)
    if not git_dir:
        return None
    return os.path.join(git_dir, MANIFEST_FILE)


def write_manifest(
    worktree_path: str, source_worktree: str, links: List[Dict]
) -> bool:
    """
    Write the manifest file to the git directory.

    Args:
        worktree_path: Path to the worktree root
        source_worktree: Path to the source worktree
        links: List of link info dicts with 'target', 'source', and optional 'type' keys

    Returns:
        True if successful, False otherwise
    """
    manifest_path = get_manifest_path(worktree_path)
    if not manifest_path:
        return False

    manifest = {
        "version": MANIFEST_VERSION,
        "worktree_path": os.path.abspath(worktree_path),
        "source_worktree": os.path.abspath(source_worktree),
        "created_at": datetime.utcnow().isoformat() + "Z",
        "links": [
            {
                "target": s["target"],
                "source": s["source"],
                "type": s.get("type", LINK_TYPE_SYMLINK),
            }
            for s in links
        ],
    }

    try:
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)
        return True
    except OSError:
        return False


def read_manifest(worktree_path: str) -> Optional[Dict]:
    """
    Read the symlink manifest file from the git directory.

    Args:
        worktree_path: Path to the worktree root

    Returns:
        Manifest dict if exists and valid, None otherwise
    """
    manifest_path = get_manifest_path(worktree_path)
    if not manifest_path:
        return None

    try:
        with open(manifest_path, "r") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def remove_links(worktree_path: str, remove_copies: bool = True) -> Tuple[int, int, List[str]]:
    """
    Remove all links (symlinks and optionally copies) listed in the manifest.

    Args:
        worktree_path: Path to the worktree root
        remove_copies: If True, also remove copied files. If False, only remove symlinks.

    Returns:
        Tuple of (removed_count, failed_count, error_messages)
    """
    import shutil

    manifest = read_manifest(worktree_path)
    if not manifest:
        return 0, 0, ["No manifest file found"]

    removed = 0
    failed = 0
    errors = []

    # Support both "links" (new) and "symlinks" (legacy) keys
    links = manifest.get("links", manifest.get("symlinks", []))

    for link in links:
        target_path = os.path.join(worktree_path, link["target"])
        link_type = link.get("type", LINK_TYPE_SYMLINK)

        try:
            if os.path.islink(target_path):
                os.remove(target_path)
                removed += 1
            elif os.path.exists(target_path):
                if link_type == LINK_TYPE_COPY and remove_copies:
                    # Remove copied file or directory
                    if os.path.isdir(target_path):
                        shutil.rmtree(target_path)
                    else:
                        os.remove(target_path)
                    removed += 1
                elif link_type == LINK_TYPE_COPY and not remove_copies:
                    errors.append(f"Skipped copy (use remove_copies=True): {link['target']}")
                    failed += 1
                else:
                    errors.append(f"Not a symlink: {link['target']}")
                    failed += 1
            else:
                # Already gone, count as success
                removed += 1
        except OSError as e:
            errors.append(f"Error removing {link['target']}: {e}")
            failed += 1

    # Remove manifest file from git directory
    manifest_path = get_manifest_path(worktree_path)
    if manifest_path:
        try:
            os.remove(manifest_path)
        except OSError:
            pass

    return removed, failed, errors


def remove_symlinks(worktree_path: str) -> Tuple[int, int, List[str]]:
    """
    Remove all links listed in the manifest.

    This is an alias for remove_links for backward compatibility.

    Args:
        worktree_path: Path to the worktree root

    Returns:
        Tuple of (removed_count, failed_count, error_messages)
    """
    return remove_links(worktree_path, remove_copies=True)


def get_link_status(worktree_path: str) -> Dict:
    """
    Get status of links (symlinks and copies) in a worktree.

    Args:
        worktree_path: Path to the worktree root

    Returns:
        Dict with 'count', 'symlinks', 'copies', 'valid', 'broken', 'missing', and 'source' keys
    """
    manifest = read_manifest(worktree_path)
    if not manifest:
        return {
            "count": 0,
            "symlinks": 0,
            "copies": 0,
            "valid": 0,
            "broken": 0,
            "missing": 0,
            "source": None,
        }

    # Support both "links" (new) and "symlinks" (legacy) keys
    links = manifest.get("links", manifest.get("symlinks", []))

    symlink_count = 0
    copy_count = 0
    valid = 0
    broken = 0
    missing = 0

    for link in links:
        target_path = os.path.join(worktree_path, link["target"])
        link_type = link.get("type", LINK_TYPE_SYMLINK)

        if link_type == LINK_TYPE_SYMLINK:
            symlink_count += 1
            if os.path.islink(target_path):
                if os.path.exists(target_path):
                    valid += 1
                else:
                    broken += 1
            elif not os.path.exists(target_path):
                missing += 1
        else:  # copy
            copy_count += 1
            if os.path.exists(target_path):
                valid += 1
            else:
                missing += 1

    return {
        "count": len(links),
        "symlinks": symlink_count,
        "copies": copy_count,
        "valid": valid,
        "broken": broken,
        "missing": missing,
        "source": manifest.get("source_worktree"),
    }


def get_symlink_status(worktree_path: str) -> Dict:
    """
    Get status of links in a worktree.

    This is an alias for get_link_status for backward compatibility.

    Args:
        worktree_path: Path to the worktree root

    Returns:
        Dict with 'count', 'valid', 'broken', and 'source' keys
    """
    status = get_link_status(worktree_path)
    # Return backward-compatible format
    return {
        "count": status["count"],
        "valid": status["valid"],
        "broken": status["broken"],
        "source": status["source"],
    }


def get_worktree_git_dir(path: str) -> Optional[str]:
    """
    Get the git directory for a worktree.

    For linked worktrees, this returns .git/worktrees/<name>/.
    For the main worktree, this returns .git/.

    Args:
        path: Path within a worktree

    Returns:
        Absolute path to the git directory, or None if not in a git repo
    """
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=path,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return None

        git_dir = result.stdout.strip()
        return os.path.abspath(os.path.join(path, git_dir))
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, OSError):
        return None


def is_worktree(path: str) -> bool:
    """
    Check if a path is a git worktree (not the main repo).

    Args:
        path: Path to check

    Returns:
        True if this is a linked worktree, False if main repo or not a git repo
    """
    try:
        git_dir = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=path,
            capture_output=True,
            text=True,
            timeout=5,
        )
        common_dir = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=path,
            capture_output=True,
            text=True,
            timeout=5,
        )

        if git_dir.returncode != 0 or common_dir.returncode != 0:
            return False

        git_dir_path = git_dir.stdout.strip()
        common_dir_path = common_dir.stdout.strip()

        # In a worktree, these are different
        # Normalize paths for comparison
        git_dir_abs = os.path.abspath(os.path.join(path, git_dir_path))
        common_dir_abs = os.path.abspath(os.path.join(path, common_dir_path))

        return git_dir_abs != common_dir_abs
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, OSError):
        return False


def get_main_worktree(path: str) -> Optional[str]:
    """
    Get the path to the main worktree from any worktree.

    Args:
        path: Path within any worktree

    Returns:
        Absolute path to the main worktree, or None if not in a git repo
    """
    try:
        result = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            cwd=path,
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode != 0:
            return None

        # First worktree line is the main worktree
        for line in result.stdout.strip().split("\n"):
            if line.startswith("worktree "):
                return line[9:]  # Remove "worktree " prefix

        return None
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, OSError):
        return None


if __name__ == "__main__":
    # Simple CLI for testing
    import sys

    if len(sys.argv) < 2:
        print("Usage: symlink_manager.py <command> [args]")
        print("Commands:")
        print("  status <worktree_path>  - Show symlink status")
        print("  list <repo_path>        - List gitignored files")
        print("  categorize <repo_path>  - Categorize gitignored files")
        sys.exit(1)

    command = sys.argv[1]

    if command == "status" and len(sys.argv) >= 3:
        status = get_symlink_status(sys.argv[2])
        print(json.dumps(status, indent=2))
    elif command == "list" and len(sys.argv) >= 3:
        files = get_gitignored_files(sys.argv[2])
        for f in files:
            print(f)
    elif command == "categorize" and len(sys.argv) >= 3:
        files = get_gitignored_files(sys.argv[2])
        categories = categorize_files(files, sys.argv[2])
        print(json.dumps(categories, indent=2))
    else:
        print(f"Unknown command or missing arguments: {command}")
        sys.exit(1)
