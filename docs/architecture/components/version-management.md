# Version Management System

> Component: Plugin version validation and enforcement

## Purpose

The version management system ensures that plugin changes are always accompanied by version bumps. This is critical because Claude Code caches plugins by version number - changes without version bumps will not be received by users.

## Architecture

```
scripts/
├── check-plugin-versions.sh      # Version validation script
├── install-hooks.sh              # Git hooks installer
└── git-hooks/
    └── pre-push                  # Pre-push hook template
```

## Components

### Version Check Script

**File:** `/Users/acostanzo/Code/quickstop/scripts/check-plugin-versions.sh`

**Purpose:** Compare current branch against base (origin/main) and verify version bumps.

**Algorithm:**
```
1. Get changed files: git diff --name-only $BASE_REF
2. Identify plugins with changes (files in plugins/[name]/)
3. Exclude README-only changes (no version bump required)
4. For each changed plugin:
   a. Extract OLD_VERSION from $BASE_REF:plugins/[name]/.claude-plugin/plugin.json
   b. Extract NEW_VERSION from current plugins/[name]/.claude-plugin/plugin.json
   c. If OLD_VERSION == NEW_VERSION → FAIL
5. Warn if marketplace.json not in changed files
6. Warn if README.md not in changed files
7. Exit 1 if any errors, else exit 0
```

**Usage:**
```bash
./scripts/check-plugin-versions.sh              # Compare against origin/main
./scripts/check-plugin-versions.sh HEAD~1       # Compare against previous commit
./scripts/check-plugin-versions.sh main         # Compare against local main
```

**Output Examples:**

Success:
```
Plugins with code changes: arborist muxy

✓ arborist: Version bumped v3.0.0 → v3.1.0
✓ muxy: Version bumped v2.5.0 → v3.0.0

All version checks passed!
```

Failure:
```
Plugins with code changes: arborist

✗ arborist: Version NOT bumped (still v3.1.0)
  Changed files:
    plugins/arborist/hooks/session-start.sh

WARNING: Plugin files changed but marketplace.json was not updated.
         Remember to update the version in marketplace.json too!

Found 2 issue(s). Please bump version numbers before pushing.
```

### Git Hooks Installer

**File:** `/Users/acostanzo/Code/quickstop/scripts/install-hooks.sh`

**Purpose:** Install git hooks from templates to `.git/hooks/`.

**Implementation:**
```bash
for hook in "$HOOKS_SOURCE"/*; do
    hook_name=$(basename "$hook")
    cp "$hook" "$HOOKS_DEST/$hook_name"
    chmod +x "$HOOKS_DEST/$hook_name"
done
```

### Pre-Push Hook

**File:** `/Users/acostanzo/Code/quickstop/scripts/git-hooks/pre-push`

**Purpose:** Run version check before allowing push.

**Implementation:**
```bash
if [[ -x "$REPO_ROOT/scripts/check-plugin-versions.sh" ]]; then
    echo "Checking plugin versions..."
    "$REPO_ROOT/scripts/check-plugin-versions.sh" || exit 1
fi
```

## Version Locations

Three locations must stay synchronized:

| Location | Purpose | Example |
|----------|---------|---------|
| `plugins/[name]/.claude-plugin/plugin.json` | Authoritative plugin version | `"version": "3.1.0"` |
| `.claude-plugin/marketplace.json` | Marketplace registry | `"version": "3.1.0"` |
| `README.md` | Documentation | `\| Arborist \| 3.1.0 \| ...` |

## Data Flow

```
Developer makes changes to plugin
                │
                ▼
Developer runs: git push
                │
                ▼
        pre-push hook fires
                │
                ▼
     check-plugin-versions.sh
                │
                ├── No plugin changes? → Allow push
                │
                ├── Only README changes? → Allow push
                │
                ├── Code changes with version bump? → Allow push
                │
                └── Code changes WITHOUT version bump? → BLOCK push
                                                          │
                                                          ▼
                                                   Exit 1 with message:
                                                   "Version NOT bumped"
```

## Semantic Versioning

The project follows semantic versioning:

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Breaking changes, rewrites | MAJOR | 2.0.0 → 3.0.0 |
| New features | MINOR | 3.0.0 → 3.1.0 |
| Bug fixes | PATCH | 3.1.0 → 3.1.1 |

## Exclusions

### README-Only Changes

Changes to `plugins/[name]/README.md` do not require version bumps. The script explicitly excludes these:

```bash
if [[ "$file" != "plugins/$plugin/README.md" ]]; then
    CHANGED_PLUGINS+=("$plugin")
fi
```

### Non-Plugin Changes

Changes outside `plugins/` directory are not checked:
- `scripts/` - Marketplace tooling
- `CLAUDE.md` - Development guidelines
- Root `README.md` - Documentation

## Installation

```bash
# From repository root
./scripts/install-hooks.sh
```

Output:
```
Installing git hooks...
  Installed: pre-push
Done!
```

## Manual Bypass

In rare cases where bypass is needed (not recommended):

```bash
git push --no-verify
```

**Warning:** This bypasses version checking and may cause cache issues for users.

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| Push blocked unexpectedly | Code changed without version bump | Bump version in plugin.json |
| Marketplace warning | marketplace.json not updated | Update version in marketplace.json |
| README warning | README table not updated | Update version in README plugin table |
| Hook not running | Hooks not installed | Run `./scripts/install-hooks.sh` |
| Script not found | Wrong directory | Run from repository root |

---

**Last Updated:** 2025-01-25
