#!/usr/bin/env bash
# build-envelope.sh — orchestrate the four event-emission scorers and
# emit a v2 wire-contract envelope on stdout.
#
# Runs each scorer in fixed order. Non-empty stdout from a scorer is
# treated as one observation; empty stdout (the empty-scope short-
# circuit — language not detected, no emission sites, no handler-shaped
# files, no metrics infra) is dropped. The collected observations are
# slurped via `jq -s` into the envelope's observations[] array.
#
# composite_score is null — the rubric stanza in
# plugins/pronto/references/rubric.md is the authority on dimension
# scoring. Empty observations[] (every scorer empty-scoped) also emits
# null, which the translator's case-3 carve-out routes through to
# presence-cap downstream.
#
# ADR-006 conformance: read-only against <REPO_ROOT>; only writes to
# stdout and ephemeral $TMPDIR tempfiles cleaned by trap. Pure shell +
# grep + awk + jq — no language toolchain on PATH is required for the
# orchestrator itself, no network calls, no consumer-state mutation.
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

OBS_FILE="$(mktemp -t towncrier-observations.XXXXXX.json)"
trap 'rm -f "$OBS_FILE"' EXIT

# Run the four scorers in fixed order so observations[] order is
# deterministic across machines. The fixed order also pins the
# observation-ID set assertion in snapshots.test.sh.
for scorer in \
  score-structured-logging-ratio.sh \
  score-metrics-presence.sh \
  score-trace-propagation.sh \
  score-event-schema-consistency.sh
do
  out="$("$SCORERS_DIR/$scorer" "$REPO_ROOT")"
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out" >> "$OBS_FILE"
  fi
done

# Assemble the v2 envelope.
jq -s '{
  "$schema_version": 2,
  plugin: "towncrier",
  dimension: "event-emission",
  categories: [],
  observations: .,
  composite_score: null,
  recommendations: []
}' "$OBS_FILE"
