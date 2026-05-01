#!/usr/bin/env bash
# score-suppression-count.sh — emit a `lint-suppression-count`
# observation for the lint-posture dimension.
#
# Per-language suppression-marker grep across source files:
#   python  -> `# noqa`, `# type: ignore`, `# pylint: disable`
#               in **/*.py (excludes .venv / venv / __pycache__)
#   js/ts   -> `eslint-disable[-next-line|-line]?`, `// @ts-ignore`,
#               `// @ts-expect-error` in **/*.{js,jsx,ts,tsx,mjs,cjs}
#               (excludes node_modules / dist / build)
#   rust    -> `#[allow(`, `#![allow(` in **/*.rs (excludes target)
#   go      -> `//nolint[…]?`, `//lint:ignore` in **/*.go
#               (excludes vendor)
#
# threshold_high = 50 (documented; the rubric stanza in 2b3 will
# lay the count-to-score ladder over it).
#
# Empty-scope short-circuit:
#  - language == none → omit observation
#  - language detected, zero source files → omit observation
#
# Source-file count (files_scanned) is meaningful as denominator;
# zero-suppression-on-many-files is a useful signal worth emitting.
#
# Usage:
#   score-suppression-count.sh <REPO_ROOT>
#
# Exit 0 on success. Exit 2 on argument or environment errors.

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

LANG_DETECTED="$(detect_primary_language "$REPO_ROOT")"
if [[ "$LANG_DETECTED" == "none" ]]; then
  exit 0
fi

# Per-language grep regex + find arguments.
case "$LANG_DETECTED" in
  python)
    SUPP_RE='(#[[:space:]]*noqa([[:space:]]|:|$)|#[[:space:]]*type:[[:space:]]*ignore|#[[:space:]]*pylint:[[:space:]]*disable)'
    FIND_ARGS=(-type f -name '*.py'
               -not -path '*/.venv/*' -not -path '*/venv/*' -not -path '*/__pycache__/*')
    ;;
  javascript|typescript)
    SUPP_RE='(eslint-disable(-next-line|-line)?|//[[:space:]]*@ts-ignore|//[[:space:]]*@ts-expect-error)'
    FIND_ARGS=(-type f \(
               -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx'
               -o -name '*.mjs' -o -name '*.cjs'
               \)
               -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*')
    ;;
  rust)
    SUPP_RE='(#\[allow\(|#!\[allow\()'
    FIND_ARGS=(-type f -name '*.rs' -not -path '*/target/*')
    ;;
  go)
    SUPP_RE='(//[[:space:]]*nolint([[:space:]]|:|$)|//[[:space:]]*lint:ignore)'
    FIND_ARGS=(-type f -name '*.go' -not -path '*/vendor/*')
    ;;
esac

FILES_LIST="$(mktemp -t lintguini-suppress-files.XXXXXX)"
trap 'rm -f "$FILES_LIST"' EXIT

find "$REPO_ROOT" "${FIND_ARGS[@]}" -print 2>/dev/null | sort > "$FILES_LIST"
SCANNED=$(wc -l < "$FILES_LIST" | tr -d ' ')
SCANNED=${SCANNED:-0}

if (( SCANNED == 0 )); then
  exit 0
fi

# Sum grep counts deterministically. `grep -c` per file may exit 1 on
# zero matches; `|| true` keeps the pipeline alive.
SUPPRESSIONS=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  c=$(grep -cE "$SUPP_RE" "$f" 2>/dev/null || true)
  c=${c:-0}
  SUPPRESSIONS=$((SUPPRESSIONS + c))
done < "$FILES_LIST"

THRESHOLD_HIGH=50

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson suppressions "$SUPPRESSIONS" \
  --argjson scanned "$SCANNED" \
  --argjson threshold "$THRESHOLD_HIGH" \
  '{
    id: "lint-suppression-count",
    kind: "count",
    evidence: {
      language: $lang,
      suppressions: $suppressions,
      files_scanned: $scanned,
      threshold_high: $threshold
    },
    summary: "\($suppressions) suppression marker(s) across \($scanned) source file(s) (\($lang))"
  }'
