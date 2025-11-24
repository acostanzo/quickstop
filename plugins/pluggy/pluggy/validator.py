"""Plugin validation logic for Pluggy."""

import json
import os
from pathlib import Path
from typing import Dict, List, Tuple, Any, Optional


class ValidationResult:
    """Result of a validation check."""

    def __init__(self):
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []

    def add_error(self, message: str) -> None:
        """Add an error message."""
        self.errors.append(message)

    def add_warning(self, message: str) -> None:
        """Add a warning message."""
        self.warnings.append(message)

    def add_info(self, message: str) -> None:
        """Add an info message."""
        self.info.append(message)

    def is_valid(self) -> bool:
        """Check if validation passed (no errors)."""
        return len(self.errors) == 0

    def format_report(self) -> str:
        """Format validation results as a readable report."""
        lines = []

        if self.errors:
            lines.append("❌ ERRORS:")
            for error in self.errors:
                lines.append(f"  • {error}")
            lines.append("")

        if self.warnings:
            lines.append("⚠️  WARNINGS:")
            for warning in self.warnings:
                lines.append(f"  • {warning}")
            lines.append("")

        if self.info:
            lines.append("ℹ️  INFO:")
            for info in self.info:
                lines.append(f"  • {info}")
            lines.append("")

        if self.is_valid():
            lines.append("✅ Validation passed!")
        else:
            lines.append(f"❌ Validation failed with {len(self.errors)} error(s)")

        return "\n".join(lines)


class PluginValidator:
    """Validates Claude Code plugin structure and configuration."""

    REQUIRED_MANIFEST_FIELDS = ["name", "description", "version"]
    RECOMMENDED_MANIFEST_FIELDS = ["author", "repository", "keywords", "license"]

    def __init__(self, plugin_path: str):
        """Initialize validator.

        Args:
            plugin_path: Path to the plugin directory
        """
        self.plugin_path = Path(plugin_path)
        self.result = ValidationResult()

    def validate(self) -> ValidationResult:
        """Run all validation checks.

        Returns:
            ValidationResult with errors, warnings, and info
        """
        self._validate_directory_structure()
        self._validate_manifest()
        self._validate_commands()
        self._validate_hooks()

        return self.result

    def _validate_directory_structure(self) -> None:
        """Validate basic directory structure."""
        if not self.plugin_path.exists():
            self.result.add_error(f"Plugin directory does not exist: {self.plugin_path}")
            return

        if not self.plugin_path.is_dir():
            self.result.add_error(f"Plugin path is not a directory: {self.plugin_path}")
            return

        # Check for .claude-plugin directory
        claude_plugin_dir = self.plugin_path / ".claude-plugin"
        if not claude_plugin_dir.exists():
            self.result.add_error("Missing .claude-plugin directory")
        elif not claude_plugin_dir.is_dir():
            self.result.add_error(".claude-plugin exists but is not a directory")

        self.result.add_info(f"Validating plugin at: {self.plugin_path}")

    def _validate_manifest(self) -> None:
        """Validate plugin.json manifest."""
        manifest_path = self.plugin_path / ".claude-plugin" / "plugin.json"

        if not manifest_path.exists():
            self.result.add_error("Missing plugin.json manifest")
            return

        try:
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
        except json.JSONDecodeError as e:
            self.result.add_error(f"Invalid JSON in plugin.json: {e}")
            return
        except Exception as e:
            self.result.add_error(f"Error reading plugin.json: {e}")
            return

        # Check required fields
        for field in self.REQUIRED_MANIFEST_FIELDS:
            if field not in manifest:
                self.result.add_error(f"Missing required field in plugin.json: {field}")
            elif not manifest[field]:
                self.result.add_error(f"Empty required field in plugin.json: {field}")

        # Check recommended fields
        for field in self.RECOMMENDED_MANIFEST_FIELDS:
            if field not in manifest:
                self.result.add_warning(f"Missing recommended field in plugin.json: {field}")

        # Validate version format
        if "version" in manifest:
            version = manifest["version"]
            if not isinstance(version, str):
                self.result.add_error("Version must be a string")
            elif not self._is_valid_semver(version):
                self.result.add_warning(f"Version '{version}' doesn't follow semantic versioning (x.y.z)")

        # Validate name format
        if "name" in manifest:
            name = manifest["name"]
            if not isinstance(name, str):
                self.result.add_error("Name must be a string")
            elif not name.islower() or not name.replace("-", "").replace("_", "").isalnum():
                self.result.add_warning("Plugin name should be lowercase alphanumeric with hyphens/underscores")

        self.result.add_info(f"Manifest validation complete")

    def _validate_commands(self) -> None:
        """Validate command definitions."""
        commands_dir = self.plugin_path / "commands"

        if not commands_dir.exists():
            self.result.add_info("No commands directory found (optional)")
            return

        if not commands_dir.is_dir():
            self.result.add_warning("commands exists but is not a directory")
            return

        command_files = list(commands_dir.glob("*.md"))

        if not command_files:
            self.result.add_warning("commands directory exists but contains no .md files")
            return

        for cmd_file in command_files:
            self._validate_command_file(cmd_file)

        self.result.add_info(f"Found {len(command_files)} command(s)")

    def _validate_command_file(self, cmd_file: Path) -> None:
        """Validate a single command file.

        Args:
            cmd_file: Path to command .md file
        """
        try:
            content = cmd_file.read_text()

            # Check for frontmatter
            if content.startswith("---"):
                # Extract frontmatter
                parts = content.split("---", 2)
                if len(parts) >= 3:
                    # frontmatter exists
                    self.result.add_info(f"Command {cmd_file.stem} has frontmatter")
                else:
                    self.result.add_warning(f"Command {cmd_file.stem} has incomplete frontmatter")
            else:
                self.result.add_info(f"Command {cmd_file.stem} has no frontmatter (optional)")

        except Exception as e:
            self.result.add_error(f"Error reading command file {cmd_file.name}: {e}")

    def _validate_hooks(self) -> None:
        """Validate hook configuration."""
        hooks_dir = self.plugin_path / "hooks"

        if not hooks_dir.exists():
            self.result.add_info("No hooks directory found (optional)")
            return

        if not hooks_dir.is_dir():
            self.result.add_warning("hooks exists but is not a directory")
            return

        hooks_json = hooks_dir / "hooks.json"

        if not hooks_json.exists():
            self.result.add_warning("hooks directory exists but no hooks.json found")
            return

        try:
            with open(hooks_json, 'r') as f:
                hooks_config = json.load(f)

            if "hooks" not in hooks_config:
                self.result.add_error("hooks.json missing 'hooks' key")
                return

            hooks = hooks_config["hooks"]
            hook_count = sum(len(v) for v in hooks.values())

            self.result.add_info(f"Found {len(hooks)} hook type(s) with {hook_count} total hook(s)")

            # Validate each hook has a command
            for hook_type, hook_list in hooks.items():
                for hook in hook_list:
                    if isinstance(hook, dict) and "hooks" in hook:
                        for h in hook["hooks"]:
                            if "command" not in h:
                                self.result.add_error(f"Hook in {hook_type} missing 'command'")

        except json.JSONDecodeError as e:
            self.result.add_error(f"Invalid JSON in hooks.json: {e}")
        except Exception as e:
            self.result.add_error(f"Error reading hooks.json: {e}")

    @staticmethod
    def _is_valid_semver(version: str) -> bool:
        """Check if version follows semantic versioning.

        Args:
            version: Version string to check

        Returns:
            True if valid semver format
        """
        parts = version.split(".")
        if len(parts) != 3:
            return False

        try:
            for part in parts:
                int(part)
            return True
        except ValueError:
            return False


