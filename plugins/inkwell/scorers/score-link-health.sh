#!/usr/bin/env bash
# score-link-health.sh — emit a `broken-internal-links-count`
# observation for the code-documentation dimension.
#
# Runs `lychee --offline --format json` over README.md and the docs/
# tree, parses the JSON output for broken links and broken anchor
# fragments, and emits a count observation. `--offline` skips network
# checks; only on-disk file targets and within-document anchors are
# validated. This is intentional — a network-aware lychee run picks
# up flaky external links and adds variance the harness can't tolerate.
#
# Empty-scope short-circuit: neither README.md nor docs/ at <REPO_ROOT>
#   -> omit observation (no stdout) and exit 0.
# Tool-absent branch: `lychee` not on PATH
#   -> stderr notice, omit observation, exit 0
#   (per 2a2 invariant B: tool absence isn't a fatal audit error).
#
# Output schema:
#   evidence.broken         — count of failed link checks (top-level
#                             `errors` or `failures` from lychee JSON)
#   evidence.scanned        — total checks performed (top-level `total`)
#   evidence.anchors_broken — best-effort count of failed entries whose
#                             URL is an anchor reference (`#fragment`).
#                             lychee's JSON shape evolves across
#                             versions; the parser falls back to 0 if
#                             the field structure doesn't expose URLs
#                             cleanly.
#
# Usage:
#   score-link-health.sh <REPO_ROOT>
#
# Exit 0 on success or any documented short-circuit. Exit 2 on
# argument or environment errors.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$HERE/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <REPO_ROOT>" >&2
  exit 2
fi
REPO_ROOT="$1"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required" >&2
  exit 2
fi

# Empty-scope: nothing to scan.
HAS_README=0
HAS_DOCS=0
[[ -f "$REPO_ROOT/README.md" ]] && HAS_README=1
[[ -d "$REPO_ROOT/docs"     ]] && HAS_DOCS=1
if (( HAS_README == 0 && HAS_DOCS == 0 )); then
  exit 0
fi

# Tool-absent branch.
if ! tool_available lychee; then
  exit 0
fi

# Build lychee args from what's present.
LYCHEE_ARGS=(--offline --format json --no-progress)
[[ "$HAS_README" -eq 1 ]] && LYCHEE_ARGS+=("$REPO_ROOT/README.md")
[[ "$HAS_DOCS"   -eq 1 ]] && LYCHEE_ARGS+=("$REPO_ROOT/docs")

# Run lychee. lychee exits non-zero when it finds broken links — that
# is a normal-result, not a scorer error. Capture stdout regardless and
# only treat exit codes that signal real failures (stdout missing /
# unparseable JSON) as scorer errors.
LYCHEE_OUT="$(mktemp -t inkwell-lychee.XXXXXX.json)"
trap 'rm -f "$LYCHEE_OUT"' EXIT
lychee "${LYCHEE_ARGS[@]}" > "$LYCHEE_OUT" 2>/dev/null || true

if ! jq -e . >/dev/null 2>&1 < "$LYCHEE_OUT"; then
  echo "Notice: lychee output not parseable as JSON; observation omitted" >&2
  exit 0
fi

# Defensive field extraction. lychee's JSON shape evolves across
# versions — try `errors`, then `failures`, then `fail_map` length;
# similarly for `total`. Default to 0 if no field matches.
BROKEN=$(jq -r '
  (.errors      // .failures // ([.fail_map[]?] | add | length // 0))
  | tonumber? // 0
' < "$LYCHEE_OUT")
SCANNED=$(jq -r '
  (.total // (((.successful // 0) + (.errors // .failures // 0)) | tonumber))
  | tonumber? // 0
' < "$LYCHEE_OUT")

# Anchor-broken count: best-effort. fail_map values are arrays whose
# entries carry a `url` field; an anchor reference is `#fragment` or
# ends in `#fragment`. Count those.
ANCHORS_BROKEN=$(jq -r '
  [
    (.fail_map // {}) | to_entries[].value[]?
    | (.url // .uri // empty)
    | select(test("#[^#]+$"))
  ] | length
' < "$LYCHEE_OUT" 2>/dev/null || echo 0)
ANCHORS_BROKEN=${ANCHORS_BROKEN:-0}

jq -nc \
  --argjson broken "$BROKEN" \
  --argjson scanned "$SCANNED" \
  --argjson anchors_broken "$ANCHORS_BROKEN" \
  '{
    id: "broken-internal-links-count",
    kind: "count",
    evidence: {
      broken: $broken,
      scanned: $scanned,
      anchors_broken: $anchors_broken
    },
    summary: "\($broken) broken internal link(s) + \($anchors_broken) broken anchor(s) across \($scanned) scanned"
  }'
