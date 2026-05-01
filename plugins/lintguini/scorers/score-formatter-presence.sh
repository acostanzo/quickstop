#!/usr/bin/env bash
# score-formatter-presence.sh — emit a `formatter-configured-count`
# observation for the lint-posture dimension.
#
# Per-language formatter detection:
#   python  -> [tool.ruff.format] in pyproject.toml,
#              or [tool.black] in pyproject.toml,
#              or top-level .black.toml
#   js/ts   -> biome.json formatter.enabled == true,
#              or any .prettierrc* file at repo root
#   rust    -> rustfmt.toml or .rustfmt.toml at repo root
#   go      -> go.mod present (gofmt is the implicit Go default —
#              there is no opt-out config; presence of go.mod is the
#              sufficient signal)
#
# Configured: 0 or 1. Empty-scope short-circuit on language == none.
#
# Usage:
#   score-formatter-presence.sh <REPO_ROOT>
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

CONFIGURED=0
TOOL=""

case "$LANG_DETECTED" in
  python)
    if [[ -f "$REPO_ROOT/pyproject.toml" ]]; then
      if grep -qE '^\[tool\.ruff\.format\]' "$REPO_ROOT/pyproject.toml"; then
        CONFIGURED=1
        TOOL="ruff format"
      elif grep -qE '^\[tool\.black\]' "$REPO_ROOT/pyproject.toml"; then
        CONFIGURED=1
        TOOL="black"
      fi
    fi
    if (( CONFIGURED == 0 )) && [[ -f "$REPO_ROOT/.black.toml" ]]; then
      CONFIGURED=1
      TOOL="black"
    fi
    ;;
  javascript|typescript)
    if [[ -f "$REPO_ROOT/biome.json" ]]; then
      ENABLED=$(jq -r '(.formatter.enabled // false) | tostring' \
                   "$REPO_ROOT/biome.json" 2>/dev/null || echo false)
      if [[ "$ENABLED" == "true" ]]; then
        CONFIGURED=1
        TOOL="biome format"
      fi
    fi
    if (( CONFIGURED == 0 )) && compgen -G "$REPO_ROOT/.prettierrc*" >/dev/null 2>&1; then
      CONFIGURED=1
      TOOL="prettier"
    fi
    ;;
  rust)
    if [[ -f "$REPO_ROOT/rustfmt.toml" || -f "$REPO_ROOT/.rustfmt.toml" ]]; then
      CONFIGURED=1
      TOOL="rustfmt"
    fi
    ;;
  go)
    # gofmt is the implicit Go default. go.mod presence (which is
    # what got us into this branch) is the sufficient signal.
    CONFIGURED=1
    TOOL="gofmt"
    ;;
esac

SUMMARY=""
if (( CONFIGURED == 1 )); then
  SUMMARY="Formatter configured (${LANG_DETECTED}: ${TOOL})"
else
  SUMMARY="No formatter configured (${LANG_DETECTED})"
fi

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson configured "$CONFIGURED" \
  --arg summary "$SUMMARY" \
  '{
    id: "formatter-configured-count",
    kind: "count",
    evidence: {
      language: $lang,
      configured: $configured
    },
    summary: $summary
  }'
