#!/usr/bin/env bash
# score-event-schema-consistency.sh — emit a
# `event-schema-consistency-ratio` observation for the event-emission
# dimension.
#
# This scorer is the most heuristic of the four — "consistent event
# shape" is structurally fuzzier than the other three signals. The
# shipped scoring keeps the heuristic deterministic by reducing
# "consistent" to a measurable proxy: what fraction of structured
# emission sites carry an `event` (or equivalent) field that anchors
# the emission to a named domain transition.
#
# For each language, the scorer reuses the structured-emit pattern
# from score-structured-logging-ratio.sh to enumerate emission sites,
# and per-line checks the call's literal arguments for a "well-shaped"
# anchor.
#
# Per language (well-shaped indicators):
#   python      event=, event_name=, event_type=,
#               "event":/"name":/"type": dict keys,
#               'event':/'name':/'type': single-quoted keys
#   typescript / javascript
#               object literal with event:/name:/type: keys
#               (e.g. log.info({ event: "order.placed", ... }))
#   go          struct field Event:/Name:/Type:; map literal keyed
#               "event"/"name"/"type"
#   rust        event = "...", event_name = "..." (tracing structured
#               field syntax: tracing::info!(event = ..., ...))
#
# distinct_schemas: approximate count of unique event-name strings
# extracted from well-shaped lines via per-language fixed-pattern sed
# capture. Approximate by design — only the dominant `event=` /
# `event:` / `Event:` / `event = ` shape is captured, not the
# secondary `name:` / `type:` / `"name":` shapes. Spec calls for
# "approximate"; the deterministic per-language pattern is the
# load-bearing constraint.
#
# Empty-scope short-circuit:
#   - language == none      -> omit
#   - total_events == 0     -> omit (no structured emissions to assess)
#
# Ratio 0.0 with total_events > 0 IS emitted (structured emissions
# exist but none carry an event-anchor — "structured but not events").
#
# Usage:
#   score-event-schema-consistency.sh <REPO_ROOT>
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

# Reuse the structured-emit patterns from score-structured-logging-ratio.sh.
# Drift between the two scorers' definitions of "structured emission
# site" would make composite scoring incoherent, so the patterns are
# kept identical (any future change to one must propagate to the other).
case "$LANG_DETECTED" in
  python)
    STRUCT_RE='((struct|json|loguru)?logger\.(info|warning|error|debug|critical)\(|structlog\..*\.bind\(|loguru\.logger\.)'
    WELL_SHAPED_RE='((^|[^A-Za-z0-9_])(event|event_name|event_type)[[:space:]]*=|"(event|name|type)"[[:space:]]*:|'"'"'(event|name|type)'"'"'[[:space:]]*:)'
    NAME_EXTRACT='s/.*event[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p'
    ;;
  typescript|javascript)
    STRUCT_RE='((pino|bunyan|winston|log)\.(info|warn|error|debug|trace|fatal)\(|logger\.)'
    WELL_SHAPED_RE='((^|[^A-Za-z0-9_])(event|name|type)[[:space:]]*:[[:space:]]*["'"'"'])'
    NAME_EXTRACT='s/.*event[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p'
    ;;
  go)
    STRUCT_RE='((zerolog|zap|logrus|slog)\.(Info|Warn|Error|Debug)\(|\.Logger\(\)\.)'
    WELL_SHAPED_RE='((^|[^A-Za-z0-9_])(Event|Name|Type)[[:space:]]*:|"(event|name|type)"[[:space:]]*:)'
    NAME_EXTRACT='s/.*Event[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p'
    ;;
  rust)
    STRUCT_RE='(tracing::(info|warn|error|debug|trace)!\(|slog::(info|warn|error|debug)!\(|log::(info|warn|error|debug)!\()'
    WELL_SHAPED_RE='((^|[^A-Za-z0-9_])(event|event_name)[[:space:]]*=[[:space:]]*")'
    NAME_EXTRACT='s/.*event[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p'
    ;;
esac

FILES_LIST="$(mktemp -t towncrier-eventschema-files.XXXXXX)"
SCHEMAS_FILE="$(mktemp -t towncrier-eventschema-names.XXXXXX)"
trap 'rm -f "$FILES_LIST" "$SCHEMAS_FILE"' EXIT
language_source_files "$REPO_ROOT" "$LANG_DETECTED" > "$FILES_LIST"

TOTAL_EVENTS=0
WELL_SHAPED=0

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # Iterate emission-matching lines in this file.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    TOTAL_EVENTS=$((TOTAL_EVENTS + 1))
    if printf '%s\n' "$line" | grep -qE "$WELL_SHAPED_RE"; then
      WELL_SHAPED=$((WELL_SHAPED + 1))
      # Best-effort name extraction (deterministic per-language).
      printf '%s\n' "$line" | sed -nE "$NAME_EXTRACT" >> "$SCHEMAS_FILE"
    fi
  done < <(grep -E "$STRUCT_RE" "$f" 2>/dev/null || true)
done < "$FILES_LIST"

if (( TOTAL_EVENTS == 0 )); then
  exit 0
fi

# `grep -c .` prints "0" then exits 1 on empty input; using `|| echo 0`
# would compound that with another "0", producing "0\n0" which
# jq --argjson rejects. `wc -l` is the cleaner zero-safe count and
# tr strips macOS's leading whitespace.
DISTINCT_SCHEMAS=$(sort -u "$SCHEMAS_FILE" | wc -l | tr -d ' ')
DISTINCT_SCHEMAS=${DISTINCT_SCHEMAS:-0}

RATIO=$(format_ratio "$WELL_SHAPED" "$TOTAL_EVENTS")

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson well "$WELL_SHAPED" \
  --argjson total "$TOTAL_EVENTS" \
  --argjson ratio "$RATIO" \
  --argjson schemas "$DISTINCT_SCHEMAS" \
  '{
    id: "event-schema-consistency-ratio",
    kind: "ratio",
    evidence: {
      language: $lang,
      well_shaped_events: $well,
      total_events: $total,
      ratio: $ratio,
      distinct_schemas: $schemas
    },
    summary: "\($well)/\($total) structured emissions carry an event-anchor field (\($lang); \($schemas) distinct schemas)"
  }'
