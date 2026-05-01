#!/usr/bin/env bash
# score-linter-presence.sh — emit a `linter-strictness-ratio`
# observation for the lint-posture dimension.
#
# Counts configured linter rules from the repo's primary language
# config against the per-language baseline documented in
# plugins/pronto/references/roll-your-own/lint-posture.md:
#
#   python  -> [tool.ruff.lint] select cardinality vs 8
#   js/ts   -> biome.json linter.rules vs 1, or .eslintrc presence vs 1
#   rust    -> [lints.{rust,clippy}] entry count vs 2
#   go      -> .golangci.yml linters.enable cardinality vs 6
#
# Configured > baseline → ratio clamped to 1.0 (over-strictness isn't
# rewarded). Configured == 0 (no linter detected even with language
# detected, or no language detected) → observation omitted (empty-scope
# short-circuit per the 2a2 pattern).
#
# Usage:
#   score-linter-presence.sh <REPO_ROOT>
#
# Exit 0 on success (one-line JSON observation on stdout, or empty
# stdout for empty scope). Exit 2 on argument or environment errors.

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
BASELINE=0

case "$LANG_DETECTED" in
  python)
    BASELINE=8
    if [[ -f "$REPO_ROOT/pyproject.toml" ]]; then
      # Count items inside [tool.ruff.lint] select = [...]; awk handles
      # multi-line arrays by capturing from `[` to matching `]`.
      CONFIGURED=$(awk '
        BEGIN { in_lint = 0; in_select = 0; collected = "" }
        /^\[tool\.ruff\.lint\][[:space:]]*$/ { in_lint = 1; next }
        /^\[/ && in_lint && !in_select       { in_lint = 0 }
        in_lint && /^[[:space:]]*select[[:space:]]*=/ {
          in_select = 1
          line = $0
          sub(/^[^=]*=[[:space:]]*\[/, "", line)
          collected = line
          if (collected ~ /\]/) {
            sub(/\].*/, "", collected)
            print collected
            in_select = 0
            exit
          }
          next
        }
        in_select {
          if ($0 ~ /\]/) {
            line = $0; sub(/\].*/, "", line)
            collected = collected " " line
            print collected
            in_select = 0
            exit
          } else {
            collected = collected " " $0
          }
        }
      ' "$REPO_ROOT/pyproject.toml" \
        | tr ',' '\n' \
        | grep -cE '"[^"]+"' || true)
      CONFIGURED=${CONFIGURED:-0}
      # Fallback: ruff/black/flake8 block present but no ruff [lint]
      # block → linter recognised, baseline pass = 1.
      if (( CONFIGURED == 0 )) && grep -qE '^\[tool\.(ruff|black|flake8)\]' "$REPO_ROOT/pyproject.toml"; then
        CONFIGURED=1
      fi
    fi
    if (( CONFIGURED == 0 )) && [[ -f "$REPO_ROOT/.flake8" ]]; then
      CONFIGURED=1
    fi
    ;;
  javascript|typescript)
    BASELINE=1
    if [[ -f "$REPO_ROOT/biome.json" ]]; then
      RECOMMENDED=$(jq -r '(.linter.rules.recommended // false) | if . then 1 else 0 end' \
                       "$REPO_ROOT/biome.json" 2>/dev/null || echo 0)
      EXTRA=$(jq -r '((.linter.rules // {}) | keys | map(select(. != "recommended")) | length)' \
                 "$REPO_ROOT/biome.json" 2>/dev/null || echo 0)
      CONFIGURED=$((RECOMMENDED + EXTRA))
    elif compgen -G "$REPO_ROOT/.eslintrc*" >/dev/null 2>&1; then
      # ESLint deep-parse is out of scope (see 2b2 ticket); presence
      # alone passes the cardinality-1 baseline.
      CONFIGURED=1
    fi
    ;;
  rust)
    BASELINE=2
    if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
      # Count entries in [lints.clippy] and [lints.rust] tables.
      CONFIGURED=$(awk '
        BEGIN { in_block = 0; count = 0 }
        /^\[lints\.(clippy|rust)\][[:space:]]*$/ { in_block = 1; next }
        /^\[/ && in_block                        { in_block = 0 }
        in_block && /^[a-zA-Z_][a-zA-Z0-9_-]*[[:space:]]*=/ { count++ }
        END { print count }
      ' "$REPO_ROOT/Cargo.toml")
    fi
    ;;
  go)
    BASELINE=6
    GLF=""
    if   [[ -f "$REPO_ROOT/.golangci.yml" ]];  then GLF="$REPO_ROOT/.golangci.yml"
    elif [[ -f "$REPO_ROOT/.golangci.yaml" ]]; then GLF="$REPO_ROOT/.golangci.yaml"
    fi
    if [[ -n "$GLF" ]]; then
      CONFIGURED=$(awk '
        BEGIN { in_linters = 0; in_enable = 0; count = 0 }
        /^linters:[[:space:]]*$/                                { in_linters = 1; next }
        in_linters && /^[a-zA-Z]/                               { in_linters = 0; in_enable = 0 }
        in_linters && /^[[:space:]]+enable:[[:space:]]*$/       { in_enable = 1; next }
        in_linters && /^[[:space:]]+[a-zA-Z]/ && in_enable      { in_enable = 0 }
        in_enable && /^[[:space:]]+-[[:space:]]+/               { count++ }
        END { print count }
      ' "$GLF")
    fi
    ;;
esac

# Empty-scope short-circuit: language detected but no linter config → omit.
if (( CONFIGURED == 0 )); then
  exit 0
fi

# Clamp to baseline (over-strictness pins to 1.0; under tracks linearly).
CLAMPED=$CONFIGURED
if (( CLAMPED > BASELINE )); then
  CLAMPED=$BASELINE
fi
RATIO=$(format_ratio "$CLAMPED" "$BASELINE")

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson configured "$CONFIGURED" \
  --argjson baseline "$BASELINE" \
  --argjson ratio "$RATIO" \
  '{
    id: "linter-strictness-ratio",
    kind: "ratio",
    evidence: {
      language: $lang,
      configured_rules: $configured,
      baseline_rules: $baseline,
      ratio: $ratio
    },
    summary: "\($configured)/\($baseline) baseline lint rules configured (\($lang))"
  }'
