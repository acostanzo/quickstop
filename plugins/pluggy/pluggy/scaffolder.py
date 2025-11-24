"""Plugin scaffolding logic for Pluggy."""

import json
import os
from pathlib import Path
from typing import Dict, Any, Optional


class PluginScaffolder:
    """Scaffolds new Claude Code plugins from templates."""

    def __init__(self, plugin_name: str, base_path: str = "."):
        """Initialize scaffolder.

        Args:
            plugin_name: Name of the plugin to create
            base_path: Base path where plugin will be created
        """
        self.plugin_name = plugin_name
        self.base_path = Path(base_path)
        self.plugin_path = self.base_path / plugin_name

    def create_basic_plugin(self, description: str = "", author_name: str = "", author_email: str = "") -> Path:
        """Create a basic plugin structure.

        Args:
            description: Plugin description
            author_name: Author name
            author_email: Author email

        Returns:
            Path to created plugin directory
        """
        # Create directory structure
        self._create_directory_structure()

        # Create manifest
        self._create_manifest(description, author_name, author_email)

        # Create basic Python package
        self._create_python_package()

        # Create documentation
        self._create_basic_docs()

        # Create setup files
        self._create_setup_files()

        return self.plugin_path

    def _create_directory_structure(self) -> None:
        """Create basic plugin directory structure."""
        directories = [
            self.plugin_path,
            self.plugin_path / ".claude-plugin",
            self.plugin_path / "commands",
            self.plugin_path / "hooks",
            self.plugin_path / self.plugin_name,
        ]

        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)

    def _create_manifest(self, description: str, author_name: str, author_email: str) -> None:
        """Create plugin.json manifest.

        Args:
            description: Plugin description
            author_name: Author name
            author_email: Author email
        """
        manifest = {
            "name": self.plugin_name,
            "description": description or f"A Claude Code plugin: {self.plugin_name}",
            "version": "0.1.0",
        }

        if author_name or author_email:
            manifest["author"] = {}
            if author_name:
                manifest["author"]["name"] = author_name
            if author_email:
                manifest["author"]["email"] = author_email

        manifest["keywords"] = [self.plugin_name]
        manifest["license"] = "MIT"

        manifest_path = self.plugin_path / ".claude-plugin" / "plugin.json"
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)

    def _create_python_package(self) -> None:
        """Create basic Python package structure."""
        # Create __init__.py
        init_path = self.plugin_path / self.plugin_name / "__init__.py"
        with open(init_path, 'w') as f:
            f.write(f'"""{self.plugin_name.capitalize()} - A Claude Code plugin."""\n\n')
            f.write('__version__ = "0.1.0"\n')

    def _create_basic_docs(self) -> None:
        """Create basic documentation files."""
        # Create README.md
        readme_path = self.plugin_path / "README.md"
        readme_content = f"""# {self.plugin_name.capitalize()}

A Claude Code plugin.

## Installation

```bash
# Add the marketplace (if not already added)
/plugin marketplace add <marketplace-url>

# Install the plugin
/plugin install {self.plugin_name}@<marketplace-name>
```

## Usage

[Add usage instructions here]

## Development

To develop this plugin locally:

```bash
# Clone or create the plugin
git clone <repository-url>

# Add as local marketplace
/plugin marketplace add ./<marketplace-dir>

# Install
/plugin install {self.plugin_name}@<marketplace-name>
```

## License

MIT
"""
        with open(readme_path, 'w') as f:
            f.write(readme_content)

    def _create_setup_files(self) -> None:
        """Create setup.py and requirements.txt."""
        # Create setup.py
        setup_path = self.plugin_path / "setup.py"
        setup_content = f'''"""Setup configuration for {self.plugin_name}."""

from setuptools import setup, find_packages
from pathlib import Path

# Read the README file
readme_path = Path(__file__).parent / "README.md"
long_description = readme_path.read_text() if readme_path.exists() else ""

setup(
    name="{self.plugin_name}",
    version="0.1.0",
    packages=find_packages(),
    python_requires=">=3.7",
    description="A Claude Code plugin",
    long_description=long_description,
    long_description_content_type="text/markdown",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    license="MIT",
)
'''
        with open(setup_path, 'w') as f:
            f.write(setup_content)

        # Create requirements.txt
        requirements_path = self.plugin_path / "requirements.txt"
        with open(requirements_path, 'w') as f:
            f.write(f"# Dependencies for {self.plugin_name}\n")
            f.write("# Minimum Python version: 3.7\n")

    def add_command(self, command_name: str, description: str = "", allowed_tools: str = "") -> Path:
        """Add a slash command to the plugin.

        Args:
            command_name: Name of the command (without leading slash)
            description: Command description
            allowed_tools: Comma-separated list of allowed tools

        Returns:
            Path to created command file
        """
        command_path = self.plugin_path / "commands" / f"{command_name}.md"

        content = "---\n"
        content += f"description: {description or f'{command_name} command'}\n"
        if allowed_tools:
            content += f"allowed-tools: {allowed_tools}\n"
        content += "---\n\n"
        content += f"# {command_name.capitalize()} Command\n\n"
        content += f"[Add command instructions for Claude here]\n\n"
        content += "## Parameters\n\n"
        content += "**Arguments**: `$ARGUMENTS`\n\n"
        content += "## Your Task\n\n"
        content += "1. [Step 1]\n"
        content += "2. [Step 2]\n"

        with open(command_path, 'w') as f:
            f.write(content)

        return command_path

    def add_hook(self, hook_type: str, script_path: str = "hooks/hook.py") -> None:
        """Add a hook configuration to the plugin.

        Args:
            hook_type: Type of hook (SessionStart, UserPromptSubmit, etc.)
            script_path: Path to hook script relative to plugin root
        """
        hooks_json_path = self.plugin_path / "hooks" / "hooks.json"

        # Load existing hooks.json or create new one
        if hooks_json_path.exists():
            with open(hooks_json_path, 'r') as f:
                hooks_config = json.load(f)
        else:
            hooks_config = {"hooks": {}}

        # Add new hook
        if hook_type not in hooks_config["hooks"]:
            hooks_config["hooks"][hook_type] = []

        hook_entry = {
            "matcher": "*",
            "hooks": [
                {
                    "type": "command",
                    "command": f"${{CLAUDE_PLUGIN_ROOT}}/{script_path}"
                }
            ]
        }

        hooks_config["hooks"][hook_type].append(hook_entry)

        # Write back
        with open(hooks_json_path, 'w') as f:
            json.dump(hooks_config, f, indent=2)

        # Create hook script template if it doesn't exist
        hook_script_path = self.plugin_path / script_path
        if not hook_script_path.exists():
            hook_script_path.parent.mkdir(parents=True, exist_ok=True)
            self._create_hook_script(hook_script_path, hook_type)

    def _create_hook_script(self, script_path: Path, hook_type: str) -> None:
        """Create a hook script template.

        Args:
            script_path: Path to create script at
            hook_type: Type of hook
        """
        content = f'''#!/usr/bin/env python3
"""
Hook script for {self.plugin_name}.
Handles {hook_type} events.
"""

import sys
import json

def main():
    """Main entry point for the hook."""
    try:
        # Read hook data from stdin
        hook_data = json.load(sys.stdin)

        # Get the hook event type
        event_type = hook_data.get("hook_event_name")

        # TODO: Implement hook logic here
        # Example: process hook_data and perform actions

        # Always exit successfully (hooks should never block)
        sys.exit(0)

    except Exception as e:
        # Log error but don't block Claude Code
        print(f"Hook error: {{e}}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
'''
        with open(script_path, 'w') as f:
            f.write(content)

        # Make script executable
        os.chmod(script_path, 0o755)


