#!/usr/bin/env bash
# lintguini-detect-language.sh — print the language(s) detected in a
# consumer repo, one per line, in stable rubric order:
#   python rust go ruby typescript javascript
#
# Wraps the detect_languages helper from scorers/_common.sh so the
# M2 /lintguini:configure skill and any other tooling can call a
# single executable instead of sourcing the bash helper directly.
#
# By default emits all detected languages (polyglot-friendly). Pass
# --primary to restrict output to a single language using the same
# precedence the scorers use.
#
# Usage:
#   lintguini-detect-language.sh <REPO_ROOT>
#   lintguini-detect-language.sh --primary <REPO_ROOT>
#
# Empty stdout (exit 0) when no language is detected. Exit 2 on
# argument errors.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../scorers/_common.sh
. "$PLUGIN_ROOT/scorers/_common.sh"

PRIMARY=0
if [[ "${1:-}" == "--primary" ]]; then
  PRIMARY=1
  shift
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") [--primary] <REPO_ROOT>" >&2
  exit 2
fi
REPO_ROOT="$1"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi

if (( PRIMARY == 1 )); then
  result="$(detect_primary_language "$REPO_ROOT")"
  [[ "$result" == "none" ]] || printf '%s\n' "$result"
else
  detect_languages "$REPO_ROOT"
fi
