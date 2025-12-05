#!/usr/bin/env python3
"""
Test suite for Pluggy - Claude Code plugin development assistant.
"""

import json
import os
import sys
import tempfile
import uuid
from pathlib import Path

# Add pluggy to path
pluggy_path = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, pluggy_path)

from pluggy.validator import PluginValidator, MarketplaceValidator, ValidationResult
from pluggy.scaffolder import PluginScaffolder, MarketplaceScaffolder
from pluggy.finder import PluginFinder


def test_validation_result():
    """Test ValidationResult class."""
    print("\nTesting ValidationResult...")

    result = ValidationResult()

    # Add messages
    result.add_error("Test error")
    result.add_warning("Test warning")
    result.add_info("Test info")

    assert len(result.errors) == 1
    assert len(result.warnings) == 1
    assert len(result.info) == 1
    assert not result.is_valid()  # Has error

    print("  ✓ ValidationResult tracks messages correctly")

    # Test valid result
    result2 = ValidationResult()
    result2.add_info("All good")
    assert result2.is_valid()  # No errors

    print("  ✓ ValidationResult.is_valid() works")

    # Test formatting
    report = result.format_report()
    assert "❌ ERRORS:" in report
    assert "⚠️  WARNINGS:" in report
    assert "ℹ️  INFO:" in report

    print("  ✓ ValidationResult formatting works")

    return True


