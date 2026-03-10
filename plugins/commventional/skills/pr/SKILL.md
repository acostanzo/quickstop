---
name: pr
description: Create a pull request with conventional commit title and structured description
argument-hint: "[base-branch]"
allowed-tools: Bash
---

# Conventional PR

Create a pull request following conventional commit conventions for the title and a structured description.

## `/pr $ARGUMENTS`

### Step 1: Determine Base Branch

If the user provided a base branch via `$ARGUMENTS`, use it. Otherwise, detect the default branch:

```bash
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

Fall back to `main` if detection fails.

### Step 2: Analyze Branch Changes

Run these in parallel:
- `git log <base>..HEAD --oneline` — all commits on this branch
- `git diff <base>...HEAD --stat` — files changed summary
- `git diff <base>...HEAD` — full diff for analysis

### Step 3: Generate PR Title

Determine the dominant commit type across all branch commits:
- If all commits share a type, use that type
- If mixed, use the most impactful type (feat > fix > refactor > others)

Format: `<type>[(scope)]: <description>`

Rules:
- Under 70 characters
- Imperative mood, lowercase, no trailing period
- Scope from the primary area of change

### Step 4: Generate PR Description

Structure the body:

```markdown
## Summary
<1-3 sentences describing the overall change>

## Changes
- <bullet list of notable changes, grouped logically>

## Test plan
- [ ] <verification steps>
```

NEVER add AI attribution footers.

### Step 5: Push and Create PR

Check if the branch tracks a remote:

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
```

If not tracking or behind, push with `-u`:

```bash
git push -u origin HEAD
```

Create the PR using a HEREDOC for the body:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
...

## Changes
...

## Test plan
...
EOF
)"
```

### Step 6: Return Result

Output the PR URL so the user can access it directly.
