#!/usr/bin/env bash
# score-linter-presence.sh — emit a `linter-strictness-ratio`
# observation for the lint-posture dimension.
#
# Counts configured linter rules from the repo's primary language
# config against the per-language baseline documented in
# plugins/pronto/references/roll-your-own/lint-posture.md:
#
#   python      -> [tool.ruff.lint] select cardinality vs 8
#   javascript  -> biome.json linter.rules vs 1, or .eslintrc /
#                  eslint.config.* presence vs 1
#   typescript  -> tsconfig strict-bundle flags (cap 4)
#                  + @typescript-eslint plugin presence (0/1)
#                  + biome/eslint cardinality (0/1)
#                  vs 6 (4 + 1 + 1)
#   rust        -> [lints.{rust,clippy}] entry count vs 2
#   go          -> .golangci.yml linters.enable cardinality vs 6
#   ruby        -> .rubocop.yml cop departments enabled vs 5,
#                  or standard.yml -> baseline-pass by convention
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
  javascript)
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
    else
      for f in "$REPO_ROOT"/eslint.config.js "$REPO_ROOT"/eslint.config.mjs "$REPO_ROOT"/eslint.config.cjs "$REPO_ROOT"/eslint.config.ts; do
        if [[ -f "$f" ]]; then
          CONFIGURED=1
          break
        fi
      done
    fi
    ;;
  typescript)
    # TS strict-baseline: 4 strict-bundle tsconfig flags + 1
    # @typescript-eslint plugin presence + 1 biome/eslint detection.
    BASELINE=6
    STRICT_FLAGS=0
    TSCONFIG="$REPO_ROOT/tsconfig.json"
    if [[ -f "$TSCONFIG" ]]; then
      # `strict: true` is shorthand for the full strict bundle (4 flags).
      STRICT_BUNDLE=$(jq -r '(.compilerOptions.strict // false) | tostring' \
                         "$TSCONFIG" 2>/dev/null || echo false)
      if [[ "$STRICT_BUNDLE" == "true" ]]; then
        STRICT_FLAGS=4
      else
        for flag in noImplicitAny strictNullChecks noUncheckedIndexedAccess strictFunctionTypes strictBindCallApply strictPropertyInitialization alwaysStrict noImplicitThis useUnknownInCatchVariables; do
          val=$(jq -r --arg f "$flag" '(.compilerOptions[$f] // false) | tostring' \
                   "$TSCONFIG" 2>/dev/null || echo false)
          [[ "$val" == "true" ]] && STRICT_FLAGS=$((STRICT_FLAGS + 1))
        done
        # Cap individual-flag count at the strict-bundle baseline of 4.
        if (( STRICT_FLAGS > 4 )); then
          STRICT_FLAGS=4
        fi
      fi
    fi
    # @typescript-eslint plugin reference in any eslint config form.
    TS_ESLINT=0
    for f in "$REPO_ROOT"/.eslintrc* "$REPO_ROOT"/eslint.config.js "$REPO_ROOT"/eslint.config.mjs "$REPO_ROOT"/eslint.config.cjs "$REPO_ROOT"/eslint.config.ts; do
      [[ -f "$f" ]] || continue
      if grep -q '@typescript-eslint' "$f" 2>/dev/null; then
        TS_ESLINT=1
        break
      fi
    done
    # biome/eslint base detection — same shape as the javascript branch.
    JS_BASE=0
    if [[ -f "$REPO_ROOT/biome.json" ]]; then
      RECOMMENDED=$(jq -r '(.linter.rules.recommended // false) | if . then 1 else 0 end' \
                       "$REPO_ROOT/biome.json" 2>/dev/null || echo 0)
      EXTRA=$(jq -r '((.linter.rules // {}) | keys | map(select(. != "recommended")) | length)' \
                 "$REPO_ROOT/biome.json" 2>/dev/null || echo 0)
      if (( RECOMMENDED + EXTRA > 0 )); then
        JS_BASE=1
      fi
    fi
    if (( JS_BASE == 0 )) && compgen -G "$REPO_ROOT/.eslintrc*" >/dev/null 2>&1; then
      JS_BASE=1
    fi
    if (( JS_BASE == 0 )); then
      for f in "$REPO_ROOT"/eslint.config.js "$REPO_ROOT"/eslint.config.mjs "$REPO_ROOT"/eslint.config.cjs "$REPO_ROOT"/eslint.config.ts; do
        if [[ -f "$f" ]]; then
          JS_BASE=1
          break
        fi
      done
    fi
    CONFIGURED=$((STRICT_FLAGS + TS_ESLINT + JS_BASE))
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
  ruby)
    # Baseline: 5 cop departments (Style, Layout, Lint, Metrics,
    # Naming). standardrb is opinionated — its presence pins to the
    # baseline by convention (the whole point of standardrb is no
    # rule-by-rule debates).
    BASELINE=5
    if [[ -f "$REPO_ROOT/standard.yml" ]]; then
      CONFIGURED=5
    elif [[ -f "$REPO_ROOT/.rubocop.yml" ]]; then
      # Count distinct department prefixes mentioned in the local
      # config. Departments outside the canonical 5 (Bundler, Gemspec,
      # Security, Performance, Rails, etc.) don't count toward the
      # strict-baseline of 5 — they're domain-specific add-ons rather
      # than the universal-codebase strictness signal.
      CONFIGURED=$(grep -oE '^(Style|Layout|Lint|Metrics|Naming)/' \
                     "$REPO_ROOT/.rubocop.yml" 2>/dev/null \
                     | sort -u | wc -l | tr -d ' ')
      CONFIGURED=${CONFIGURED:-0}
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
