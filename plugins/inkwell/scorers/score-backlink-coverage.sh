#!/usr/bin/env bash
# score-backlink-coverage.sh — emit an `inkwell-backlink-coverage`
# observation for the code-documentation dimension.
#
# Counts inkwell-marked docs that terminate with a non-empty
# `## Related` block. Mirrors the tidy `missing-related` rule but as
# a coverage percentage rather than a per-doc finding.
#
# A `## Related` block is "non-empty" iff the file has a heading
# matching `^## +Related[[:space:]]*$` AND at least one non-blank,
# non-`-`-placeholder line follows it before EOF. A
# `<!-- inkwell:related -->` HTML comment counts as content (the
# writer's "intentionally empty" placeholder), mirroring tidy's
# missing-related rule so the two surfaces never disagree about which
# docs have backlinks.
#
# Empty-scope short-circuit:
#   No `docs/**/*.md` carries a Diátaxis `template:` value -> omit
#   observation, exit 0. Audit composite is unchanged on non-inkwell
#   consumers (A4).
#
# Pure shell + grep + awk + jq. No LLM dispatch, no network.
#
# Usage:
#   score-backlink-coverage.sh <REPO_ROOT>
#
# Exit 0 on success or empty-scope. Exit 2 on argument or environment
# errors.

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

if ! inkwell_marked_consumer "$REPO_ROOT"; then
  exit 0
fi

TOTAL=0
WITH_RELATED=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  TOTAL=$((TOTAL + 1))
  related_lineno="$(awk '/^##[[:space:]]+Related[[:space:]]*$/ { last = NR } END { if (last) print last }' "$file")"
  [[ -z "$related_lineno" ]] && continue
  meaningful="$(awk -v start="$related_lineno" '
    NR <= start { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*-[[:space:]]*$/ { next }
    { print; exit }
  ' "$file")"
  if [[ -n "$meaningful" ]]; then
    WITH_RELATED=$((WITH_RELATED + 1))
  fi
done < <(inkwell_list_marked_docs "$REPO_ROOT")

if (( TOTAL == 0 )); then
  exit 0
fi

RATIO=$(format_ratio "$WITH_RELATED" "$TOTAL")

jq -nc \
  --argjson with_related "$WITH_RELATED" \
  --argjson total "$TOTAL" \
  --argjson ratio "$RATIO" \
  '{
    id: "inkwell-backlink-coverage",
    kind: "ratio",
    evidence: {
      with_related: $with_related,
      total: $total,
      ratio: $ratio
    },
    summary: "\($with_related)/\($total) inkwell-marked docs end with a non-empty `## Related` block"
  }'
