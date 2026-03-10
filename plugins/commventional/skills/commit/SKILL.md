---
name: commit
description: Stage and commit changes using conventional commit format
argument-hint: "[message]"
allowed-tools: Bash
---

# Conventional Commit

Create a conventional commit for the current changes. If the user provides a message via `$ARGUMENTS`, use it as guidance for the commit message. Otherwise, analyze the changes to determine the appropriate type, scope, and description.

## `/commit $ARGUMENTS`

### Step 1: Assess Changes

Run these in parallel:
- `git status` — see all modified and untracked files (never use `-uall`)
- `git diff` — see unstaged changes
- `git diff --cached` — see staged changes
- `git log --oneline -5` — see recent commit style for context

### Step 2: Determine Type and Scope

Analyze the changes to determine the conventional commit type:
- **feat** — new feature or capability
- **fix** — bug fix
- **docs** — documentation only
- **style** — formatting, whitespace, semicolons (no logic change)
- **refactor** — code restructuring without behavior change
- **perf** — performance improvement
- **test** — adding or updating tests
- **build** — build system or dependency changes
- **ci** — CI/CD configuration
- **chore** — maintenance, tooling, config changes

Determine scope from the area of code affected (e.g., `auth`, `api`, `db`). Scope is optional — omit it if the change is broad or the scope isn't meaningful.

If the change includes breaking changes, note this for the commit message.

### Step 3: Stage Files

Stage specific files by name — NEVER use `git add -A` or `git add .`. Do not stage files that likely contain secrets (`.env`, `credentials.json`, etc.) — warn the user if such files are modified.

If files are already staged from Step 1, respect the user's staging choices.

### Step 4: Commit

Draft the commit message following conventional commit format:

```
<type>[(scope)]: <description>

[optional body explaining the "why"]

[optional BREAKING CHANGE: footer]
```

Rules:
- Imperative mood, lowercase, no trailing period
- Description should be concise (under 72 characters)
- Add a body only if the "why" isn't obvious from the description
- NEVER add Co-Authored-By or AI attribution lines

Use a HEREDOC for the commit:

```bash
git commit -m "$(cat <<'EOF'
<type>[(scope)]: <description>

<optional body>
EOF
)"
```

### Step 5: Verify

Run `git status` to confirm the commit succeeded and show the result.
