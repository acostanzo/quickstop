---
name: install-trailer-stripper
description: Install consumer-side wirings (Claude Code hooks or .git/hooks/commit-msg) that invoke commventional's trailer-stripping capability. Per ADR-006 §1, the consumer types this slash command — that is the directing act that authorises the write.
disable-model-invocation: true
allowed-tools: Read, Write, Bash, AskUserQuestion
argument-hint: --target <choice> [--force]
---

# /commventional:install-trailer-stripper

Install helper that writes a consumer-side wiring of commventional's trailer-stripping capability into the consumer's chosen surface — Claude Code settings, the consumer's git-hooks tree, or both. The consumer typing this slash command is the directing act that authorises the write per ADR-006 §1; the plugin install itself does not perform any wiring.

## Phase 0: Parse arguments

Parse `$ARGUMENTS` for:

- **`--target <choice>`** — required. One of:
  - `claude-settings-user` — write a `PreToolUse` hook to `~/.claude/settings.json`. Restores v1.x's `enforce-ownership.sh` scope (every Claude Bash call, globally).
  - `claude-settings-project` — write the same `PreToolUse` hook to `<repo>/.claude/settings.json` (per-repo scope).
  - `git-commit-msg-hook` — write a `commit-msg` script to `<repo>/.git/hooks/commit-msg`. Catches manual commits too — broader than v1.x's behaviour.
  - `pr-cleanup-hook-user` — write a `PostToolUse` hook to `~/.claude/settings.json` that calls `:strip-pr-body` on `gh pr (create|edit)` Bash calls. Restores v1.x's `pr-ownership-check.sh` scope (globally).
  - `pr-cleanup-hook-project` — same, in project-scoped settings.
  - `all` — write both Pre and Post entries into the consumer's chosen settings scope. Ask which scope.

- **`--force`** — optional. Without it, the helper refuses to overwrite any existing target file. With it, the helper still asks for an explicit confirmation per file before overwriting.

If `--target` is missing or unrecognised, use AskUserQuestion to ask the user to pick one of the choices above. List all six explicitly. **Do not silently default.**

## Phase 1: Resolve paths

Resolve the absolute target path(s) by `--target`. Use `bash` to expand `~` and locate the repo root via `git rev-parse --show-toplevel`.

| Target | Files written |
|---|---|
| `claude-settings-user` | `~/.claude/scripts/commventional-enforce-ownership.sh` + merge into `~/.claude/settings.json` |
| `claude-settings-project` | `<repo>/.claude/scripts/commventional-enforce-ownership.sh` + merge into `<repo>/.claude/settings.json` |
| `git-commit-msg-hook` | `<repo>/.git/hooks/commit-msg` |
| `pr-cleanup-hook-user` | `~/.claude/scripts/commventional-pr-cleanup.sh` + merge into `~/.claude/settings.json` |
| `pr-cleanup-hook-project` | `<repo>/.claude/scripts/commventional-pr-cleanup.sh` + merge into `<repo>/.claude/settings.json` |
| `all` | Both scripts above + both entries merged into the chosen settings.json (ask scope) |

For project-scoped targets, abort with a diagnostic if `git rev-parse --show-toplevel` fails — there is no repo to write into.

## Phase 2: Existence check

For each target file:

1. Read the path. If it does not exist, proceed to Phase 3 (write).
2. If it exists and `--force` is **not** set, abort with a diagnostic: `<path> exists. Re-run with --force to overwrite (you will still be asked to confirm before each write).` Do not write.
3. If it exists and `--force` is set, use AskUserQuestion to confirm overwrite for that specific path. Refuse on a "no" answer.

For settings.json paths, "exists" means the file exists. Merging into an existing settings.json is **not** an overwrite — see Phase 3 below for the merge rules. The `--force` gate applies to the standalone hook scripts (under `scripts/`) and to `commit-msg`, not to in-place JSON merges.

## Phase 3: Confirmation and write

Use AskUserQuestion to show the user:

- The exact paths the helper is about to write.
- The exact content of each new hook script (paste the full script body so the user reviews before approving).
- The exact JSON delta the helper will merge into settings.json, if any.
- A "yes / no" question.

On "no", abort cleanly. On "yes", proceed.

### Standalone hook script template (PreToolUse — `enforce-ownership` shape)

Mirrors v1.x `hooks/enforce-ownership.sh`. Write this verbatim to the resolved `commventional-enforce-ownership.sh` path; chmod +x.

```bash
#!/usr/bin/env bash
# commventional-enforce-ownership.sh
# PreToolUse hook for Bash — strips Co-Authored-By trailers and "Generated
# with/by Claude" footers from git commit / gh pr create command payloads.
# Installed by /commventional:install-trailer-stripper.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")

if ! printf '%s\n' "$COMMAND" | grep -qE '(git commit|gh pr create)'; then
  exit 0
fi

CLEANED=$(printf '%s\n' "$COMMAND" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:[^"\x27\\]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^"\x27\\]*//g;
')
CLEANED=$(printf '%s\n' "$CLEANED" | cat -s)

if [ "$COMMAND" = "$CLEANED" ]; then
  exit 0
fi

jq -n --arg cmd "$CLEANED" '{
  "hookSpecificOutput": {
    "updatedInput": {
      "command": $cmd
    }
  }
}'
```

### Standalone hook script template (PostToolUse — `pr-cleanup` shape)

Mirrors v1.x `hooks/pr-ownership-check.sh`. Write this verbatim to the resolved `commventional-pr-cleanup.sh` path; chmod +x.

