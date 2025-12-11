#!/usr/bin/env python3
"""
Tests for Arborist plugin components.

Tests the config_manager module and session_start hook.
"""

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Add src directory to path for imports
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from config_manager import (
    ALWAYS_SKIP_PATTERNS,
    ALWAYS_SYMLINK_PATTERNS,
    ASK_THRESHOLD_BYTES,
    LINK_TYPE_COPY,
    LINK_TYPE_SYMLINK,
    MANIFEST_FILE,
    MANIFEST_VERSION,
    calculate_relative_path,
    categorize_files,
    copy_file,
    create_links,
    create_symlink,
    create_symlinks,
    get_gitignored_files,
    get_link_status,
    get_manifest_path,
    get_symlink_status,
    get_worktree_git_dir,
    is_large_file,
    is_worktree,
    matches_pattern,
    read_manifest,
    remove_links,
    remove_symlinks,
    should_skip,
    should_symlink,
    write_manifest,
)


class TestPatternMatching(unittest.TestCase):
    """Tests for pattern matching functions."""

    def test_should_skip_node_modules(self):
        """node_modules should always be skipped."""
        self.assertTrue(should_skip("node_modules/"))
        self.assertTrue(should_skip("node_modules/package/index.js"))

    def test_should_skip_vendor(self):
        """vendor directories should always be skipped."""
        self.assertTrue(should_skip("vendor/"))
        self.assertTrue(should_skip("vendor/autoload.php"))

    def test_should_skip_pycache(self):
        """Python cache should always be skipped."""
        self.assertTrue(should_skip("__pycache__/"))
        self.assertTrue(should_skip("module.pyc"))
        self.assertTrue(should_skip("test.pyo"))

    def test_should_skip_build_dirs(self):
        """Build directories should always be skipped."""
        self.assertTrue(should_skip("dist/"))
        self.assertTrue(should_skip("build/"))
        self.assertTrue(should_skip("out/"))
        self.assertTrue(should_skip("target/"))

    def test_should_skip_framework_builds(self):
        """Framework build directories should always be skipped."""
        self.assertTrue(should_skip(".next/"))
        self.assertTrue(should_skip(".nuxt/"))
        self.assertTrue(should_skip(".svelte-kit/"))

    def test_should_skip_caches(self):
        """Cache directories should always be skipped."""
        self.assertTrue(should_skip(".cache/"))
        self.assertTrue(should_skip("cache/"))
        self.assertTrue(should_skip(".eslintcache"))

    def test_should_skip_logs(self):
        """Log files should always be skipped."""
        self.assertTrue(should_skip("app.log"))
        self.assertTrue(should_skip("logs/"))
        self.assertTrue(should_skip("debug.log.1"))

    def test_should_skip_os_artifacts(self):
        """OS artifacts should always be skipped."""
        self.assertTrue(should_skip(".DS_Store"))
        self.assertTrue(should_skip("Thumbs.db"))

    def test_should_skip_git(self):
        """Git internals should always be skipped."""
        self.assertTrue(should_skip(".git/"))

    def test_should_symlink_env(self):
        """.env files should always be symlinked."""
        self.assertTrue(should_symlink(".env"))
        self.assertTrue(should_symlink(".env.local"))
        self.assertTrue(should_symlink(".env.development"))

    def test_should_symlink_credentials(self):
        """Credential files should always be symlinked."""
        self.assertTrue(should_symlink("credentials.json"))
        self.assertTrue(should_symlink("serviceAccountKey.json"))
        self.assertTrue(should_symlink("private.pem"))
        self.assertTrue(should_symlink("server.key"))

    def test_should_symlink_package_config(self):
        """Package manager configs should always be symlinked."""
        self.assertTrue(should_symlink(".npmrc"))
        self.assertTrue(should_symlink(".yarnrc"))
        self.assertTrue(should_symlink(".nvmrc"))
        self.assertTrue(should_symlink(".tool-versions"))

    def test_should_symlink_ide_settings(self):
        """IDE settings should always be symlinked."""
        self.assertTrue(should_symlink(".vscode/"))
        self.assertTrue(should_symlink(".idea/"))
        self.assertTrue(should_symlink(".vscode/settings.json"))

    def test_should_symlink_config_dirs(self):
        """Config directories should always be symlinked."""
        self.assertTrue(should_symlink("config/"))
        self.assertTrue(should_symlink("config/database.yml"))
        self.assertTrue(should_symlink("settings.local.json"))

    def test_env_file_vs_directory(self):
        """.env file should be symlinked, .env/ directory should be skipped."""
        # .env file should be symlinked
        self.assertTrue(should_symlink(".env"))
        # .env/ directory (for virtual environments) should be skipped
        self.assertTrue(should_skip(".env/"))

    def test_regular_file_not_matched(self):
        """Regular source files should not match either pattern."""
        self.assertFalse(should_skip("src/index.js"))
        self.assertFalse(should_symlink("src/index.js"))