class MarketplaceValidator:
    """Validates Claude Code marketplace structure."""

    def __init__(self, marketplace_path: str):
        """Initialize marketplace validator.

        Args:
            marketplace_path: Path to the marketplace directory
        """
        self.marketplace_path = Path(marketplace_path)
        self.result = ValidationResult()

    def validate(self) -> ValidationResult:
        """Run all marketplace validation checks.

        Returns:
            ValidationResult with errors, warnings, and info
        """
        self._validate_marketplace_structure()
        self._validate_marketplace_manifest()
        self._validate_plugins()

        return self.result

    def _validate_marketplace_structure(self) -> None:
        """Validate marketplace directory structure."""
        if not self.marketplace_path.exists():
            self.result.add_error(f"Marketplace directory does not exist: {self.marketplace_path}")
            return

        claude_plugin_dir = self.marketplace_path / ".claude-plugin"
        if not claude_plugin_dir.exists():
            self.result.add_error("Missing .claude-plugin directory")

        plugins_dir = self.marketplace_path / "plugins"
        if not plugins_dir.exists():
            self.result.add_warning("Missing plugins directory")

    def _validate_marketplace_manifest(self) -> None:
        """Validate marketplace.json."""
        manifest_path = self.marketplace_path / ".claude-plugin" / "marketplace.json"

        if not manifest_path.exists():
            self.result.add_error("Missing marketplace.json")
            return

        try:
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)

            required_fields = ["name", "description"]
            for field in required_fields:
                if field not in manifest:
                    self.result.add_error(f"Missing required field in marketplace.json: {field}")

            self.result.add_info("Marketplace manifest is valid")

        except json.JSONDecodeError as e:
            self.result.add_error(f"Invalid JSON in marketplace.json: {e}")
        except Exception as e:
            self.result.add_error(f"Error reading marketplace.json: {e}")

    def _validate_plugins(self) -> None:
        """Validate all plugins in the marketplace."""
        plugins_dir = self.marketplace_path / "plugins"

        if not plugins_dir.exists():
            return

        plugin_dirs = [d for d in plugins_dir.iterdir() if d.is_dir() and not d.name.startswith(".")]

        if not plugin_dirs:
            self.result.add_warning("No plugins found in marketplace")
            return

        self.result.add_info(f"Found {len(plugin_dirs)} plugin(s) in marketplace")

        for plugin_dir in plugin_dirs:
            validator = PluginValidator(str(plugin_dir))
            plugin_result = validator.validate()

            if not plugin_result.is_valid():
                self.result.add_warning(f"Plugin '{plugin_dir.name}' has validation issues")
