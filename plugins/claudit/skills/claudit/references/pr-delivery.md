# Phase 5: PR Delivery

After Phase 4 fixes are applied, check if any project-scoped files were modified. If no project files were changed (only personal/global edits), skip this phase.

## Offer PR Option

Use `AskUserQuestion` (single-select) to ask the user:

- **"Open a PR"** — Create branch, commit changes, push, open PR with educational inline comments
- **"Keep as local edits"** — Leave changes uncommitted in the working tree

## Check Prerequisites

Before attempting PR delivery:
1. Verify `gh` CLI is available: `command -v gh`
2. Verify `gh` is authenticated: `gh auth status`
3. If either fails, tell the user `gh` CLI is required for PR delivery and fall back to "Keep as local edits"

## Create the PR

If PR delivery is selected and prerequisites pass:

1. **Record the current branch**: `CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)` — this is the branch the user was on before claudit creates its own branch. The PR will target this branch so the diff only shows claudit changes.
2. **Create branch**: `git checkout -b claudit/improvements-YYYY-MM-DD-HHMM` (use today's date and current time to avoid same-day collisions)
3. **Stage changed project files**: Only stage project-scoped files that were modified in Phase 4. Never stage:
   - `CLAUDE.local.md` (gitignored/personal)
   - `.claude/settings.local.json` (personal local settings)
   - Any file under `~/.claude/` (personal config)
   - Any file outside the project root
4. **Commit** with a clear message including the score delta:
   ```
   claudit: improve Claude Code configuration (score XX → YY)

   - [List key changes]
   ```
5. **Push** with `git push -u origin claudit/improvements-YYYY-MM-DD-HHMM` (same branch name as step 2)
6. **Create PR** via `gh pr create --base $CURRENT_BRANCH`:
   - Title: `claudit: improve Claude Code configuration`
   - Body: Concise summary with score delta, list of changes, and note that personal/global config was audited separately (if comprehensive)
   - The `--base` flag ensures the PR targets the user's original branch, not the repo default — so the diff only contains claudit's changes
7. **Add inline review comments** via `gh api` for each changed file. Use this JSON structure:

   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
     --method POST \
     --field commit_id="$(git rev-parse HEAD)" \
     --field path="path/to/file" \
     --field line=N \
     --field side="RIGHT" \
     --field body="**What changed:** Brief description

   **Why it matters:** 1-2 sentences on impact

   **Claude Code feature:** Feature name
   **Docs:** https://docs.anthropic.com/en/docs/claude-code/relevant-page
   **Score impact:** +N pts Category"
   ```

   To determine the correct `line` value, run `git diff HEAD~1 -- path/to/file` and find line numbers within changed hunks. The `line` must be a line number in the new file version that falls within a diff hunk range. Target the most representative changed line per hunk. If line targeting fails (422 error), fall back to a general PR comment without line numbers using `gh pr comment`.

   Add one comment per significant change. Keep comments concise and educational.

8. Return the PR URL to the user.

## Fallback

If `gh` is not available, not authenticated, or PR creation fails:
- Tell the user what happened
- Fall back to "Keep as local edits"
- Show a `git diff --stat` of what was changed