class TestRelativePath(unittest.TestCase):
    """Tests for relative path calculation."""

    def test_sibling_directories(self):
        """Test relative path between sibling directories."""
        source = "/Users/dev/project/.env"
        target = "/Users/dev/project-feature/.env"
        result = calculate_relative_path(source, target)
        self.assertEqual(result, "../project/.env")

    def test_nested_file(self):
        """Test relative path for nested file."""
        source = "/Users/dev/project/config/database.yml"
        target = "/Users/dev/project-feature/config/database.yml"
        result = calculate_relative_path(source, target)
        self.assertEqual(result, "../../project/config/database.yml")

    def test_same_parent(self):
        """Test relative path in same parent directory."""
        source = "/Users/dev/project/.env"
        target = "/Users/dev/project/.env.backup"
        result = calculate_relative_path(source, target)
        self.assertEqual(result, ".env")


class TestSymlinkCreation(unittest.TestCase):
    """Tests for symlink creation."""

    def setUp(self):
        """Create temporary directories for testing."""
        self.temp_dir = tempfile.mkdtemp()
        self.source_dir = os.path.join(self.temp_dir, "source")
        self.target_dir = os.path.join(self.temp_dir, "target")
        os.makedirs(self.source_dir)
        os.makedirs(self.target_dir)

    def tearDown(self):
        """Clean up temporary directories."""
        shutil.rmtree(self.temp_dir)

    def test_create_symlink_success(self):
        """Test successful symlink creation."""
        # Create source file
        source_file = os.path.join(self.source_dir, ".env")
        with open(source_file, "w") as f:
            f.write("SECRET=value")

        target_file = os.path.join(self.target_dir, ".env")
        success, message = create_symlink(source_file, target_file)

        self.assertTrue(success)
        self.assertTrue(os.path.islink(target_file))
        self.assertTrue(os.path.exists(target_file))

    def test_create_symlink_source_not_exists(self):
        """Test symlink creation fails when source doesn't exist."""
        source_file = os.path.join(self.source_dir, "nonexistent")
        target_file = os.path.join(self.target_dir, ".env")

        success, message = create_symlink(source_file, target_file)

        self.assertFalse(success)
        self.assertIn("does not exist", message)

    def test_create_symlink_target_exists(self):
        """Test symlink creation fails when target already exists."""
        source_file = os.path.join(self.source_dir, ".env")
        target_file = os.path.join(self.target_dir, ".env")

        with open(source_file, "w") as f:
            f.write("SECRET=value")
        with open(target_file, "w") as f:
            f.write("OTHER=value")

        success, message = create_symlink(source_file, target_file)

        self.assertFalse(success)
        self.assertIn("already exists", message)

    def test_create_symlink_dry_run(self):
        """Test dry run doesn't create actual symlink."""
        source_file = os.path.join(self.source_dir, ".env")
        target_file = os.path.join(self.target_dir, ".env")

        with open(source_file, "w") as f:
            f.write("SECRET=value")

        success, message = create_symlink(source_file, target_file, dry_run=True)

        self.assertTrue(success)
        self.assertIn("Would create", message)
        self.assertFalse(os.path.exists(target_file))

    def test_create_symlink_nested_directory(self):
        """Test symlink creation with nested target directory."""
        source_file = os.path.join(self.source_dir, "config", "database.yml")
        os.makedirs(os.path.dirname(source_file))
        with open(source_file, "w") as f:
            f.write("db: postgres")

        target_file = os.path.join(self.target_dir, "config", "database.yml")
        success, message = create_symlink(source_file, target_file)

        self.assertTrue(success)
        self.assertTrue(os.path.islink(target_file))


