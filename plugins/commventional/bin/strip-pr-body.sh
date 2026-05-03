#!/usr/bin/env bash
# strip-pr-body.sh — convenience wrapper around strip-trailers.sh for the
# GitHub-PR-body case. Fetches a PR body via gh, runs it through
# strip-trailers, writes the cleaned body back via gh pr edit --body-file.
#
# Mirrors the v1.x PostToolUse hook (hooks/pr-ownership-check.sh) but
# moves the trigger to the consumer per ADR-006 §1: this script only
# acts when the consumer invokes it (directly or via the install helper).
#
# Usage:
#   strip-pr-body.sh --pr-url <https://github.com/owner/repo/pull/N>

set -euo pipefail

PR_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-url)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --pr-url requires an argument" >&2
        exit 2
      fi
      PR_URL="$2"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: strip-pr-body.sh --pr-url <url>

Fetches a PR body via gh, strips engineering-ownership trailers/footers,
writes the cleaned body back via gh pr edit --body-file. Idempotent.
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PR_URL" ]]; then
  echo "ERROR: --pr-url is required" >&2
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found on PATH" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRIPPER="$SCRIPT_DIR/strip-trailers.sh"

if [[ ! -x "$STRIPPER" ]]; then
  echo "ERROR: strip-trailers.sh not executable at $STRIPPER" >&2
  exit 2
fi

BODY=$(gh pr view "$PR_URL" --json body --jq '.body')
CLEANED=$(printf '%s' "$BODY" | bash "$STRIPPER")

if [[ "$BODY" == "$CLEANED" ]]; then
  echo "PR body is already clean — no changes." >&2
  exit 0
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
printf '%s' "$CLEANED" > "$TMPFILE"

gh pr edit "$PR_URL" --body-file "$TMPFILE" >/dev/null
echo "Updated PR body: $PR_URL" >&2
