#!/usr/bin/env bash
# score-ci-lint-wired.sh — emit a `ci-lint-wired-ratio` observation
# for the lint-posture dimension.
#
# Walks the repo for CI surfaces and greps each for lint
# invocations. Surfaces:
#   .github/workflows/*.{yml,yaml}   (one surface per file)
#   .gitlab-ci.yml                   (one surface)
#   .circleci/config.yml             (one surface)
#   Makefile / makefile              (one surface)
#   lefthook.yml / .lefthook.yml /
#     lefthook.yaml                  (one surface)
#   .pre-commit-config.yaml          (one surface)
#
# A surface counts as "lint-wired" if any of the fixed lint-invocation
# regexes matches it (ruff/biome/eslint/prettier/clippy/cargo
# fmt/clippy/golangci-lint/gofmt/black/flake8). Ratio =
# surfaces-with-lint / surfaces-detected.
#
# Empty-scope short-circuit: zero CI surfaces detected → observation
# omitted (we don't conflate "no CI" with "broken lint in CI").
#
# Usage:
#   score-ci-lint-wired.sh <REPO_ROOT>
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

# Fixed lint-invocation regex (case-insensitive). Order is alphabetical
# by tool name so additions are easy to audit. Word-boundary semantics
# are approximated by leading whitespace / line-start and trailing
# whitespace / EOL — `grep -iE` against shell-y CI YAML.
LINT_RE='(^|[[:space:]])(black([[:space:]]|--check)|biome[[:space:]]+(check|format|lint)|cargo[[:space:]]+(fmt|clippy)|clippy|eslint([[:space:]]|$)|flake8|gofmt|golangci-lint|prettier([[:space:]]|--check|--write)|ruff[[:space:]]+(check|format))'

# Collect surfaces deterministically: sorted file list.
SURFACES_FILE="$(mktemp -t lintguini-ci-surfaces.XXXXXX)"
trap 'rm -f "$SURFACES_FILE"' EXIT

if [[ -d "$REPO_ROOT/.github/workflows" ]]; then
  find "$REPO_ROOT/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print 2>/dev/null \
    | sort >> "$SURFACES_FILE"
fi
for f in \
  "$REPO_ROOT/.gitlab-ci.yml" \
  "$REPO_ROOT/.circleci/config.yml" \
  "$REPO_ROOT/Makefile" \
  "$REPO_ROOT/makefile" \
  "$REPO_ROOT/lefthook.yml" \
  "$REPO_ROOT/.lefthook.yml" \
  "$REPO_ROOT/lefthook.yaml" \
  "$REPO_ROOT/.pre-commit-config.yaml"
do
  [[ -f "$f" ]] && echo "$f" >> "$SURFACES_FILE"
done

DETECTED=$(wc -l < "$SURFACES_FILE" | tr -d ' ')
DETECTED=${DETECTED:-0}

# Empty-scope: no CI surfaces → omit observation.
if (( DETECTED == 0 )); then
  exit 0
fi

WIRED=0
while IFS= read -r surface; do
  [[ -z "$surface" ]] && continue
  if grep -iqE "$LINT_RE" "$surface" 2>/dev/null; then
    WIRED=$((WIRED + 1))
  fi
done < "$SURFACES_FILE"

RATIO=$(format_ratio "$WIRED" "$DETECTED")

jq -nc \
  --argjson detected "$DETECTED" \
  --argjson wired "$WIRED" \
  --argjson ratio "$RATIO" \
  '{
    id: "ci-lint-wired-ratio",
    kind: "ratio",
    evidence: {
      ci_surfaces_detected: $detected,
      ci_surfaces_with_lint: $wired,
      ratio: $ratio
    },
    summary: "\($wired)/\($detected) CI surfaces invoke a linter"
  }'