class TestCopyFile(unittest.TestCase):
    """Tests for file copying."""

    def setUp(self):
        """Create temporary directories for testing."""
        self.temp_dir = tempfile.mkdtemp()
        self.source_dir = os.path.join(self.temp_dir, "source")
        self.target_dir = os.path.join(self.temp_dir, "target")
        os.makedirs(self.source_dir)
        os.makedirs(self.target_dir)

    def tearDown(self):
        """Clean up temporary directories."""
        shutil.rmtree(self.temp_dir)

    def test_copy_file_success(self):
        """Test successful file copy."""
        source_file = os.path.join(self.source_dir, "data.db")
        with open(source_file, "w") as f:
            f.write("database content")

        target_file = os.path.join(self.target_dir, "data.db")
        success, message = copy_file(source_file, target_file)

        self.assertTrue(success)
        self.assertTrue(os.path.exists(target_file))
        self.assertFalse(os.path.islink(target_file))
        with open(target_file) as f:
            self.assertEqual(f.read(), "database content")

    def test_copy_file_source_not_exists(self):
        """Test copy fails when source doesn't exist."""
        source_file = os.path.join(self.source_dir, "nonexistent")
        target_file = os.path.join(self.target_dir, "data.db")

        success, message = copy_file(source_file, target_file)

        self.assertFalse(success)
        self.assertIn("does not exist", message)

    def test_copy_file_target_exists(self):
        """Test copy fails when target already exists."""
        source_file = os.path.join(self.source_dir, "data.db")
        target_file = os.path.join(self.target_dir, "data.db")

        with open(source_file, "w") as f:
            f.write("source content")
        with open(target_file, "w") as f:
            f.write("target content")

        success, message = copy_file(source_file, target_file)

        self.assertFalse(success)
        self.assertIn("already exists", message)

    def test_copy_file_dry_run(self):
        """Test dry run doesn't create actual copy."""
        source_file = os.path.join(self.source_dir, "data.db")
        target_file = os.path.join(self.target_dir, "data.db")

        with open(source_file, "w") as f:
            f.write("database content")

        success, message = copy_file(source_file, target_file, dry_run=True)

        self.assertTrue(success)
        self.assertIn("Would copy", message)
        self.assertFalse(os.path.exists(target_file))

    def test_copy_directory(self):
        """Test copying a directory."""
        source_subdir = os.path.join(self.source_dir, "config")
        os.makedirs(source_subdir)
        with open(os.path.join(source_subdir, "settings.json"), "w") as f:
            f.write('{"key": "value"}')

        target_subdir = os.path.join(self.target_dir, "config")
        success, message = copy_file(source_subdir, target_subdir)

        self.assertTrue(success)
        self.assertTrue(os.path.isdir(target_subdir))
        self.assertTrue(os.path.exists(os.path.join(target_subdir, "settings.json")))


