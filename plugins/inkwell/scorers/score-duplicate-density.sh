#!/usr/bin/env bash
# score-duplicate-density.sh — emit an `inkwell-duplicate-density`
# observation for the code-documentation dimension.
#
# Counts pairs of inkwell-marked docs whose title + body shingle
# Jaccard overlap exceeds the duplicate threshold from
# references/thresholds.json (`tidy.duplicate_overlap_min`,
# default 0.85). The emitted ratio is
# `near_duplicate_pairs / total_inkwell_docs` — a density measure
# rather than a per-doc finding (the per-doc finding is what tidy
# emits).
#
# The shingle implementation is the same one inkwell-tidy.sh uses
# (extracted to scorers/_common.sh as `bigrams_for_doc` and
# `jaccard_files`) so the scorer and the tidy finding can never
# disagree about which pairs are duplicates.
#
# Empty-scope short-circuit:
#   No `docs/**/*.md` carries a Diátaxis `template:` value -> omit
#   observation, exit 0. Audit composite is unchanged on non-inkwell
#   consumers (A4).
#
# Pure shell + grep + awk + jq. No LLM dispatch, no network.
#
# Usage:
#   score-duplicate-density.sh <REPO_ROOT>
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

# Thresholds.
THRESHOLDS_JSON="$HERE/../references/thresholds.json"
DUP_MIN="0.85"
if [[ -f "$THRESHOLDS_JSON" ]] && command -v jq >/dev/null 2>&1; then
  v="$(jq -r '.tidy.duplicate_overlap_min // 0.85' <"$THRESHOLDS_JSON" 2>/dev/null || echo 0.85)"
  DUP_MIN="$v"
fi

# Collect marked docs.
mapfile -t MARKED < <(inkwell_list_marked_docs "$REPO_ROOT")
TOTAL=${#MARKED[@]}
if (( TOTAL == 0 )); then
  exit 0
fi

# Build per-doc bigram files.
BIGRAM_DIR="$(mktemp -d -t inkwell-dup-density.XXXXXX)"
trap 'rm -rf "$BIGRAM_DIR"' EXIT
for ((i = 0; i < TOTAL; i++)); do
  bigrams_for_doc "${MARKED[i]}" "$BIGRAM_DIR/$i"
done

# Float comparison via awk (locale-independent).
ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 >= b+0) }'; }

PAIRS=0
for ((i = 0; i < TOTAL; i++)); do
  bi_count="$(wc -l <"$BIGRAM_DIR/$i" | tr -d ' ')"
  if (( bi_count < 5 )); then continue; fi
  for ((j = i + 1; j < TOTAL; j++)); do
    bj_count="$(wc -l <"$BIGRAM_DIR/$j" | tr -d ' ')"
    if (( bj_count < 5 )); then continue; fi
    score="$(jaccard_files "$BIGRAM_DIR/$i" "$BIGRAM_DIR/$j")"
    if ge "$score" "$DUP_MIN"; then
      PAIRS=$((PAIRS + 1))
    fi
  done
done

DENSITY=$(format_ratio "$PAIRS" "$TOTAL")

jq -nc \
  --argjson pairs "$PAIRS" \
  --argjson total "$TOTAL" \
  --argjson density "$DENSITY" \
  --arg threshold "$DUP_MIN" \
  '{
    id: "inkwell-duplicate-density",
    kind: "ratio",
    evidence: {
      near_duplicate_pairs: $pairs,
      total_inkwell_docs: $total,
      threshold: $threshold,
      density: $density
    },
    summary: "\($pairs) near-duplicate pair(s) across \($total) inkwell-marked docs (>= \($threshold) shingle overlap)"
  }'
