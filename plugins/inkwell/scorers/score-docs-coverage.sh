#!/usr/bin/env bash
# score-docs-coverage.sh — emit a `docs-coverage-ratio` observation
# for the code-documentation dimension.
#
# Detects the repo's primary language and dispatches to the canonical
# docstring-coverage tool for that language:
#
#   python  -> interrogate -q --fail-under 0 (text-mode TOTAL row)
#   js      -> eslint with `jsdoc/require-jsdoc: error` (JSON output)
#   ts      -> eslint as above, scoped to *.ts/*.tsx
#   go      -> revive with the exported-doc rule (JSON output)
#   rust    -> cargo doc --show-coverage (stdout coverage line)
#
# Empty-scope short-circuit:
#   detect_language returns `other`        -> omit observation, exit 0
#                                            (no language detected)
# Tool-absent branch (per 2a2 invariant B):
#   the language's tool is not on PATH     -> stderr notice, omit
#                                            observation, exit 0
#
# The 80% gate convention (interrogate's `--fail-under 80` default)
# informs the 2a3 rubric stanza, not this scorer. 2a2 emits the raw
# ratio plus best-effort documented/total counts; 2a3 lays the
# threshold ladder over it.
#
# Usage:
#   score-docs-coverage.sh <REPO_ROOT>
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

LANG_DETECTED="$(detect_language "$REPO_ROOT")"
if [[ "$LANG_DETECTED" == "other" ]]; then
  exit 0  # empty-scope: no language detected
fi

# Dispatch table outputs three values into shell vars: DOCUMENTED, TOTAL,
# RATIO. Empty/unparseable -> caller exits without emitting.
DOCUMENTED=""
TOTAL=""
RATIO=""

case "$LANG_DETECTED" in
  python)
    if ! tool_available interrogate; then
      exit 0
    fi
    # interrogate's verbose-level-1 output prints a Markdown summary
    # table that ends with a TOTAL row; --fail-under 0 keeps exit
    # code at 0 regardless of coverage. The TOTAL row format is:
    #   | TOTAL              | <total> | <miss> | <pct>% |
    # `-v` (not `-q`) is required — `-q` suppresses all output.
    OUT=$(interrogate -v --fail-under 0 "$REPO_ROOT" 2>&1 || true)
    TOTAL_ROW=$(echo "$OUT" | grep -E '\| *TOTAL *\|' | tail -1)
    if [[ -n "$TOTAL_ROW" ]]; then
      # Extract the three numeric columns by splitting on `|`.
      total=$(echo "$TOTAL_ROW" | awk -F'|' '{gsub(/ /,"",$3); print $3}')
      miss=$(echo  "$TOTAL_ROW" | awk -F'|' '{gsub(/ /,"",$4); print $4}')
      if [[ "$total" =~ ^[0-9]+$ && "$miss" =~ ^[0-9]+$ ]]; then
        TOTAL=$total
        DOCUMENTED=$((total - miss))
      fi
    fi
    ;;
  js|ts)
    if ! tool_available eslint; then
      exit 0
    fi
    # eslint with jsdoc/require-jsdoc emits per-file message arrays in
    # JSON output. Count messageless files (= "documented") vs total.
    # Scope js -> *.{js,jsx,mjs,cjs}; ts -> *.{ts,tsx}.
    if [[ "$LANG_DETECTED" == "js" ]]; then
      EXTS='.js,.jsx,.mjs,.cjs'
    else
      EXTS='.ts,.tsx'
    fi
    OUT=$(eslint --no-eslintrc \
                 --rule '{"jsdoc/require-jsdoc":"error"}' \
                 --format json \
                 --ext "$EXTS" \
                 "$REPO_ROOT" 2>/dev/null || true)
    if echo "$OUT" | jq empty >/dev/null 2>&1; then
      TOTAL=$(echo "$OUT" | jq 'length')
      DOCUMENTED=$(echo "$OUT" | jq '[.[] | select(.errorCount == 0 and .warningCount == 0)] | length')
    fi
    ;;
  go)
    if ! tool_available revive; then
      exit 0
    fi
    # revive in JSON mode emits an array of {Position, Failure, ...};
    # one entry per missing-doc finding. Count tracked files via
    # `go list ./...` for the denominator.
    OUT=$(revive -formatter json "$REPO_ROOT/..." 2>/dev/null || true)
    if echo "$OUT" | jq empty >/dev/null 2>&1; then
      missing=$(echo "$OUT" | jq 'length')
      if command -v go >/dev/null 2>&1; then
        total_files=$( (cd "$REPO_ROOT" && go list -f '{{.GoFiles | len}}' ./... 2>/dev/null | awk '{s+=$1} END {print s+0}') )
        if [[ "$total_files" =~ ^[0-9]+$ && "$missing" =~ ^[0-9]+$ ]]; then
          TOTAL=$total_files
          DOCUMENTED=$((total_files - missing))
          (( DOCUMENTED < 0 )) && DOCUMENTED=0
        fi
      fi
    fi
    ;;
  rust)
    if ! tool_available cargo; then
      exit 0
    fi
    # `cargo doc --show-coverage` prints a coverage line per crate plus
    # a TOTAL line. The line format is roughly:
    #   | <crate>     | 80.0% (16/20)            | 0.0% (0/0)              |
    # Grab the rightmost (a/b) under "Documented" column.
    OUT=$( (cd "$REPO_ROOT" && cargo doc --show-coverage --no-deps 2>&1) || true )
    TOTAL_ROW=$(echo "$OUT" | grep -E '^ *\| *Total' | tail -1)
    if [[ -n "$TOTAL_ROW" ]]; then
      pair=$(echo "$TOTAL_ROW" | grep -oE '\([0-9]+/[0-9]+\)' | head -1 | tr -d '()')
      if [[ "$pair" =~ ^([0-9]+)/([0-9]+)$ ]]; then
        DOCUMENTED="${BASH_REMATCH[1]}"
        TOTAL="${BASH_REMATCH[2]}"
      fi
    fi
    ;;
esac

# If parse failed (DOCUMENTED or TOTAL still empty), omit the
# observation rather than emit garbage.
if [[ -z "$DOCUMENTED" || -z "$TOTAL" ]]; then
  echo "Notice: $LANG_DETECTED docs-coverage tool produced unparseable output; observation omitted" >&2
  exit 0
fi

# Empty-scope: language detected but the tool found zero items to
# inspect (e.g. interrogate against a dir with no .py files).
if (( TOTAL == 0 )); then
  exit 0
fi

RATIO=$(format_ratio "$DOCUMENTED" "$TOTAL")

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson documented "$DOCUMENTED" \
  --argjson total "$TOTAL" \
  --argjson ratio "$RATIO" \
  '{
    id: "docs-coverage-ratio",
    kind: "ratio",
    evidence: {
      language: $lang,
      documented: $documented,
      total: $total,
      ratio: $ratio
    },
    summary: "\($documented)/\($total) public \($lang) APIs documented"
  }'
