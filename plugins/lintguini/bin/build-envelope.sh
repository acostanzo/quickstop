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

# Assemble the v2 envelope. composite_score is null — the rubric
# stanza in plugins/pronto/references/rubric.md is the authority on
# dimension scoring. Empty observations[] (every scorer empty-scoped)
# also emits null, which the translator's case-3 carve-out routes
# through to presence-cap downstream.
jq -s '{
  "$schema_version": 2,
  plugin: "lintguini",
  dimension: "lint-posture",
  categories: [],
  observations: .,
  composite_score: null,
  recommendations: []
}' "$OBS_FILE"
