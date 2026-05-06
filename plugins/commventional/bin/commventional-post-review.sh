#!/usr/bin/env bash
# commventional-post-review.sh — post a single GitHub pull-request review
# with grouped inline comments, given the locked JSON contract that the
# review-formatter agent emits on stdin.
#
# This script is the deterministic half of /commventional's review path.
# The LLM half is agents/review-formatter.md, which emits the JSON shape
# documented under "Output — locked JSON contract" in that file.
#
# What changes from v2.0:
#   - v2.0: the agent returned formatted human-readable text; the
#     caller posted a wall-of-text PR comment via `gh pr comment`.
#   - v2.1: the agent returns structured JSON; this poster submits one
#     pull-request review with N inline comments grouped under it via
#     `gh api POST repos/{owner}/{repo}/pulls/{n}/reviews`.
#
# The contract surface — field names, body rendering, request shape —
# is locked. Both halves depend on it; SKILL.md documents it inline so
# a future contributor can wire against it without re-deciding.
#
# Usage:
#   commventional-post-review.sh <pr> [--dry-run] [--input <file>] [--head-sha <sha>]
#   ... | commventional-post-review.sh <pr>
#
# <pr> is anything `gh pr view` accepts: a number (102), a URL
# (https://github.com/owner/repo/pull/102), or owner/repo#n shape.
# --head-sha overrides SHA resolution and is the test-surface knob;
# real callers leave it unset and let `gh pr view` resolve it.
#
# Exit codes:
#   0 — posted successfully, or dry-run completed
#   2 — argument or JSON validation error
#   3 — gh not on PATH, unauthenticated, or PR resolution failed
#   4 — gh api returned a non-2xx response (body surfaced on stderr)

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: commventional-post-review.sh <pr> [--dry-run] [--input <file>] [--head-sha <sha>]

Reads a JSON review document from stdin (or --input <file>) and submits
a single GitHub pull-request review with N inline comments grouped
under it.

Arguments:
  <pr>          PR identifier — number, URL, or owner/repo#n.

Options:
  --dry-run     Print the gh api invocation that would run (with the
                JSON body) to stdout. Do not post. Exit 0.
  --input FILE  Read JSON from FILE instead of stdin.
  --head-sha S  Override head-commit SHA resolution. Test-surface
                knob; production callers leave this unset and let
                `gh pr view` resolve the head SHA. When set with
                --dry-run, the gh resolution call is skipped entirely
                so the test runs without network or gh auth.
  --help, -h    Print this help.

JSON contract: see plugins/commventional/agents/review-formatter.md
("Output — locked JSON contract") and plugins/commventional/skills/
commventional/SKILL.md ("Response contract — locked").
EOF
}

PR=""
DRY_RUN=0
INPUT_FILE=""
HEAD_SHA_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --input)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --input requires a path" >&2; exit 2
      fi
      INPUT_FILE="$2"; shift 2 ;;
    --head-sha)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --head-sha requires a value" >&2; exit 2
      fi
      HEAD_SHA_OVERRIDE="$2"; shift 2 ;;
    --) shift; break ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
    *)
      if [[ -z "$PR" ]]; then
        PR="$1"
      else
        echo "ERROR: unexpected positional argument: $1" >&2; exit 2
      fi
      shift ;;
  esac
done

if [[ -z "$PR" ]]; then
  echo "ERROR: PR identifier is required" >&2
  usage >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2
  exit 2
fi

# ----- read input ----------------------------------------------------
if [[ -n "$INPUT_FILE" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: --input file not found: $INPUT_FILE" >&2
    exit 2
  fi
  RAW="$(cat "$INPUT_FILE")"
else
  RAW="$(cat)"
fi

if [[ -z "${RAW//[[:space:]]/}" ]]; then
  echo "ERROR: empty review JSON on stdin (or --input file)" >&2
  exit 2
fi

if ! printf '%s' "$RAW" | jq -e '.' >/dev/null 2>&1; then
  echo "ERROR: input is not valid JSON" >&2
  exit 2
fi

# ----- shape validation ---------------------------------------------
# verdict.body required; verdict.event optional with default COMMENT.
VBODY=$(printf '%s' "$RAW" | jq -r '.verdict.body // ""')
if [[ -z "$VBODY" ]]; then
  echo "ERROR: verdict.body is required (short overall summary)" >&2
  exit 2
fi

VEVENT=$(printf '%s' "$RAW" | jq -r '.verdict.event // "COMMENT"')
case "$VEVENT" in
  COMMENT|APPROVE|REQUEST_CHANGES) : ;;
  *)
    echo "ERROR: verdict.event must be COMMENT, APPROVE, or REQUEST_CHANGES (got: $VEVENT)" >&2
    exit 2 ;;
esac

# comments must be an array (possibly empty).
if ! printf '%s' "$RAW" | jq -e '.comments | type == "array"' >/dev/null 2>&1; then
  echo "ERROR: comments must be an array (use [] for verdict-only reviews)" >&2
  exit 2
fi

NCOMMENTS=$(printf '%s' "$RAW" | jq -r '.comments | length')

