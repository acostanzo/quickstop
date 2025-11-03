#!/usr/bin/env python3
"""
Installation script for Courtney.
Sets up the Claude Code hooks configuration.
"""

import json
import os
import sys
from pathlib import Path
import shutil


def get_courtney_path():
    """Get the absolute path to the Courtney directory."""
    return os.path.dirname(os.path.abspath(__file__))


def get_hook_script_path():
    """Get the absolute path to the hook script."""
    return os.path.join(get_courtney_path(), "courtney", "hooks", "courtney_hook.py")


def read_settings(settings_path):
    """Read existing Claude Code settings."""
    if os.path.exists(settings_path):
        with open(settings_path, 'r') as f:
            return json.load(f)
    return {}


def write_settings(settings_path, settings):
    """Write Claude Code settings."""
    Path(settings_path).parent.mkdir(parents=True, exist_ok=True)
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)


def add_courtney_hooks(settings, hook_script_path):
    """Add Courtney hooks to the settings."""
    if "hooks" not in settings:
        settings["hooks"] = {}

    # Hook configuration for all events
    hook_config = {
        "type": "command",
        "command": hook_script_path
    }

    # Events that need Courtney hooks
    # Only recording user prompts and AI responses (not tool calls)
    events = [
        "SessionStart",
        "SessionEnd",
        "UserPromptSubmit",
        "Stop",
        "SubagentStop"
    ]

    for event in events:
        if event not in settings["hooks"]:
            settings["hooks"][event] = []

        # Check if Courtney hook already exists
        courtney_exists = any(
            hook.get("command") == hook_script_path
            for matcher_group in settings["hooks"][event]
            for hook in matcher_group.get("hooks", [])
        )

        if not courtney_exists:
            # Add Courtney hook
            settings["hooks"][event].append({
                "matcher": "*",  # Match all tools/events
                "hooks": [hook_config]
            })

    return settings


def create_default_config():
    """Create default Courtney configuration file."""
    config_path = os.path.expanduser("~/.claude/courtney.json")
    if not os.path.exists(config_path):
        Path(config_path).parent.mkdir(parents=True, exist_ok=True)
        default_config = {
            "adapter": "sqlite",
            "sqlite": {
                "path": "~/.claude/courtney.db"
            }
        }
        with open(config_path, 'w') as f:
            json.dump(default_config, f, indent=2)
        print(f"✓ Created default config at {config_path}")
    else:
        print(f"✓ Config already exists at {config_path}")


def install_global():
    """Install Courtney globally (all Claude Code sessions)."""
    settings_path = os.path.expanduser("~/.claude/settings.json")
    hook_script_path = get_hook_script_path()

    print(f"Installing Courtney globally...")
    print(f"Hook script: {hook_script_path}")
    print(f"Settings file: {settings_path}")

    # Read existing settings
    settings = read_settings(settings_path)

    # Add Courtney hooks
    settings = add_courtney_hooks(settings, hook_script_path)

    # Write updated settings
    write_settings(settings_path, settings)

    # Create default config
    create_default_config()

    print("\n✓ Courtney installed globally!")
    print("\nCourtney will now record all your Claude Code conversations.")
    print(f"Database location: ~/.claude/courtney.db")
    print(f"Config location: ~/.claude/courtney.json")


def install_project():
    """Install Courtney for the current project only."""
    project_dir = os.getcwd()
    settings_path = os.path.join(project_dir, ".claude", "settings.json")
    hook_script_path = get_hook_script_path()

    print(f"Installing Courtney for project: {project_dir}")
    print(f"Hook script: {hook_script_path}")
    print(f"Settings file: {settings_path}")

    # Read existing settings
    settings = read_settings(settings_path)

    # Add Courtney hooks
    settings = add_courtney_hooks(settings, hook_script_path)

    # Write updated settings
    write_settings(settings_path, settings)

    # Create default config
    create_default_config()

    print("\n✓ Courtney installed for this project!")
    print("\nCourtney will record Claude Code conversations in this project.")
    print(f"Database location: ~/.claude/courtney.db")
    print(f"Config location: ~/.claude/courtney.json")


def main():
    """Main installation flow."""
    print("=" * 60)
    print("Courtney Installation")
    print("Your agentic workflow stenographer")
    print("=" * 60)
    print()

    if len(sys.argv) > 1 and sys.argv[1] == "--project":
        install_project()
    else:
        print("Install Courtney:")
        print("  1. Globally (all Claude Code sessions)")
        print("  2. Project only (current directory)")
        print()

        choice = input("Enter choice (1 or 2): ").strip()

        if choice == "1":
            install_global()
        elif choice == "2":
            install_project()
        else:
            print("Invalid choice. Exiting.")
            sys.exit(1)

    print("\nTo customize the database location, edit: ~/.claude/courtney.json")


if __name__ == "__main__":
    main()