class TestCreateLinks(unittest.TestCase):
    """Tests for create_links with mixed types."""

    def setUp(self):
        """Create temporary directories for testing."""
        self.temp_dir = tempfile.mkdtemp()
        self.source_dir = os.path.join(self.temp_dir, "source")
        self.target_dir = os.path.join(self.temp_dir, "target")
        os.makedirs(self.source_dir)
        os.makedirs(self.target_dir)

    def tearDown(self):
        """Clean up temporary directories."""
        shutil.rmtree(self.temp_dir)

    def test_create_links_mixed_types(self):
        """Test creating both symlinks and copies."""
        # Create source files
        env_file = os.path.join(self.source_dir, ".env")
        db_file = os.path.join(self.source_dir, "data.db")
        with open(env_file, "w") as f:
            f.write("SECRET=value")
        with open(db_file, "w") as f:
            f.write("database")

        files = [
            {"path": ".env", "type": LINK_TYPE_SYMLINK},
            {"path": "data.db", "type": LINK_TYPE_COPY},
        ]

        result = create_links(self.source_dir, self.target_dir, files)

        self.assertEqual(len(result["success"]), 2)
        self.assertEqual(len(result["failed"]), 0)

        # Check .env is a symlink
        target_env = os.path.join(self.target_dir, ".env")
        self.assertTrue(os.path.islink(target_env))

        # Check data.db is a copy (not a symlink)
        target_db = os.path.join(self.target_dir, "data.db")
        self.assertTrue(os.path.exists(target_db))
        self.assertFalse(os.path.islink(target_db))

        # Verify types in result
        for entry in result["success"]:
            if entry["target"] == ".env":
                self.assertEqual(entry["type"], LINK_TYPE_SYMLINK)
            elif entry["target"] == "data.db":
                self.assertEqual(entry["type"], LINK_TYPE_COPY)

    def test_create_links_defaults_to_symlink(self):
        """Test that type defaults to symlink when not specified."""
        env_file = os.path.join(self.source_dir, ".env")
        with open(env_file, "w") as f:
            f.write("SECRET=value")

        # Omit type field
        files = [{"path": ".env"}]

        result = create_links(self.source_dir, self.target_dir, files)

        self.assertEqual(len(result["success"]), 1)
        self.assertEqual(result["success"][0]["type"], LINK_TYPE_SYMLINK)
        self.assertTrue(os.path.islink(os.path.join(self.target_dir, ".env")))


class TestManifest(unittest.TestCase):
    """Tests for manifest reading and writing."""

    def setUp(self):
        """Create temporary directory for testing."""
        self.temp_dir = tempfile.mkdtemp()
        # Create a fake git dir structure to simulate worktree
        self.git_dir = os.path.join(self.temp_dir, ".git")
        os.makedirs(self.git_dir)

    def tearDown(self):
        """Clean up temporary directory."""
        shutil.rmtree(self.temp_dir)

    @patch("config_manager.get_worktree_git_dir")
    def test_write_manifest(self, mock_git_dir):
        """Test manifest writing."""
        mock_git_dir.return_value = self.git_dir

        links = [
            {"target": ".env", "source": "../main/.env", "type": LINK_TYPE_SYMLINK},
            {"target": "config/db.yml", "source": "../../main/config/db.yml", "type": LINK_TYPE_COPY},
        ]

        success = write_manifest(self.temp_dir, "/Users/dev/main", links)

        self.assertTrue(success)
        manifest_path = os.path.join(self.git_dir, MANIFEST_FILE)
        self.assertTrue(os.path.exists(manifest_path))

        with open(manifest_path) as f:
            data = json.load(f)

        self.assertEqual(data["version"], MANIFEST_VERSION)
        self.assertEqual(len(data["links"]), 2)
        self.assertEqual(data["links"][0]["type"], LINK_TYPE_SYMLINK)
        self.assertEqual(data["links"][1]["type"], LINK_TYPE_COPY)
        self.assertIn("created_at", data)

    @patch("config_manager.get_worktree_git_dir")
    def test_read_manifest(self, mock_git_dir):
        """Test manifest reading."""
        mock_git_dir.return_value = self.git_dir

        manifest_data = {
            "version": MANIFEST_VERSION,
            "source_worktree": "/Users/dev/main",
            "created_at": "2025-01-15T10:00:00Z",
            "links": [
                {"target": ".env", "source": "../main/.env", "type": LINK_TYPE_SYMLINK},
                {"target": "data.db", "source": "../main/data.db", "type": LINK_TYPE_COPY},
            ],
        }

        manifest_path = os.path.join(self.git_dir, MANIFEST_FILE)
        with open(manifest_path, "w") as f:
            json.dump(manifest_data, f)

        result = read_manifest(self.temp_dir)

        self.assertIsNotNone(result)
        self.assertEqual(result["version"], MANIFEST_VERSION)
        self.assertEqual(len(result["links"]), 2)

    @patch("config_manager.get_worktree_git_dir")
    def test_read_manifest_not_exists(self, mock_git_dir):
        """Test reading nonexistent manifest."""
        mock_git_dir.return_value = self.git_dir
        result = read_manifest(self.temp_dir)
        self.assertIsNone(result)

    @patch("config_manager.get_worktree_git_dir")
    def test_read_manifest_invalid_json(self, mock_git_dir):
        """Test reading invalid JSON manifest."""
        mock_git_dir.return_value = self.git_dir

        manifest_path = os.path.join(self.git_dir, MANIFEST_FILE)
        with open(manifest_path, "w") as f:
            f.write("not valid json")

        result = read_manifest(self.temp_dir)
        self.assertIsNone(result)

    @patch("config_manager.get_worktree_git_dir")
    def test_read_manifest_no_git_dir(self, mock_git_dir):
        """Test reading manifest when not in a git repo."""
        mock_git_dir.return_value = None
        result = read_manifest(self.temp_dir)
        self.assertIsNone(result)