# Per-comment required fields: path, line (number), label, subject.
# side defaults to RIGHT when absent.
i=0
while (( i < NCOMMENTS )); do
  for field in path label subject; do
    val=$(printf '%s' "$RAW" | jq -r ".comments[$i].$field // \"\"")
    if [[ -z "$val" ]]; then
      echo "ERROR: comments[$i].$field is required (missing or empty)" >&2
      exit 2
    fi
  done
  ltype=$(printf '%s' "$RAW" | jq -r ".comments[$i].line | type")
  if [[ "$ltype" != "number" ]]; then
    echo "ERROR: comments[$i].line is required and must be a number (got: $ltype)" >&2
    exit 2
  fi
  side=$(printf '%s' "$RAW" | jq -r ".comments[$i].side // \"RIGHT\"")
  case "$side" in
    LEFT|RIGHT) : ;;
    *)
      echo "ERROR: comments[$i].side must be LEFT or RIGHT (got: $side)" >&2
      exit 2 ;;
  esac
  i=$((i + 1))
done

# ----- render the GitHub-shaped comments array -----------------------
# Body shape per comment: "<label>: <subject>\n\n<discussion>"
#   - label: subject is the conventional-comments header line.
#   - discussion is appended after a blank line, only if present.
# This preserves the conventional-comments shape on the wire — what
# changes versus v2.0 is the wrapper around it (one review submission
# with N inline comments, instead of one wall-of-text PR comment).
GH_COMMENTS=$(printf '%s' "$RAW" | jq '
  [
    .comments[] | {
      path: .path,
      line: .line,
      side: (.side // "RIGHT"),
      body: (
        (.label + ": " + .subject)
        + (if (.discussion // "") | length > 0 then "\n\n" + .discussion else "" end)
      )
    }
  ]
')

# ----- resolve PR coordinates ----------------------------------------
# Owner, repo, PR number, head SHA. In dry-run with --head-sha set, we
# skip the gh call entirely so the test surface runs without gh auth.
parse_ident_minimal() {
  local id="$1"
  if [[ "$id" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    NUMBER="${BASH_REMATCH[3]}"
  elif [[ "$id" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    NUMBER="${BASH_REMATCH[3]}"
  elif [[ "$id" =~ ^([0-9]+)$ ]]; then
    NUMBER="${BASH_REMATCH[1]}"
    OWNER="<owner>"
    REPO="<repo>"
  else
    echo "ERROR: cannot parse PR identifier: $id" >&2
    exit 2
  fi
}

OWNER=""; REPO=""; NUMBER=""; HEAD_SHA=""

if (( DRY_RUN )) && [[ -n "$HEAD_SHA_OVERRIDE" ]]; then
  parse_ident_minimal "$PR"
  HEAD_SHA="$HEAD_SHA_OVERRIDE"
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI not found on PATH" >&2
    exit 3
  fi
  if ! VIEW=$(gh pr view "$PR" --json url,number,headRefOid 2>&1); then
    echo "ERROR: gh pr view failed: $VIEW" >&2
    exit 3
  fi
  URL=$(printf '%s' "$VIEW" | jq -r '.url // ""')
  NUMBER=$(printf '%s' "$VIEW" | jq -r '.number // ""')
  HEAD_SHA=$(printf '%s' "$VIEW" | jq -r '.headRefOid // ""')
  if [[ -z "$URL" || ! "$URL" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/[0-9]+ ]]; then
    echo "ERROR: could not parse owner/repo from gh URL: $URL" >&2
    exit 3
  fi
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  if [[ -n "$HEAD_SHA_OVERRIDE" ]]; then
    HEAD_SHA="$HEAD_SHA_OVERRIDE"
  fi
fi

if [[ -z "$NUMBER" || -z "$HEAD_SHA" ]]; then
  echo "ERROR: failed to resolve PR number or head SHA" >&2
  exit 3
fi

# ----- build the request body ----------------------------------------
# jq -S sorts object keys, which gives byte-stable output across runs
# given identical inputs — a precondition for the triple-run
# determinism test.
BODY=$(jq -nS \
  --arg commit_id "$HEAD_SHA" \
  --arg body "$VBODY" \
  --arg event "$VEVENT" \
  --argjson comments "$GH_COMMENTS" \
  '{commit_id: $commit_id, body: $body, event: $event, comments: $comments}')

API_PATH="repos/$OWNER/$REPO/pulls/$NUMBER/reviews"

# ----- dry-run path --------------------------------------------------
if (( DRY_RUN )); then
  printf 'gh api -X POST %s --input -\n' "$API_PATH"
  printf '%s\n' "$BODY"
  exit 0
fi

# ----- live submit ---------------------------------------------------
# Pipe the body via `--input -` to sidestep `gh api` array-flag
# awkwardness with nested arrays (the comments[] field).
if ! RESP=$(printf '%s' "$BODY" | gh api -X POST "$API_PATH" --input - 2>&1); then
  echo "ERROR: gh api POST $API_PATH failed:" >&2
  printf '%s\n' "$RESP" >&2
  exit 4
fi

# Surface the review URL on success. Some gh versions return the URL
# under .html_url; if absent, fall back to a generic success line.
REVIEW_URL=$(printf '%s' "$RESP" | jq -r '.html_url // empty' 2>/dev/null || true)
if [[ -n "$REVIEW_URL" ]]; then
  echo "Posted review: $REVIEW_URL" >&2
else
  echo "Posted review (response did not include html_url)" >&2
fi
