"""Plugin finder for intelligent plugin discovery in marketplaces."""

import json
from pathlib import Path
from typing import Dict, Any, Optional, List


class PluginFinder:
    """Finds plugins within a marketplace or standalone context.

    This class provides intelligent plugin discovery by:
    1. Auto-detecting if we're in a marketplace or plugin directory
    2. Searching for plugins by name within the detected context
    3. Supporting both path-based and name-based lookups
    """

    def __init__(self, cwd: str = "."):
        """Initialize the finder with a working directory.

        Args:
            cwd: Current working directory to search from. Defaults to ".".
        """
        self.cwd = Path(cwd).resolve()
        self.context = self._detect_context()

    def _detect_context(self) -> Dict[str, Any]:
        """Detect if we're in a marketplace, plugin, or unknown context.

        Returns:
            Dictionary with context information:
            - type: 'marketplace', 'plugin', or 'unknown'
            - root: Path to the root directory
            - name: Name of the marketplace/plugin (if applicable)
            - plugins: List of plugins (if marketplace)
        """
        # Check current dir for plugin.json (we're inside a plugin)
        plugin_manifest = self.cwd / '.claude-plugin' / 'plugin.json'
        if plugin_manifest.exists():
            try:
                with open(plugin_manifest, 'r') as f:
                    manifest = json.load(f)
                return {
                    'type': 'plugin',
                    'root': self.cwd,
                    'name': manifest.get('name', self.cwd.name),
                    'manifest': manifest
                }
            except (json.JSONDecodeError, IOError):
                pass

        # Walk up looking for marketplace.json
        current = self.cwd
        while current != current.parent:
            mp_path = current / '.claude-plugin' / 'marketplace.json'
            if mp_path.exists():
                try:
                    with open(mp_path, 'r') as f:
                        manifest = json.load(f)
                    return {
                        'type': 'marketplace',
                        'root': current,
                        'name': manifest.get('name', current.name),
                        'plugins': manifest.get('plugins', []),
                        'manifest': manifest
                    }
                except (json.JSONDecodeError, IOError):
                    pass
            current = current.parent

        # Unknown context - just use CWD
        return {
            'type': 'unknown',
            'root': self.cwd,
            'name': None
        }

    def find_plugin(self, query: str) -> Optional[Path]:
        """Find a plugin by name or path.

        Search order:
        1. If query looks like a path (has / or \\), try as relative path
        2. If in marketplace, check ./plugins/{query}/
        3. Check direct child ./{query}/
        4. Search marketplace manifest by plugin name

        Args:
            query: Plugin name or relative path to find

        Returns:
            Absolute Path to the plugin directory, or None if not found
        """
        # 1. If it looks like a path (has / or \), try as relative path
        if '/' in query or '\\' in query:
            abs_path = (self.cwd / query).resolve()
            if self._is_valid_plugin(abs_path):
                return abs_path
            return None

        # 2. If in marketplace, check plugins/{query}/
        if self.context['type'] == 'marketplace':
            plugin_dir = self.context['root'] / 'plugins' / query
            if self._is_valid_plugin(plugin_dir):
                return plugin_dir.resolve()

        # 3. Check direct child ./{query}/
        direct = self.cwd / query
        if self._is_valid_plugin(direct):
            return direct.resolve()

        # 4. Search marketplace manifest by name
        if self.context['type'] == 'marketplace':
            for plugin in self.context.get('plugins', []):
                if plugin.get('name') == query:
                    source = plugin.get('source', '')
                    if source:
                        source_path = self.context['root'] / source
                        if self._is_valid_plugin(source_path):
                            return source_path.resolve()

        return None

    def _is_valid_plugin(self, path: Path) -> bool:
        """Check if path is a valid plugin directory.

        Args:
            path: Path to check

        Returns:
            True if the path contains a valid plugin.json manifest
        """
        manifest_path = path / '.claude-plugin' / 'plugin.json'
        return manifest_path.exists()

    def list_plugins(self) -> List[Dict[str, Any]]:
        """List all plugins in the current context.

        For marketplaces, returns plugins from the manifest plus any
        discovered plugins in the plugins/ directory.

        For plugin contexts, returns just the current plugin.

        Returns:
            List of plugin info dictionaries with name, path, and description
        """
        plugins = []

        if self.context['type'] == 'marketplace':
            # Get plugins from manifest
            manifest_plugins = {p.get('name'): p for p in self.context.get('plugins', [])}

            # Also scan plugins/ directory for any not in manifest
            plugins_dir = self.context['root'] / 'plugins'
            if plugins_dir.exists():
                for item in plugins_dir.iterdir():
                    if item.is_dir() and self._is_valid_plugin(item):
                        plugin_info = self._read_plugin_info(item)
                        if plugin_info:
                            # Merge with manifest info if available
                            name = plugin_info.get('name', item.name)
                            if name in manifest_plugins:
                                plugin_info['description'] = manifest_plugins[name].get(
                                    'description', plugin_info.get('description', '')
                                )
                            plugins.append(plugin_info)

        elif self.context['type'] == 'plugin':
            # Just return current plugin
            plugin_info = self._read_plugin_info(self.cwd)
            if plugin_info:
                plugins.append(plugin_info)

        return plugins

    def _read_plugin_info(self, path: Path) -> Optional[Dict[str, Any]]:
        """Read plugin info from a plugin directory.

        Args:
            path: Path to the plugin directory

        Returns:
            Dictionary with plugin name, path, and description, or None
        """
        manifest_path = path / '.claude-plugin' / 'plugin.json'
        try:
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
            return {
                'name': manifest.get('name', path.name),
                'path': str(path.resolve()),
                'description': manifest.get('description', ''),
                'version': manifest.get('version', '')
            }
        except (json.JSONDecodeError, IOError, FileNotFoundError):
            return None

    def get_context_summary(self) -> str:
        """Get a human-readable summary of the current context.

        Returns:
            String describing the detected context
        """
        ctx = self.context
        if ctx['type'] == 'marketplace':
            plugin_count = len(self.list_plugins())
            return f"Marketplace '{ctx['name']}' at {ctx['root']} ({plugin_count} plugins)"
        elif ctx['type'] == 'plugin':
            return f"Plugin '{ctx['name']}' at {ctx['root']}"
        else:
            return f"Unknown context at {ctx['root']}"