class TestSymlinkRemoval(unittest.TestCase):
    """Tests for symlink removal."""

    def setUp(self):
        """Create temporary directories for testing."""
        self.temp_dir = tempfile.mkdtemp()
        self.source_dir = os.path.join(self.temp_dir, "source")
        self.target_dir = os.path.join(self.temp_dir, "target")
        os.makedirs(self.source_dir)
        os.makedirs(self.target_dir)
        # Create a fake git dir structure
        self.git_dir = os.path.join(self.target_dir, ".git")
        os.makedirs(self.git_dir)

    def tearDown(self):
        """Clean up temporary directories."""
        shutil.rmtree(self.temp_dir)

    @patch("config_manager.get_worktree_git_dir")
    def test_remove_symlinks(self, mock_git_dir):
        """Test symlink removal using manifest."""
        mock_git_dir.return_value = self.git_dir

        # Create source file
        source_file = os.path.join(self.source_dir, ".env")
        with open(source_file, "w") as f:
            f.write("SECRET=value")

        # Create symlink
        target_file = os.path.join(self.target_dir, ".env")
        rel_path = calculate_relative_path(source_file, target_file)
        os.symlink(rel_path, target_file)

        # Write manifest
        write_manifest(
            self.target_dir,
            self.source_dir,
            [{"target": ".env", "source": rel_path}],
        )

        # Verify symlink exists
        self.assertTrue(os.path.islink(target_file))

        # Remove symlinks
        removed, failed, errors = remove_symlinks(self.target_dir)

        self.assertEqual(removed, 1)
        self.assertEqual(failed, 0)
        self.assertFalse(os.path.exists(target_file))
        self.assertFalse(os.path.exists(os.path.join(self.git_dir, MANIFEST_FILE)))

    @patch("config_manager.get_worktree_git_dir")
    def test_remove_symlinks_no_manifest(self, mock_git_dir):
        """Test removal when no manifest exists."""
        mock_git_dir.return_value = self.git_dir

        removed, failed, errors = remove_symlinks(self.target_dir)

        self.assertEqual(removed, 0)
        self.assertEqual(failed, 0)
        self.assertIn("No manifest file found", errors)


