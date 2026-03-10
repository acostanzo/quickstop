---
name: review
description: Review a PR using conventional comments format
argument-hint: "<pr-number-or-url>"
allowed-tools: Bash
---

# Conventional Review

Review a pull request using the Conventional Comments format. Present findings in-session first, then post to the PR if the user approves.

## `/review $ARGUMENTS`

### Step 1: Fetch PR Details

Extract the PR number from `$ARGUMENTS` (handle both plain numbers and full URLs).

Run these in parallel:
- `gh pr view <number> --json title,body,baseRefName,headRefName,files` — PR metadata
- `gh pr diff <number>` — full diff

### Step 2: Analyze the Diff

Review the diff for:
- **Issues** — bugs, security vulnerabilities, logic errors, race conditions
- **Suggestions** — better patterns, clearer naming, simpler approaches
- **Questions** — unclear intent, missing context, ambiguous behavior
- **Praise** — clean patterns, good test coverage, thoughtful design
- **Nitpicks** — style, naming preferences, minor improvements
- **Todos** — small necessary changes (missing error handling, typos)

Focus on substance over style. Prioritize issues and suggestions over nitpicks.

### Step 3: Format as Conventional Comments

Format each piece of feedback as:

```
**<label> [decorations]:** <subject>

<discussion — explain the reasoning, provide examples if helpful>
```

Apply decorations:
- **(blocking)** for issues that must be resolved before merging
- **(non-blocking)** for suggestions, nitpicks, and thoughts
- **(if-minor)** for changes that are only worth making if they're small

### Step 4: Present In-Session

Show the full review to the user, organized by severity:
1. Blocking items first
2. Non-blocking suggestions and issues
3. Nitpicks and thoughts
4. Praise

Include file paths and line references where applicable.

Ask the user: "Post this review to the PR?" — wait for confirmation before proceeding.

### Step 5: Post to PR (If Approved)

Post the review as a single review with individual comments where possible:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST \
  -f body="<overall summary>" \
  -f event="COMMENT"
```

For file-specific comments, use:

```bash
gh pr review <number> --comment --body "<formatted review>"
```

### Step 6: Summarize

Report what was posted and provide the PR URL for the user to verify.
