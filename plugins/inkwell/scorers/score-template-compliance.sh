#!/usr/bin/env bash
# score-template-compliance.sh — emit an `inkwell-template-compliance`
# observation for the code-documentation dimension.
#
# Counts inkwell-marked docs (frontmatter `template:` ∈
# {concept, how-to, reference, tutorial}) whose frontmatter also
# carries the other required fields (`title`, `updated`). Compliant /
# total is the emitted ratio.
#
# Empty-scope short-circuit (per ADR-007 and the T5 acceptance
# criteria):
#   No `docs/**/*.md` carries a Diátaxis `template:` value -> omit
#   observation, exit 0. The audit's existing four scorers are the
#   sole contributors on non-inkwell consumers, so the composite
#   letter grade is unchanged.
#
# Pure shell + grep + awk + jq. No LLM dispatch, no network. ADR-007
# is explicit about the audit-vs-query split: corroboration runs in
# `/inkwell:query` only; this scorer (and the audit at large) stays
# deterministic and CI-friendly.
#
# Usage:
#   score-template-compliance.sh <REPO_ROOT>
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
  exit 0   # empty-scope: no inkwell frontmatter on this consumer
fi

TOTAL=0
COMPLIANT=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  TOTAL=$((TOTAL + 1))
  fm="$(inkwell_extract_frontmatter "$file")"
  title="$(inkwell_fm_field title "$fm")"
  updated="$(inkwell_fm_field updated "$fm")"
  template="$(inkwell_fm_field template "$fm")"
  if [[ -n "$title" && -n "$updated" && "$template" =~ $VALID_INKWELL_TEMPLATES_RE ]]; then
    COMPLIANT=$((COMPLIANT + 1))
  fi
done < <(inkwell_list_marked_docs "$REPO_ROOT")

# inkwell_marked_consumer returned true so TOTAL >= 1, but be defensive.
if (( TOTAL == 0 )); then
  exit 0
fi

RATIO=$(format_ratio "$COMPLIANT" "$TOTAL")

jq -nc \
  --argjson compliant "$COMPLIANT" \
  --argjson total "$TOTAL" \
  --argjson ratio "$RATIO" \
  '{
    id: "inkwell-template-compliance",
    kind: "ratio",
    evidence: {
      compliant: $compliant,
      total: $total,
      ratio: $ratio
    },
    summary: "\($compliant)/\($total) inkwell-marked docs have valid template + required fields"
  }'