class TestSymlinkStatus(unittest.TestCase):
    """Tests for symlink status checking."""

    def setUp(self):
        """Create temporary directories for testing."""
        self.temp_dir = tempfile.mkdtemp()
        self.source_dir = os.path.join(self.temp_dir, "source")
        self.target_dir = os.path.join(self.temp_dir, "target")
        os.makedirs(self.source_dir)
        os.makedirs(self.target_dir)
        # Create a fake git dir structure
        self.git_dir = os.path.join(self.target_dir, ".git")
        os.makedirs(self.git_dir)

    def tearDown(self):
        """Clean up temporary directories."""
        shutil.rmtree(self.temp_dir)

    @patch("config_manager.get_worktree_git_dir")
    def test_status_no_manifest(self, mock_git_dir):
        """Test status with no manifest."""
        mock_git_dir.return_value = self.git_dir

        status = get_symlink_status(self.target_dir)

        self.assertEqual(status["count"], 0)
        self.assertEqual(status["valid"], 0)
        self.assertEqual(status["broken"], 0)

    @patch("config_manager.get_worktree_git_dir")
    def test_status_with_valid_symlinks(self, mock_git_dir):
        """Test status with valid symlinks."""
        mock_git_dir.return_value = self.git_dir

        # Create source and symlink
        source_file = os.path.join(self.source_dir, ".env")
        with open(source_file, "w") as f:
            f.write("SECRET=value")

        target_file = os.path.join(self.target_dir, ".env")
        rel_path = calculate_relative_path(source_file, target_file)
        os.symlink(rel_path, target_file)

        # Write manifest
        write_manifest(
            self.target_dir,
            self.source_dir,
            [{"target": ".env", "source": rel_path}],
        )

        status = get_symlink_status(self.target_dir)

        self.assertEqual(status["count"], 1)
        self.assertEqual(status["valid"], 1)
        self.assertEqual(status["broken"], 0)

    @patch("config_manager.get_worktree_git_dir")
    def test_status_with_broken_symlinks(self, mock_git_dir):
        """Test status with broken symlinks."""
        mock_git_dir.return_value = self.git_dir

        # Create symlink to nonexistent source
        target_file = os.path.join(self.target_dir, ".env")
        os.symlink("../nonexistent/.env", target_file)

        # Write manifest
        write_manifest(
            self.target_dir,
            self.source_dir,
            [{"target": ".env", "source": "../nonexistent/.env"}],
        )

        status = get_symlink_status(self.target_dir)

        self.assertEqual(status["count"], 1)
        self.assertEqual(status["valid"], 0)
        self.assertEqual(status["broken"], 1)


class TestFileCategorization(unittest.TestCase):
    """Tests for file categorization."""

    def setUp(self):
        """Create temporary directory for testing."""
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Clean up temporary directory."""
        shutil.rmtree(self.temp_dir)

    def test_categorize_mixed_files(self):
        """Test categorization of mixed file types."""
        files = [
            ".env",
            ".env.local",
            "node_modules/package.json",
            "__pycache__/module.pyc",
            ".vscode/settings.json",
            "config/database.yml",
            "dist/bundle.js",
            "unknown_file.xyz",
        ]

        result = categorize_files(files, self.temp_dir)

        # Check symlink category
        symlink_paths = [f[0] for f in result["symlink"]]
        self.assertIn(".env", symlink_paths)
        self.assertIn(".env.local", symlink_paths)
        self.assertIn(".vscode/settings.json", symlink_paths)
        self.assertIn("config/database.yml", symlink_paths)

        # Check skip category
        skip_paths = [f[0] for f in result["skip"]]
        self.assertIn("node_modules/package.json", skip_paths)
        self.assertIn("__pycache__/module.pyc", skip_paths)
        self.assertIn("dist/bundle.js", skip_paths)

        # Check ask category
        ask_paths = [f[0] for f in result["ask"]]
        self.assertIn("unknown_file.xyz", ask_paths)

    def test_categorize_large_file(self):
        """Test categorization of large files."""
        # Create a large file
        large_file = os.path.join(self.temp_dir, "large_data.bin")
        with open(large_file, "wb") as f:
            f.write(b"x" * (ASK_THRESHOLD_BYTES + 1000))

        result = categorize_files(["large_data.bin"], self.temp_dir)

        ask_paths = [f[0] for f in result["ask"]]
        self.assertIn("large_data.bin", ask_paths)

    def test_categorize_database_files(self):
        """Test categorization of database files."""
        files = ["data.sqlite", "app.db", "cache.sqlite3"]
        result = categorize_files(files, self.temp_dir)

        ask_paths = [f[0] for f in result["ask"]]
        for f in files:
            self.assertIn(f, ask_paths)


if __name__ == "__main__":
    unittest.main()
