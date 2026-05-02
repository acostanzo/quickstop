#!/usr/bin/env bash
# score-structured-logging-ratio.sh — emit a `structured-logging-ratio`
# observation for the event-emission dimension.
#
# Detects the repo's primary language (per the precedence chain in
# _common.sh) and walks source files for emission-shape patterns.
# Two pattern classes:
#
#   structured   — calls into a known structured logger
#   unstructured — free-form print / console.log / fmt.Println
#
# Per language:
#   python      structured: logger.{info|warning|error|debug|critical}(,
#                          structlog....bind(, loguru.logger.
#               unstructured: print(, sys.stderr.write(, sys.stdout.write(
#   typescript / javascript
#               structured: {pino|bunyan|winston|log}.{info|warn|error|
#                          debug|trace|fatal}(, logger.
#               unstructured: console.{log|error|warn|info|debug}(,
#                            process.std{out|err}.write(
#   go          structured: {zerolog|zap|logrus|slog}.{Info|Warn|Error|
#                          Debug}(, .Logger().
#               unstructured: fmt.{Print|Println|Printf}(,
#                            os.Std{out|err}.Write(
#   rust        structured: tracing::{info|warn|error|debug|trace}!(,
#                          slog::{info|warn|error|debug}!(,
#                          log::{info|warn|error|debug}!(
#               unstructured: println!(, eprintln!(, print!(, eprint!(
#
# This is the bait-and-switch case the 2c plan calls for: kernel-level
# greps for the structured logger import (handled at the orchestrator
# level, not here) pass; THIS scorer counts emission-site shape and
# reports ratio < 0.5 if half the emit sites are still console.log.
#
# Empty-scope short-circuit:
#   - language == none           → omit observation
#   - total emission sites == 0  → omit observation
# Ratio 0.0 with total > 0 (all-freeform) is a valid signal and IS
# emitted — that's the difference between "no scope" (silent) and
# "fully unstructured" (emitted).
#
# Usage:
#   score-structured-logging-ratio.sh <REPO_ROOT>
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

# Per-language structured + unstructured regex (ERE, OR'd within class).
# A single line matching multiple alternatives in the same class still
# counts as 1 (grep -c counts lines, not match positions); a line
# matching one alternative in BOTH classes is rare in practice and
# would count once in each — the fixtures avoid that shape.
case "$LANG_DETECTED" in
  python)
    STRUCT_RE='((struct|json|loguru)?logger\.(info|warning|error|debug|critical)\(|structlog\..*\.bind\(|loguru\.logger\.)'
    UNSTRUCT_RE='((^|[^A-Za-z0-9_])print\(|sys\.stderr\.write\(|sys\.stdout\.write\()'
    ;;
  typescript|javascript)
    STRUCT_RE='((pino|bunyan|winston|log)\.(info|warn|error|debug|trace|fatal)\(|logger\.)'
    UNSTRUCT_RE='(console\.(log|error|warn|info|debug)\(|process\.stdout\.write\(|process\.stderr\.write\()'
    ;;
  go)
    STRUCT_RE='((zerolog|zap|logrus|slog)\.(Info|Warn|Error|Debug)\(|\.Logger\(\)\.)'
    UNSTRUCT_RE='(fmt\.(Print|Println|Printf)\(|os\.Std(out|err)\.Write\()'
    ;;
  rust)
    STRUCT_RE='(tracing::(info|warn|error|debug|trace)!\(|slog::(info|warn|error|debug)!\(|log::(info|warn|error|debug)!\()'
    UNSTRUCT_RE='(println!\(|eprintln!\(|print!\(|eprint!\()'
    ;;
esac

FILES_LIST="$(mktemp -t towncrier-structlog-files.XXXXXX)"
trap 'rm -f "$FILES_LIST"' EXIT
language_source_files "$REPO_ROOT" "$LANG_DETECTED" > "$FILES_LIST"

STRUCT_SITES=$(count_pattern_hits "$STRUCT_RE" "$FILES_LIST")
UNSTRUCT_SITES=$(count_pattern_hits "$UNSTRUCT_RE" "$FILES_LIST")
TOTAL_SITES=$((STRUCT_SITES + UNSTRUCT_SITES))

if (( TOTAL_SITES == 0 )); then
  exit 0
fi

RATIO=$(format_ratio "$STRUCT_SITES" "$TOTAL_SITES")

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson struct_sites "$STRUCT_SITES" \
  --argjson total_sites "$TOTAL_SITES" \
  --argjson ratio "$RATIO" \
  '{
    id: "structured-logging-ratio",
    kind: "ratio",
    evidence: {
      language: $lang,
      structured_sites: $struct_sites,
      total_sites: $total_sites,
      ratio: $ratio
    },
    summary: "\($struct_sites)/\($total_sites) emission sites use a structured logger (\($lang))"
  }'
