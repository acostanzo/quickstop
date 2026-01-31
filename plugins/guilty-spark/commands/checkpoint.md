---
name: checkpoint
description: Capture documentation for work done in the current session
allowed-tools:
  - Task
  - Read
  - Glob
  - Grep
  - Bash
  - Skill
---

# Documentation Checkpoint

The user wants to capture documentation. This command provides branch-aware documentation behavior.

## Workflow

```
/guilty-spark:checkpoint
       │
       ▼
  Detect Branch (git rev-parse --abbrev-ref HEAD)
       │
  ┌────┴────┐
  ▼         ▼
main?    feature?
  │         │
  ▼         ▼
Deep     Branch
Review   Diff
Mode     Mode

Deep Review Mode
  ├── 3a. Inventory docs
  ├── 3b. Scan codebase
  ├── 3c. Cross-reference (stale detection)
  ├── 3d. Cleanup (sentinel-cleanup)
  ├── 3e. Link audit (sentinel-links)
  ├── 3f. Verify docs (sentinel-verify)
  └── 3g. Dispatch update sentinels
```

## Step 1: Initialize Documentation

Before any documentation work, check if `docs/README.md` exists:

```bash
test -f docs/README.md && echo "exists" || echo "missing"
```

If missing, create the documentation structure using the Write tool:
- `docs/README.md` - Main entry point
- `docs/architecture/README.md` - Architecture index
- `docs/architecture/OVERVIEW.md` - Architecture placeholder
- `docs/architecture/components/README.md` - Components index
- `docs/features/README.md` - Feature inventory

Every folder in docs/ should have a README.md for GitHub auto-rendering and navigation.

Use the templates from `${CLAUDE_PLUGIN_ROOT}/skills/monitor/references/` as guides for initial content.

## Step 2: Detect Current Branch

Run:
```bash
git rev-parse --abbrev-ref HEAD
```

- If `main` or `master` → **Deep Review Mode**
- Otherwise → **Branch Diff Mode**

---

## Branch Diff Mode (Feature Branches)

When on a feature branch, document only the changes specific to this branch.

### 2a. Find Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master
```

### 2b. Get Changed Files

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD
```

### 2c. Analyze Changes

Read the diff content to understand what changed:
```bash
git diff $(git merge-base HEAD main)..HEAD --stat
```

For significant files, read the actual changes:
```bash
git diff $(git merge-base HEAD main)..HEAD -- path/to/file
```

### 2d. Categorize Changes

Analyze the changed files:
- **New features**: New files in feature-related directories
- **Feature modifications**: Changes to existing feature code
- **Architecture changes**: Changes to core/config/structure files
- **Skip-worthy**: Tests only, deps only, formatting, docs only

### 2e. Leverage Session Context

Review the conversation history to understand:
- What features were implemented
- What decisions were made
- What the user was working on

### 2f. Dispatch Sentinel

If meaningful changes were found, invoke the Monitor skill with context:

Use the Skill tool:
- `skill`: "guilty-spark:monitor"
- `args`: Summary of changes and session context

Or dispatch sentinel-diff directly via Task tool:
- `subagent_type`: "guilty-spark:sentinel-diff"
- `prompt`: Include changed files list, diff summary, and session context
- `run_in_background`: true

---

## Deep Review Mode (Main Branch)

When on main/master, perform a comprehensive documentation review.

### 3a. Inventory Current Documentation

```bash
find docs -name "*.md" -type f 2>/dev/null | head -50
```

Read `docs/README.md` and `docs/features/README.md` to understand current state.

### 3b. Scan Codebase

Explore the codebase to identify:
- Major features and components
- Entry points and key files
- Architecture patterns

### 3c. Cross-Reference

Compare documentation against code:
- **Code is the source of truth**
- Identify undocumented features
- Identify stale or inaccurate documentation
- Check code reference validity

### 3d. Dispatch Cleanup Sentinel

If any stale documentation was found during cross-reference:

1. Dispatch `guilty-spark:sentinel-cleanup` with findings
2. Run in **foreground** so user sees what will be removed
3. Show summary of deletions/updates before committing

Example Task tool parameters:
- `description`: "Cleanup stale docs"
- `subagent_type`: "guilty-spark:sentinel-cleanup"
- `prompt`: Include list of stale docs and invalid references found
- `run_in_background`: false (run in foreground for visibility)

### 3e. Audit Documentation Links

After cleanup, audit internal documentation links:

1. Dispatch `guilty-spark:sentinel-links`
2. Run in **foreground** for visibility
3. Apply auto-fixes for renamed/moved files
4. Flag unfixable links for manual review

Example Task tool parameters:
- `description`: "Audit doc links"
- `subagent_type`: "guilty-spark:sentinel-links"
- `prompt`: Audit all markdown links in docs/ for validity
- `run_in_background`: false (run in foreground for visibility)

### 3f. Verify Documentation Accuracy

For each documented feature, verify accuracy against code:

1. List all features in `docs/features/`
2. Dispatch `guilty-spark:sentinel-verify` for each
3. Run in **foreground** to show accuracy assessments
4. Flag major discrepancies for manual review

Example Task tool parameters:
- `description`: "Verify auth docs"
- `subagent_type`: "guilty-spark:sentinel-verify"
- `prompt`: Verify docs/features/authentication/README.md against actual code
- `run_in_background`: false (run in foreground for visibility)

For large projects with many features, you may verify in batches or prioritize recently modified features.

### 3g. Dispatch Documentation Sentinels

Based on findings:

**For undocumented features:**
- Dispatch `guilty-spark:sentinel-feature` for each

**For architecture gaps:**
- Dispatch `guilty-spark:sentinel-architecture`

**For index updates:**
- Dispatch `guilty-spark:sentinel-index`

Run sentinels in background so user can continue working.

---

## Output

After analysis and dispatch:

**If on feature branch:**
```
Checkpoint: Branch diff mode (feature/xyz)

Changes analyzed:
- 5 files modified
- New: authentication handler
- Modified: user service

Dispatched sentinel-diff to document changes.
```

**If on main branch:**
```
Checkpoint: Deep review mode (main)

Documentation cleanup:
- DELETED: docs/features/old-auth/ (feature removed from codebase)
- UPDATED: docs/features/payment/README.md (fixed 3 invalid refs)
- FLAGGED: docs/architecture/components/api.md (needs manual review)

Link audit:
- Fixed 2 broken links
- 1 unfixable link flagged for review

Verification:
- docs/features/auth/ - Accurate
- docs/features/payment/ - Minor discrepancies (line numbers updated)

Documentation gaps:
- 1 undocumented feature found

Dispatched sentinels to address gaps.
```

**If no documentation needed:**
```
Checkpoint: No documentation needed

Changes reviewed:
- Tests only
- No feature or architecture changes detected
```

Keep responses concise - the user invoked this for quick documentation capture.