```bash
#!/usr/bin/env bash
# commventional-pr-cleanup.sh
# PostToolUse hook for Bash — strips Co-Authored-By trailers and "Generated
# with/by Claude" footers from PR bodies after gh pr create / edit.
# Installed by /commventional:install-trailer-stripper.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
if ! printf '%s\n' "$INPUT" | grep -q 'gh pr'; then
  exit 0
fi

COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
STDOUT=$(jq -r '.tool_output.stdout // empty' <<< "$INPUT")

if ! printf '%s\n' "$COMMAND" | grep -qE 'gh pr (create|edit)'; then
  exit 0
fi

PR_URL=$(printf '%s\n' "$STDOUT" | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1)
if [ -z "$PR_URL" ]; then
  PR_URL=$(printf '%s\n' "$COMMAND" | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1)
fi
if [ -z "$PR_URL" ]; then
  PR_URL=$(gh pr view --json url --jq '.url' 2>/dev/null) || true
fi
if [ -z "$PR_URL" ]; then
  exit 0
fi

BODY=$(gh pr view "$PR_URL" --json body --jq '.body' 2>/dev/null) || exit 0

if ! printf '%s\n' "$BODY" | grep -qiE '(Co-Authored-By:|Generated (with|by).*Claude)'; then
  exit 0
fi

CLEANED=$(printf '%s\n' "$BODY" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:[^\n]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^\n]*//g;
')
CLEANED=$(printf '%s\n' "$CLEANED" | cat -s)
CLEANED=$(printf '%s\n' "$CLEANED" | sed -e 's/[[:space:]]*$//')

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
printf '%s' "$CLEANED" > "$TMPFILE"
gh pr edit "$PR_URL" --body-file "$TMPFILE" >/dev/null 2>&1 || true
```

### `commit-msg` template (`git-commit-msg-hook` target)

Write this verbatim to `<repo>/.git/hooks/commit-msg`; chmod +x.

```bash
#!/usr/bin/env bash
# commit-msg — strip engineering-ownership trailers/footers from commit messages.
# Installed by /commventional:install-trailer-stripper --target git-commit-msg-hook.
# Runs on every commit (manual or via Claude); broader than v1.x's PreToolUse hook.

set -euo pipefail

MSG_FILE="${1:?commit-msg expects a path argument}"
ORIGINAL=$(cat "$MSG_FILE")

CLEANED=$(printf '%s\n' "$ORIGINAL" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:[^"\x27\\]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^"\x27\\]*//g;
')
CLEANED=$(printf '%s\n' "$CLEANED" | cat -s)

if [ "$ORIGINAL" = "$CLEANED" ]; then
  exit 0
fi

printf '%s' "$CLEANED" > "$MSG_FILE"
```

### `settings.json` merge

For Claude-Code-settings targets, merge an entry into the existing `hooks.PreToolUse[]` (or `hooks.PostToolUse[]`) array of the resolved settings.json. Use `jq` for the merge — never hand-edit the JSON.

If the file does not exist, create it with the minimal shape:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "<absolute-path-to-commventional-enforce-ownership.sh>",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

If the file already exists, parse it as JSON. Refuse and abort if parsing fails — do not attempt to recover. Otherwise:

1. Ensure `.hooks.PreToolUse` (or `.PostToolUse`) exists as an array.
2. Look for an existing entry with `matcher == "Bash"`. If found, append a new hook entry to its inner `hooks[]` array — do not duplicate if a hook with the same `command` already exists.
3. If no `"Bash"` matcher entry exists, append a new one with the structure above.

Show the user the exact `jq` invocation you will run before running it. Use `--argjson` / `--arg` to inject the absolute path as a string. Write atomically: `jq ... > <tmp> && mv <tmp> <settings.json>`.

For PostToolUse the structure is identical — substitute `PostToolUse` for `PreToolUse` and `commventional-pr-cleanup.sh` for `commventional-enforce-ownership.sh`.

For `--target all`, merge both entries in a single Phase 3 cycle: ask the user which scope (user vs project), then write both standalone scripts and merge both PreToolUse + PostToolUse entries into the chosen settings.json.

## Phase 4: Report

Print to stderr:

- Each path written (full absolute paths).
- The exact contents written to standalone scripts (or the `jq` delta applied to settings.json).
- A copy-pasteable verification command:
  - For Claude-settings targets: `jq '.hooks' <settings.json>` to confirm the entry is present.
  - For `git-commit-msg-hook`: `cat <repo>/.git/hooks/commit-msg && ls -la <repo>/.git/hooks/commit-msg` to confirm executable.
- A reminder that the hook script is now standalone — if commventional updates `bin/strip-trailers.sh`, the consumer must re-run this helper to pick up the change. The installed script is decoupled from the plugin.

## ADR-006 conformance

This skill writes consumer state (`.claude/scripts/`, `.claude/settings.json`, `.git/hooks/commit-msg`) — that is permitted under ADR-006 §1 because the consumer's slash-command invocation is the directing act. The plugin install itself performs no writes; only this skill, only when invoked explicitly by the consumer with an explicit `--target`.

ADR-006 §3 invariants (no payload mutation, no persistent host state, no undeclared writes) are inherited by the **installed** hook scripts — they live in the consumer's surface, so the consumer owns their conformance. v1.x's `enforce-ownership.sh` violated §3 invariant 1 (`updatedInput` payload mutation) when the **plugin** owned the hook; the same payload mutation in a **consumer-installed** hook is the consumer's chosen behaviour, outside the §3 scope.
