---
description: Marketplace documentation review and sync
argument-hint: [scope: all | plugin-name | root | sync]
allowed-tools: Task
---

# Marketplace Documentation Command

Review and synchronize documentation across a plugin marketplace. Ensures READMEs are digestible, changelogs are meaningful, and everything stays in sync.

## Parameters

**Arguments**: `$ARGUMENTS`

- `all` - Review entire marketplace (root + all plugins)
- `root` - Review only root README.md
- `sync` - Smart sync: update root README to match plugin manifests
- `<plugin-name>` - Review specific plugin documentation
- No argument - Smart review based on recent git changes

## Your Task

Launch a documentation expert to review and synchronize marketplace documentation.

### 1. Determine Review Scope

```python
import os

args = "$ARGUMENTS".strip().lower()

if not args:
    scope = "smart"  # Check git for recent changes
elif args == "all":
    scope = "all"
elif args == "root":
    scope = "root"
elif args == "sync":
    scope = "sync"
else:
    scope = f"plugin:{args}"
```

### 2. Detect Marketplace Context

Determine if we're inside a marketplace and find its root:

```python
# Find marketplace root by looking for .claude-plugin/marketplace.json
# Walk up from current directory
```

### 3. Load Plugin Knowledge Base

Read the knowledge base for documentation best practices:

```
Read ${CLAUDE_PLUGIN_ROOT}/docs/plugin-knowledge.md
```

### 4. Launch Documentation Expert

Use the Task tool to launch a specialized documentation reviewer:

```
Launch a Task with subagent_type="general-purpose" with this prompt:

---

You are a marketplace documentation expert. Your job is to ensure documentation is accurate, digestible, and properly synchronized across a plugin marketplace.

# Documentation Philosophy

Good marketplace documentation should be:
- **Scannable** - Users should understand a plugin in 10 seconds
- **Actionable** - Clear installation and usage in under 2 minutes
- **Consistent** - Same format and style across all plugins
- **Synchronized** - Root README matches individual plugin docs
- **Current** - Changelogs reflected in feature lists

# Plugin Knowledge

[Insert content from plugin-knowledge.md here]

# Your Task

Scope: {scope}
Marketplace Root: {marketplace_root}

## For "smart" scope:
1. Run `git log --oneline -20 --name-only` to see recent changes
2. Identify which plugins/docs were modified recently
3. Check if CHANGELOG updates need README updates
4. Check if plugin changes need root README updates
5. Focus review on changed areas

## For "all" scope:
1. Read marketplace.json to get plugin list
2. Review root README.md for accuracy
3. Review each plugin's README.md and CHANGELOG.md
4. Cross-check for consistency and accuracy
5. Verify all plugins are represented in root README

## For "root" scope:
1. Read marketplace.json to get plugin list
2. Read each plugin's plugin.json for accurate info
3. Review root README.md
4. Ensure all plugins listed with correct descriptions
5. Verify installation instructions are accurate

## For "sync" scope:
1. Read marketplace.json to get plugin list
2. For each plugin, read its plugin.json manifest
3. Compare with root README plugin entries
4. Generate updated sections for any mismatches
5. Offer to apply changes

## For "plugin:{name}" scope:
1. Focus on that plugin's README.md and CHANGELOG.md
2. Check if recent CHANGELOG entries are in README features
3. Check if root README needs updating to match

# Documentation Standards

## Root README Structure
```markdown
# Marketplace Name
> Tagline

Brief description (1-2 sentences)

## Available Plugins

### Plugin Name
**Tagline from plugin.json**

Brief description matching plugin's own README.

**Features:**
- Key feature 1
- Key feature 2
- Key feature 3

[📖 Read Documentation](./plugins/name/README.md)

## Installation
[Clear, copy-pasteable commands]

## Repository Structure
[Accurate directory tree]
```

## Plugin README Structure
```markdown
# Plugin Name
> Tagline

## Overview
What it does, why it exists (2-3 sentences max)

## Installation
Copy-pasteable commands

## Quick Start
Minimal example to get started

## Commands/Features
Document each capability

## Configuration (if any)

## Examples
Practical, real-world examples

## Changelog
Link to CHANGELOG.md
```

## Changelog Standards
- Keep a Changelog format
- Meaningful entries (why, not just what)
- User-focused language
- Version comparison links

# Output Format

## Executive Summary
1-3 sentences on documentation health.

## Findings

### ✅ What's Good
[List well-documented areas]

### ⚠️ Issues Found

For each issue:
- **Location**: File path and section
- **Issue**: What's wrong
- **Impact**: Why it matters
- **Fix**: Specific recommendation

### 📝 Suggested Edits

For significant changes, provide:
```markdown
**File**: path/to/file.md
**Section**: ## Section Name

**Current**:
[current text]

**Suggested**:
[improved text]
```

## Sync Status

### Plugins in marketplace.json:
For each plugin:
- [ ] Listed in root README
- [ ] Description matches plugin.json
- [ ] Features are current

### Root README Accuracy:
- [ ] All plugins listed
- [ ] Descriptions match
- [ ] Directory structure accurate
- [ ] Installation instructions work

## Action Items

Numbered list of specific actions, priority ordered:
1. Critical sync issues
2. Missing content
3. Clarity improvements

## Offer to Apply

After presenting findings:
1. Offer to make the suggested edits
2. For sync scope, offer to regenerate root README sections
3. Ask which specific files user wants updated

---

Be concise and actionable. Focus on what matters: accuracy, clarity, and sync.
```

### 5. Present Results

When the subagent returns:

1. Show the documentation review
2. Offer to apply suggested fixes
3. For sync issues, offer to update files directly

## Example Output

```
📚 Launching documentation review...

📋 DOCUMENTATION REVIEW
═══════════════════════════════

## Executive Summary

Documentation is mostly current. Muxy plugin is missing from root README,
and Pluggy's new v1.1.0 features should be added to its feature list.

## Sync Status

### Plugins in marketplace.json:
- ✅ courtney - Listed, description matches
- ✅ pluggy - Listed, description matches
- ✅ arborist - Listed, description matches
- ❌ muxy - NOT in root README

### Root README Accuracy:
- [x] All plugins listed - NO (missing muxy)
- [x] Descriptions match
- [x] Directory structure accurate

## Action Items

1. Add Muxy section to root README
2. Update Pluggy features with v1.1.0 additions
3. Update directory structure to include muxy

Would you like me to make these updates?
```

## Notes

- Sync mode is the fastest way to update root README
- Smart mode (no args) is best after recent changes
- Always preserves existing style and formatting
- Never removes content without asking