class MarketplaceScaffolder:
    """Scaffolds new Claude Code marketplaces."""

    def __init__(self, marketplace_name: str, base_path: str = "."):
        """Initialize marketplace scaffolder.

        Args:
            marketplace_name: Name of the marketplace
            base_path: Base path where marketplace will be created
        """
        self.marketplace_name = marketplace_name
        self.base_path = Path(base_path)
        self.marketplace_path = self.base_path / marketplace_name

    def create_marketplace(self, description: str = "") -> Path:
        """Create a new marketplace structure.

        Args:
            description: Marketplace description

        Returns:
            Path to created marketplace directory
        """
        # Create directory structure
        self.marketplace_path.mkdir(parents=True, exist_ok=True)
        (self.marketplace_path / ".claude-plugin").mkdir(exist_ok=True)
        (self.marketplace_path / "plugins").mkdir(exist_ok=True)

        # Create marketplace.json
        manifest = {
            "name": self.marketplace_name,
            "description": description or f"{self.marketplace_name} plugin marketplace"
        }

        manifest_path = self.marketplace_path / ".claude-plugin" / "marketplace.json"
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)

        # Create README
        readme_content = f"""# {self.marketplace_name.capitalize()} Marketplace

A Claude Code plugin marketplace.

## Installation

```bash
# Add this marketplace to Claude Code
/plugin marketplace add <repository-url-or-local-path>
```

## Available Plugins

[Plugins will be listed here]

## Contributing

To add a plugin to this marketplace:

1. Create your plugin in the `plugins/` directory
2. Ensure it has a valid `.claude-plugin/plugin.json` manifest
3. Test your plugin
4. Submit a pull request

## License

MIT
"""
        readme_path = self.marketplace_path / "README.md"
        with open(readme_path, 'w') as f:
            f.write(readme_content)

        return self.marketplace_path
