---
name: changelog
description: Generate or update CHANGELOG.md from conventional commits
disable-model-invocation: true
argument-hint: "<range>"
allowed-tools: Read, Bash, Write, Edit
---

# Changelog

Generate or update the project changelog from conventional commits. Follows the [Keep a Changelog](https://keepachangelog.com/) format.

## `/inkwell:changelog $ARGUMENTS`

### Phase 1: Read Configuration

If `.inkwell.json` exists in the project root, read the changelog output path from `docs.changelog.file`. Default: `CHANGELOG.md`.

### Phase 2: Determine Range

If `$ARGUMENTS` is provided, use it as the git range or tag (e.g., `v1.0.0..HEAD`, `--since="2 weeks ago"`).

If empty, detect the range automatically:
1. Check if the changelog file exists and find the most recent version header (e.g., `## [1.2.0]`)
2. Search for a git tag matching that version: `git tag -l "v<version>"` or `git tag -l "<version>"`
3. If a matching tag is found, use `<tag>..HEAD` as the range
4. If no tag or no changelog exists, use the last 50 commits: `git log -50 --oneline`

### Phase 3: Parse Commits

Run `git log --format="%H %s" <range>` to get commit hashes and subjects.

Parse each subject line for conventional commit format: `<type>[scope]: <description>`.

Group commits by type into Keep a Changelog categories:

| Commit Type | Changelog Category |
|---|---|
| `feat` | Added |
| `fix` | Fixed |
| `refactor`, `perf` | Changed |
| `docs` | Documentation |
| `deprecate` | Deprecated |
| `revert` | Removed |
| `security` | Security |

Skip commits that don't follow conventional format (merge commits, `chore:`, `ci:`, `test:`, `style:`).

If no qualifying commits are found, report: "No conventional commits found in range — nothing to add to changelog."

### Phase 4: Generate Entry

Format the new changelog section:

```markdown
## [Unreleased] - YYYY-MM-DD

### Added

- Description from feat commit
- Description from another feat commit

### Fixed

- Description from fix commit

### Changed

- Description from refactor commit
```

Use today's date. Use `[Unreleased]` as the version — the user can replace it with a version number when they release.

Only include categories that have entries. Order categories: Added, Changed, Deprecated, Removed, Fixed, Security, Documentation.

### Phase 5: Write Changelog

If the changelog file exists:
1. Read its contents
2. Find the insertion point — after the file header and before the first version entry
3. Insert the new section

If it doesn't exist, create it:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased] - YYYY-MM-DD

### Added

- ...
```

### Phase 6: Report

Output a summary of what was added:

```
Updated <changelog-path>:
  Added: N entries
  Fixed: N entries
  Changed: N entries
  Range: <start>..<end>
```

### Error Handling

- If the git range is invalid (e.g., unknown revision or bad ref), report the error and suggest a valid range: "Invalid range `<input>`. Try a tag (`v1.0.0..HEAD`), commit hash, or `--since=\"2 weeks ago\"`."
- If the changelog file exists but is not writable, report the permission error
- If no git repository is found, report: "Not a git repository — changelog requires git history."
