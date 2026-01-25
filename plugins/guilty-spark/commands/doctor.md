---
name: doctor
description: Verify Guilty Spark plugin setup and documentation health
allowed-tools:
  - Bash
  - Glob
  - Read
  - Grep
---

# Guilty Spark Diagnostics

Run diagnostic checks for the Guilty Spark plugin.

## Checks to Perform

### 1. Plugin Installation
Verify this command is running (if you're seeing this, it works).

### 2. Git Repository
Check if the current directory is a git repository:
```bash
git rev-parse --is-inside-work-tree
```

### 3. Documentation Directory
Check if `docs/` exists and has the expected structure:
- `docs/INDEX.md` (required)
- `docs/architecture/OVERVIEW.md` (expected)
- `docs/features/INDEX.md` (expected)

### 4. Documentation Health
For each expected file, check:
- Does it exist?
- When was it last modified?
- Is it empty or initialized?

### 5. Code Reference Validation
Scan documentation for code references (`file:line`) and verify:
- Referenced files exist
- Line numbers are valid (file has that many lines)

Report any stale references.

## Output Format

Present results as:

```
Guilty Spark Diagnostics
========================

Plugin Status: OK
Git Repository: OK (branch: main)

Documentation Structure:
  docs/INDEX.md         OK (updated 2 days ago)
  docs/architecture/    OK (3 files)
  docs/features/        OK (5 features documented)

Documentation Health:
  Total files: 12
  Last update: 2024-01-15
  Stale (>7 days): 0

Code References:
  Total: 24
  Valid: 24
  Broken: 0

Status: Healthy
```

Or if issues found:

```
Issues Found:
  - docs/INDEX.md missing
  - 3 broken code references in docs/features/auth/README.md

Recommendations:
  - Run Sentinel-Index to restore INDEX.md
  - Update auth documentation with current code references
```

## Implementation

1. Use Bash to check git status
2. Use Glob to find documentation files
3. Use Read to check file contents
4. Use Grep to find code references (pattern: backtick + path + colon + number)
5. Validate each reference with file existence and line count checks
