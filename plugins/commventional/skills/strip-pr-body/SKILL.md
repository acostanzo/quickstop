---
name: strip-pr-body
description: Fetch a GitHub PR body, strip engineering-ownership trailers/footers, write the cleaned body back via gh pr edit. Consumer-invoked per-call.
disable-model-invocation: true
allowed-tools: Bash
argument-hint: --pr-url <url>
---

# /commventional:strip-pr-body

Convenience capability for the GitHub-PR-body case of trailer-stripping. Wraps `:strip-trailers` with a `gh pr view` / `gh pr edit --body-file` round-trip, so the consumer can clean a single PR's body on demand.

This is the consumer-invoked equivalent of commventional v1.x's `PostToolUse` hook (`hooks/pr-ownership-check.sh`), preserved as a capability per ADR-006 §1. Removed: the v1.x trigger that fired this on every `gh pr (create|edit)` Bash call. Preserved: the trailer-stripping behaviour, idempotent and read-then-write-back on a specific PR.

## Usage

Parse `$ARGUMENTS` for `--pr-url <url>`. If missing or malformed, ask the user for the PR URL.

Run the canonical script and emit its stdout/stderr verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/strip-pr-body.sh" --pr-url "<https://github.com/owner/repo/pull/N>"
```

The script exits cleanly when the body is already clean (no `gh pr edit` call is made). When changes happen, it prints `"Updated PR body: <url>"` to stderr and exits 0.

## Mutation surface

This skill writes to **the GitHub PR body the consumer named in `--pr-url`**, and only that. No other consumer artefact is touched. ADR-006 §2 (no silent mutation of consumer artefacts) is satisfied because the consumer typed the slash command and supplied the target URL — the directing act is explicit.

## Composition

- **Manual cleanup of a specific PR:** `/commventional:strip-pr-body --pr-url <url>`.
- **Bulk cleanup script:** the consumer can loop over `gh pr list` and call this skill (or the underlying `bin/strip-pr-body.sh` script) per URL — that loop lives in the consumer's surface, not commventional's.
- **Restore the v1.x PostToolUse trigger:** run `/commventional:install-trailer-stripper --target pr-cleanup-hook-user` (or `pr-cleanup-hook-project`) — the install helper writes the equivalent hook into the consumer's chosen Claude Code settings scope.

## Reference

- `bin/strip-pr-body.sh` — the script this skill invokes.
- `bin/strip-trailers.sh` — the underlying capability the script wraps.
- ADR-006 §1 / §2 — capability/trigger boundary and non-mutation rule that motivate the consumer-invoked posture.
