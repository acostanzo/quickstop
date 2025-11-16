"""Configuration management for Courtney."""

import json
import logging
import os
from pathlib import Path
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class Config:
    """Configuration loader for Courtney."""

    DEFAULT_CONFIG = {
        "adapter": "sqlite",
        "sqlite": {
            "path": "~/.claude/courtney.db"
        }
    }

    def __init__(self, config_path: Optional[str] = None):
        """Initialize configuration.

        Args:
            config_path: Path to config file. If None, uses default locations.
        """
        self.config: Dict[str, Any] = self.DEFAULT_CONFIG.copy()

        # Try to load from config file
        if config_path:
            self._load_from_file(config_path)
        else:
            # Try default locations in order
            default_paths = [
                os.path.expanduser("~/.claude/courtney.json"),
                os.path.join(os.getcwd(), ".claude", "courtney.json"),
            ]
            for path in default_paths:
                if os.path.exists(path):
                    self._load_from_file(path)
                    break

    def _load_from_file(self, path: str) -> None:
        """Load configuration from a JSON file."""
        try:
            with open(path, 'r') as f:
                user_config = json.load(f)
                self.config.update(user_config)
        except (IOError, json.JSONDecodeError) as e:
            # If config file is invalid, use defaults
            logger.warning(f"Could not load config from {path}: {e}")

    def get(self, key: str, default: Any = None) -> Any:
        """Get a configuration value.

        Args:
            key: Configuration key (supports dot notation, e.g., 'sqlite.path')
            default: Default value if key not found

        Returns:
            Configuration value or default
        """
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value

    def get_adapter_type(self) -> str:
        """Get the configured adapter type."""
        return self.config.get("adapter", "sqlite")

    def get_adapter_config(self) -> Dict[str, Any]:
        """Get the configuration for the current adapter."""
        adapter_type = self.get_adapter_type()
        return self.config.get(adapter_type, {})

    @staticmethod
    def create_default_config(path: str) -> None:
        """Create a default configuration file.

        Args:
            path: Path where to create the config file
        """
        path = os.path.expanduser(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)

        with open(path, 'w') as f:
            json.dump(Config.DEFAULT_CONFIG, f, indent=2)
