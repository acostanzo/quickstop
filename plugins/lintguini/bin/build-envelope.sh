#!/usr/bin/env bash
# build-envelope.sh — orchestrate the four lint-posture scorers and
# emit a v2 wire-contract envelope on stdout.
#
# Runs each scorer in fixed order. Non-empty stdout from a scorer is
# treated as one observation; empty stdout (the empty-scope
# short-circuit) is dropped. The collected observations are slurped
# into the envelope's observations[] array.
#
# Composite_score is computed by a transitional formula documented
# inline below — equal-share mean of per-observation sub-scores
# derived from each kind's evidence shape. This formula is replaced
# in 2b3 by the lint-posture rubric stanza in
# plugins/pronto/references/rubric.md (the rubric stanza becomes the
# authority; the inline math here goes away).
#
# ADR-006 conformance: read-only against <REPO_ROOT>; only writes to
# stdout and ephemeral $TMPDIR tempfiles cleaned by trap. Pure shell
# + grep + awk + jq — no language toolchain on PATH required, no
# network calls.
#
# Usage:
#   build-envelope.sh <REPO_ROOT>
#
# Exit 0 on success. Exit 2 on argument or environment errors.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
SCORERS_DIR="$PLUGIN_ROOT/scorers"

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

OBS_FILE="$(mktemp -t lintguini-observations.XXXXXX.json)"
trap 'rm -f "$OBS_FILE"' EXIT

# Run the four scorers in fixed order so observations[] order is
# deterministic across machines.
for scorer in \
  score-linter-presence.sh \
  score-formatter-presence.sh \
  score-ci-lint-wired.sh \
  score-suppression-count.sh
do
  out="$("$SCORERS_DIR/$scorer" "$REPO_ROOT")"
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out" >> "$OBS_FILE"
  fi
done

# ---------------------------------------------------------------------------
# Transitional composite math (REPLACED IN 2b3 by the rubric stanza).
# ---------------------------------------------------------------------------
# Per-observation sub-score:
#   linter-strictness-ratio       -> ratio * 100
#   formatter-configured-count    -> 100 if configured == 1 else 0
#   ci-lint-wired-ratio           -> ratio * 100
#   lint-suppression-count        -> threshold ladder:
#       0   → 100
#       1–5 → 95
#       6–20 → 85
#       21–50 → 70
#       51–100 → 50
#       >100 → 25
#
# Composite = round(arithmetic mean of sub-scores). When
# observations[] is empty (every scorer empty-scoped), composite is
# null and the rubric helper degrades to presence-cap downstream.
COMPOSITE=$(jq -s '
  if length == 0 then null
  else
    ([.[] | (
      if   .id == "linter-strictness-ratio"     then (.evidence.ratio * 100)
      elif .id == "formatter-configured-count"  then (if .evidence.configured == 1 then 100 else 0 end)
      elif .id == "ci-lint-wired-ratio"         then (.evidence.ratio * 100)
      elif .id == "lint-suppression-count"      then
        (.evidence.suppressions as $n |
          if   $n == 0   then 100
          elif $n <= 5   then 95
          elif $n <= 20  then 85
          elif $n <= 50  then 70
          elif $n <= 100 then 50
          else 25 end)
      else 100 end
    )]) as $scores
    | (($scores | add) / ($scores | length) | round)
  end
' "$OBS_FILE")

# Assemble the v2 envelope.
jq -s --argjson composite "$COMPOSITE" '{
  "$schema_version": 2,
  plugin: "lintguini",
  dimension: "lint-posture",
  categories: [],
  observations: .,
  composite_score: $composite,
  recommendations: []
}' "$OBS_FILE"