def test_plugin_scaffolder_basic():
    """Test basic plugin scaffolding."""
    print("\nTesting PluginScaffolder (basic plugin)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_name = "test-plugin"
        scaffolder = PluginScaffolder(plugin_name, tmpdir)

        # Create basic plugin
        plugin_path = scaffolder.create_basic_plugin(
            description="Test plugin",
            author_name="Test Author",
            author_email="test@example.com"
        )

        assert plugin_path.exists()
        print(f"  ✓ Plugin directory created: {plugin_path}")

        # Check directory structure
        assert (plugin_path / ".claude-plugin").exists()
        assert (plugin_path / "commands").exists()
        assert (plugin_path / "hooks").exists()
        assert (plugin_path / plugin_name).exists()

        print("  ✓ Directory structure created")

        # Check manifest
        manifest_path = plugin_path / ".claude-plugin" / "plugin.json"
        assert manifest_path.exists()

        with open(manifest_path) as f:
            manifest = json.load(f)
            assert manifest["name"] == plugin_name
            assert manifest["description"] == "Test plugin"
            assert manifest["version"] == "0.1.0"
            assert manifest["author"]["name"] == "Test Author"
            assert manifest["author"]["email"] == "test@example.com"

        print("  ✓ Manifest created correctly")

        # Check Python package
        init_path = plugin_path / plugin_name / "__init__.py"
        assert init_path.exists()
        content = init_path.read_text()
        assert "__version__" in content

        print("  ✓ Python package created")

        # Check documentation
        assert (plugin_path / "README.md").exists()
        assert (plugin_path / "setup.py").exists()
        assert (plugin_path / "requirements.txt").exists()

        print("  ✓ Documentation files created")

    return True


def test_plugin_scaffolder_add_command():
    """Test adding commands to plugin."""
    print("\nTesting PluginScaffolder (add command)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_name = "test-plugin"
        scaffolder = PluginScaffolder(plugin_name, tmpdir)
        plugin_path = scaffolder.create_basic_plugin()

        # Add command
        command_path = scaffolder.add_command(
            command_name="hello",
            description="Hello command",
            allowed_tools="*"
        )

        assert command_path.exists()
        print(f"  ✓ Command file created: {command_path}")

        # Check content
        content = command_path.read_text()
        assert "description: Hello command" in content
        assert "allowed-tools: *" in content
        assert "# Hello Command" in content

        print("  ✓ Command content is correct")

    return True


def test_plugin_scaffolder_add_hook():
    """Test adding hooks to plugin."""
    print("\nTesting PluginScaffolder (add hook)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_name = "test-plugin"
        scaffolder = PluginScaffolder(plugin_name, tmpdir)
        plugin_path = scaffolder.create_basic_plugin()

        # Add hook
        scaffolder.add_hook(
            hook_type="SessionStart",
            script_path="hooks/session_hook.py"
        )

        # Check hooks.json
        hooks_json_path = plugin_path / "hooks" / "hooks.json"
        assert hooks_json_path.exists()

        with open(hooks_json_path) as f:
            hooks_config = json.load(f)
            assert "hooks" in hooks_config
            assert "SessionStart" in hooks_config["hooks"]

        print("  ✓ hooks.json created/updated")

        # Check hook script
        hook_script_path = plugin_path / "hooks" / "session_hook.py"
        assert hook_script_path.exists()

        content = hook_script_path.read_text()
        assert "#!/usr/bin/env python3" in content
        assert "SessionStart" in content

        # Check executable
        assert os.access(hook_script_path, os.X_OK)

        print("  ✓ Hook script created and executable")

    return True


def test_plugin_validator_valid():
    """Test validating a valid plugin."""
    print("\nTesting PluginValidator (valid plugin)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a valid plugin
        plugin_name = "valid-plugin"
        scaffolder = PluginScaffolder(plugin_name, tmpdir)
        plugin_path = scaffolder.create_basic_plugin(
            description="A valid test plugin",
            author_name="Test Author",
            author_email="test@example.com"
        )

        # Validate it
        validator = PluginValidator(str(plugin_path))
        result = validator.validate()

        print(result.format_report())

        assert result.is_valid()
        print("  ✓ Valid plugin passes validation")

        # Should have some info messages
        assert len(result.info) > 0

        print("  ✓ Validation provides info messages")

    return True


def test_plugin_validator_missing_manifest():
    """Test validating plugin with missing manifest."""
    print("\nTesting PluginValidator (missing manifest)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create directory without manifest
        plugin_path = Path(tmpdir) / "bad-plugin"
        plugin_path.mkdir()
        (plugin_path / ".claude-plugin").mkdir()

        # Validate it
        validator = PluginValidator(str(plugin_path))
        result = validator.validate()

        assert not result.is_valid()
        assert any("plugin.json" in str(e) for e in result.errors)

        print("  ✓ Missing manifest detected as error")

    return True


def test_plugin_validator_invalid_json():
    """Test validating plugin with invalid JSON."""
    print("\nTesting PluginValidator (invalid JSON)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_path = Path(tmpdir) / "bad-json-plugin"
        plugin_path.mkdir()
        (plugin_path / ".claude-plugin").mkdir()

        # Create invalid JSON
        manifest_path = plugin_path / ".claude-plugin" / "plugin.json"
        with open(manifest_path, 'w') as f:
            f.write('{"invalid": json}')

        # Validate it
        validator = PluginValidator(str(plugin_path))
        result = validator.validate()

        assert not result.is_valid()
        assert any("Invalid JSON" in str(e) for e in result.errors)

        print("  ✓ Invalid JSON detected as error")

    return True


def test_plugin_validator_missing_required_fields():
    """Test validating plugin missing required fields."""
    print("\nTesting PluginValidator (missing required fields)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_path = Path(tmpdir) / "incomplete-plugin"
        plugin_path.mkdir()
        (plugin_path / ".claude-plugin").mkdir()

        # Create manifest missing description
        manifest_path = plugin_path / ".claude-plugin" / "plugin.json"
        with open(manifest_path, 'w') as f:
            json.dump({
                "name": "incomplete-plugin",
                "version": "1.0.0"
                # missing description
            }, f)

        # Validate it
        validator = PluginValidator(str(plugin_path))
        result = validator.validate()

        assert not result.is_valid()
        assert any("description" in str(e) for e in result.errors)

        print("  ✓ Missing required field detected")

    return True


def test_plugin_validator_version_format():
    """Test version format validation."""
    print("\nTesting PluginValidator (version format)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_path = Path(tmpdir) / "version-plugin"
        plugin_path.mkdir()
        (plugin_path / ".claude-plugin").mkdir()

        # Create manifest with non-semver version
        manifest_path = plugin_path / ".claude-plugin" / "plugin.json"
        with open(manifest_path, 'w') as f:
            json.dump({
                "name": "version-plugin",
                "description": "Test",
                "version": "1.0"  # Not x.y.z
            }, f)

        # Validate it
        validator = PluginValidator(str(plugin_path))
        result = validator.validate()

        # Should have warning about version format
        assert any("semantic versioning" in str(w).lower() for w in result.warnings)

        print("  ✓ Version format warning issued")

    return True


def test_marketplace_scaffolder():
    """Test marketplace scaffolding."""
    print("\nTesting MarketplaceScaffolder...")

    with tempfile.TemporaryDirectory() as tmpdir:
        marketplace_name = "test-marketplace"
        scaffolder = MarketplaceScaffolder(marketplace_name, tmpdir)

        # Create marketplace
        marketplace_path = scaffolder.create_marketplace(
            description="Test marketplace"
        )

        assert marketplace_path.exists()
        print(f"  ✓ Marketplace directory created: {marketplace_path}")

        # Check structure
        assert (marketplace_path / ".claude-plugin").exists()
        assert (marketplace_path / "plugins").exists()

        print("  ✓ Marketplace structure created")

        # Check manifest
        manifest_path = marketplace_path / ".claude-plugin" / "marketplace.json"
        assert manifest_path.exists()

        with open(manifest_path) as f:
            manifest = json.load(f)
            assert manifest["name"] == marketplace_name
            assert manifest["description"] == "Test marketplace"

        print("  ✓ Marketplace manifest created")

        # Check README
        readme_path = marketplace_path / "README.md"
        assert readme_path.exists()

        print("  ✓ Marketplace README created")

    return True


def test_marketplace_validator():
    """Test marketplace validation."""
    print("\nTesting MarketplaceValidator...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a valid marketplace
        marketplace_name = "test-marketplace"
        scaffolder = MarketplaceScaffolder(marketplace_name, tmpdir)
        marketplace_path = scaffolder.create_marketplace("Test marketplace")

        # Add a plugin
        plugin_scaffolder = PluginScaffolder("test-plugin", marketplace_path / "plugins")
        plugin_scaffolder.create_basic_plugin()

        # Validate marketplace
        validator = MarketplaceValidator(str(marketplace_path))
        result = validator.validate()

        print(result.format_report())

        assert result.is_valid()
        print("  ✓ Valid marketplace passes validation")

        # Should mention the plugin
        assert any("1 plugin" in str(i) for i in result.info)

        print("  ✓ Marketplace validator detects plugins")

    return True


def test_marketplace_validator_invalid():
    """Test marketplace validation with missing manifest."""
    print("\nTesting MarketplaceValidator (invalid marketplace)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create directory without marketplace.json
        marketplace_path = Path(tmpdir) / "bad-marketplace"
        marketplace_path.mkdir()
        (marketplace_path / ".claude-plugin").mkdir()

        # Validate it
        validator = MarketplaceValidator(str(marketplace_path))
        result = validator.validate()

        assert not result.is_valid()
        assert any("marketplace.json" in str(e) for e in result.errors)

        print("  ✓ Missing marketplace.json detected")

    return True


def test_command_frontmatter_validation():
    """Test command file frontmatter validation."""
    print("\nTesting command frontmatter validation...")

    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_name = "cmd-plugin"
        scaffolder = PluginScaffolder(plugin_name, tmpdir)
        plugin_path = scaffolder.create_basic_plugin()

        # Add command with frontmatter
        cmd_path = plugin_path / "commands" / "test.md"
        with open(cmd_path, 'w') as f:
            f.write("---\n")
            f.write("description: Test command\n")
            f.write("---\n")
            f.write("# Test Command\n")

        # Validate
        validator = PluginValidator(str(plugin_path))
        result = validator.validate()

        # Should mention frontmatter in info
        assert any("frontmatter" in str(i).lower() for i in result.info)

        print("  ✓ Command frontmatter detected")

    return True


def test_plugin_scaffolder_marketplace_registration():
    """Test automatic marketplace registration when scaffolding inside a marketplace."""
    print("\nTesting PluginScaffolder (marketplace registration)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a marketplace first
        marketplace_name = "test-marketplace"
        marketplace_scaffolder = MarketplaceScaffolder(marketplace_name, tmpdir)
        marketplace_path = marketplace_scaffolder.create_marketplace("Test marketplace")

        # Update the marketplace manifest to include plugins array
        manifest_path = marketplace_path / ".claude-plugin" / "marketplace.json"
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        manifest["plugins"] = []
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)

        # Scaffold a plugin inside the marketplace's plugins directory
        plugins_dir = marketplace_path / "plugins"
        plugin_scaffolder = PluginScaffolder("my-new-plugin", str(plugins_dir))
        plugin_path = plugin_scaffolder.create_basic_plugin(
            description="A brand new plugin"
        )

        assert plugin_path.exists()
        print(f"  ✓ Plugin created: {plugin_path}")

        # Check that the marketplace manifest was updated
        with open(manifest_path, 'r') as f:
            updated_manifest = json.load(f)

        plugins = updated_manifest.get("plugins", [])
        assert len(plugins) == 1, f"Expected 1 plugin, got {len(plugins)}"

        plugin_entry = plugins[0]
        assert plugin_entry["name"] == "my-new-plugin"
        assert plugin_entry["source"] == "./plugins/my-new-plugin"
        assert plugin_entry["description"] == "A brand new plugin"

        print("  ✓ Plugin registered in marketplace.json")

        # Create another plugin to verify it appends correctly
        plugin_scaffolder2 = PluginScaffolder("another-plugin", str(plugins_dir))
        plugin_scaffolder2.create_basic_plugin(description="Another plugin")

        with open(manifest_path, 'r') as f:
            updated_manifest = json.load(f)

        plugins = updated_manifest.get("plugins", [])
        assert len(plugins) == 2, f"Expected 2 plugins, got {len(plugins)}"

        print("  ✓ Second plugin appended to marketplace.json")

    return True


def test_finder_detects_marketplace_context():
    """Test PluginFinder detects marketplace context."""
    print("\nTesting PluginFinder (marketplace context)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a marketplace
        marketplace_scaffolder = MarketplaceScaffolder("test-marketplace", tmpdir)
        marketplace_path = marketplace_scaffolder.create_marketplace("Test marketplace")

        # Add plugins list to manifest
        manifest_path = marketplace_path / ".claude-plugin" / "marketplace.json"
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
        manifest["plugins"] = [
            {"name": "plugin-a", "source": "./plugins/plugin-a", "description": "Plugin A"}
        ]
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)

        # Test from marketplace root
        finder = PluginFinder(str(marketplace_path))
        assert finder.context['type'] == 'marketplace'
        assert finder.context['name'] == 'test-marketplace'
        assert finder.context['root'].resolve() == marketplace_path.resolve()

        print("  ✓ Detects marketplace from root")

        # Test from plugins subdirectory
        plugins_dir = marketplace_path / "plugins"
        finder2 = PluginFinder(str(plugins_dir))
        assert finder2.context['type'] == 'marketplace'
        assert finder2.context['root'].resolve() == marketplace_path.resolve()

        print("  ✓ Detects marketplace from subdirectory")

    return True


def test_finder_detects_plugin_context():
    """Test PluginFinder detects plugin context."""
    print("\nTesting PluginFinder (plugin context)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a plugin
        plugin_scaffolder = PluginScaffolder("my-plugin", tmpdir)
        plugin_path = plugin_scaffolder.create_basic_plugin(description="My plugin")

        # Test from plugin root
        finder = PluginFinder(str(plugin_path))
        assert finder.context['type'] == 'plugin'
        assert finder.context['name'] == 'my-plugin'
        assert finder.context['root'].resolve() == plugin_path.resolve()

        print("  ✓ Detects plugin context correctly")

    return True


def test_finder_detects_unknown_context():
    """Test PluginFinder handles unknown context."""
    print("\nTesting PluginFinder (unknown context)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Empty directory - no plugin or marketplace
        finder = PluginFinder(tmpdir)
        assert finder.context['type'] == 'unknown'
        assert finder.context['root'] == Path(tmpdir).resolve()

        print("  ✓ Handles unknown context correctly")

    return True


def test_finder_finds_plugin_by_name():
    """Test PluginFinder finds plugin by name in marketplace."""
    print("\nTesting PluginFinder (find by name)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a marketplace with plugins
        marketplace_scaffolder = MarketplaceScaffolder("test-marketplace", tmpdir)
        marketplace_path = marketplace_scaffolder.create_marketplace()

        # Create plugin in plugins/
        plugins_dir = marketplace_path / "plugins"
        plugin_scaffolder = PluginScaffolder("arborist", str(plugins_dir))
        plugin_path = plugin_scaffolder.create_basic_plugin(description="Tree plugin")

        # Test finder from marketplace root
        finder = PluginFinder(str(marketplace_path))

        # Find by exact name
        found = finder.find_plugin("arborist")
        assert found is not None
        assert found == plugin_path.resolve()

        print("  ✓ Finds plugin by name")

        # Should not find non-existent plugin
        not_found = finder.find_plugin("nonexistent")
        assert not_found is None

        print("  ✓ Returns None for non-existent plugin")

    return True


def test_finder_finds_plugin_by_path():
    """Test PluginFinder finds plugin by relative path."""
    print("\nTesting PluginFinder (find by path)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a marketplace with plugins
        marketplace_scaffolder = MarketplaceScaffolder("test-marketplace", tmpdir)
        marketplace_path = marketplace_scaffolder.create_marketplace()

        # Create plugin
        plugins_dir = marketplace_path / "plugins"
        plugin_scaffolder = PluginScaffolder("my-plugin", str(plugins_dir))
        plugin_path = plugin_scaffolder.create_basic_plugin()

        # Test finder
        finder = PluginFinder(str(marketplace_path))

        # Find by relative path
        found = finder.find_plugin("plugins/my-plugin")
        assert found is not None
        assert found == plugin_path.resolve()

        print("  ✓ Finds plugin by relative path")

    return True


def test_finder_lists_plugins():
    """Test PluginFinder lists all plugins in marketplace."""
    print("\nTesting PluginFinder (list plugins)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a marketplace
        marketplace_scaffolder = MarketplaceScaffolder("test-marketplace", tmpdir)
        marketplace_path = marketplace_scaffolder.create_marketplace()

        # Create multiple plugins
        plugins_dir = marketplace_path / "plugins"
        for name in ["alpha", "beta", "gamma"]:
            scaffolder = PluginScaffolder(name, str(plugins_dir))
            scaffolder.create_basic_plugin(description=f"{name.capitalize()} plugin")

        # Test listing
        finder = PluginFinder(str(marketplace_path))
        plugins = finder.list_plugins()

        assert len(plugins) == 3
        names = [p['name'] for p in plugins]
        assert 'alpha' in names
        assert 'beta' in names
        assert 'gamma' in names

        print("  ✓ Lists all plugins correctly")

        # Each plugin should have path and description
        for plugin in plugins:
            assert 'path' in plugin
            assert 'description' in plugin

        print("  ✓ Plugin info includes path and description")

    return True


def test_finder_context_summary():
    """Test PluginFinder context summary."""
    print("\nTesting PluginFinder (context summary)...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create a marketplace
        marketplace_scaffolder = MarketplaceScaffolder("my-marketplace", tmpdir)
        marketplace_path = marketplace_scaffolder.create_marketplace()

        finder = PluginFinder(str(marketplace_path))
        summary = finder.get_context_summary()

        assert "Marketplace" in summary
        assert "my-marketplace" in summary

        print("  ✓ Context summary is descriptive")

    return True


def main():
    """Run all tests."""
    print("=" * 60)
    print("Pluggy Test Suite")
    print("=" * 60)

    tests = [
        ("ValidationResult", test_validation_result),
        ("PluginScaffolder - Basic", test_plugin_scaffolder_basic),
        ("PluginScaffolder - Add Command", test_plugin_scaffolder_add_command),
        ("PluginScaffolder - Add Hook", test_plugin_scaffolder_add_hook),
        ("PluginValidator - Valid Plugin", test_plugin_validator_valid),
        ("PluginValidator - Missing Manifest", test_plugin_validator_missing_manifest),
        ("PluginValidator - Invalid JSON", test_plugin_validator_invalid_json),
        ("PluginValidator - Missing Fields", test_plugin_validator_missing_required_fields),
        ("PluginValidator - Version Format", test_plugin_validator_version_format),
        ("MarketplaceScaffolder", test_marketplace_scaffolder),
        ("MarketplaceValidator - Valid", test_marketplace_validator),
        ("MarketplaceValidator - Invalid", test_marketplace_validator_invalid),
        ("Command Frontmatter", test_command_frontmatter_validation),
        ("PluginScaffolder - Marketplace Registration", test_plugin_scaffolder_marketplace_registration),
        ("PluginFinder - Marketplace Context", test_finder_detects_marketplace_context),
        ("PluginFinder - Plugin Context", test_finder_detects_plugin_context),
        ("PluginFinder - Unknown Context", test_finder_detects_unknown_context),
        ("PluginFinder - Find by Name", test_finder_finds_plugin_by_name),
        ("PluginFinder - Find by Path", test_finder_finds_plugin_by_path),
        ("PluginFinder - List Plugins", test_finder_lists_plugins),
        ("PluginFinder - Context Summary", test_finder_context_summary),
    ]

    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n❌ {test_name} failed with exception: {e}")
            import traceback
            traceback.print_exc()
            results.append((test_name, False))

    # Print summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "✓ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")

    print(f"\n{passed}/{total} tests passed")

    # Exit with appropriate code
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
