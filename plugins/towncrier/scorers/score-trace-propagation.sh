#!/usr/bin/env bash
# score-trace-propagation.sh — emit a `trace-propagation-ratio`
# observation for the event-emission dimension.
#
# Detects the repo's primary language. Then walks source files for
# request-handler-shaped files and counts the fraction of those files
# that reference trace context (W3C trace headers, OTel span APIs,
# instrumentation calls).
#
# Per language (handler-shape — file must match ≥1 pattern to count
# as a handler-shaped file):
#   python      Flask(, FastAPI(, @app.{route|get|post|put|delete},
#               def view_, class .*View(Set)?(,
#               aiohttp.web.RouteTableDef()
#   typescript / javascript
#               express(), fastify(, app.{get|post|put|delete|patch}(,
#               @Controller(, Router()
#   go          http.HandleFunc(, mux.Handle(Func)?(, gin.New(,
#               chi.NewRouter(, fiber.New(
#   rust        axum::Router::new(, actix_web::App::new(,
#               rocket::build(, warp::path
#
# Per language (trace-context inside handler files — file matches ≥1
# pattern to count toward handlers_with_trace):
#   python      traceparent, tracestate, trace.get_current_span(,
#               set_attribute(, tracer.start_as_current_span(
#   typescript / javascript
#               traceparent, tracestate, trace.getActiveSpan(,
#               propagation.inject(, propagation.extract(
#   go          traceparent, tracestate, tracer.Start(,
#               otelhttp.NewHandler(, propagation.HeaderCarrier
#   rust        traceparent, tracestate, tracing::Span::current(),
#               .instrument(, use tracing::Instrument, OpenTelemetryLayer
#
# Empty-scope short-circuit:
#   - language == none           -> omit
#   - handlers_total == 0        -> omit (no handlers to instrument;
#       this is the CLI-tool acceptance bar — a CLI tool with no
#       request-handler-shaped files shouldn't be faulted for lacking
#       trace propagation it never had occasion to need)
#
# Emits ratio 0.0 with handlers_total > 0 (handlers exist, none trace)
# — that's "infrastructure exists but isn't used", a real signal worth
# surfacing (cf. python-otel-bare fixture).
#
# Usage:
#   score-trace-propagation.sh <REPO_ROOT>
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

case "$LANG_DETECTED" in
  python)
    HANDLER_RE='(Flask\(|FastAPI\(|@app\.(route|get|post|put|delete)|def[[:space:]]+view_|class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(.*View(Set)?[\(:]|aiohttp\.web\.RouteTableDef\(\))'
    TRACE_RE='(traceparent|tracestate|trace\.get_current_span\(|set_attribute\(|tracer\.start_as_current_span\()'
    ;;
  typescript|javascript)
    HANDLER_RE='(express\(\)|fastify\(|app\.(get|post|put|delete|patch)\(|@Controller\(|Router\(\))'
    TRACE_RE='(traceparent|tracestate|trace\.getActiveSpan\(|propagation\.inject\(|propagation\.extract\()'
    ;;
  go)
    HANDLER_RE='(http\.HandleFunc\(|mux\.Handle(Func)?\(|gin\.New\(|chi\.NewRouter\(|fiber\.New\()'
    TRACE_RE='(traceparent|tracestate|tracer\.Start\(|otelhttp\.NewHandler\(|propagation\.HeaderCarrier)'
    ;;
  rust)
    HANDLER_RE='(axum::Router::new\(|actix_web::App::new\(|rocket::build\(|warp::path)'
    TRACE_RE='(traceparent|tracestate|tracing::Span::current\(\)|\.instrument\(|use[[:space:]]+tracing::Instrument|OpenTelemetryLayer)'
    ;;
esac

FILES_LIST="$(mktemp -t towncrier-trace-files.XXXXXX)"
trap 'rm -f "$FILES_LIST"' EXIT
language_source_files "$REPO_ROOT" "$LANG_DETECTED" > "$FILES_LIST"

HANDLERS_TOTAL=0
HANDLERS_WITH_TRACE=0

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if grep -qE "$HANDLER_RE" "$f" 2>/dev/null; then
    HANDLERS_TOTAL=$((HANDLERS_TOTAL + 1))
    if grep -qE "$TRACE_RE" "$f" 2>/dev/null; then
      HANDLERS_WITH_TRACE=$((HANDLERS_WITH_TRACE + 1))
    fi
  fi
done < "$FILES_LIST"

# Empty-scope: no handler-shaped files in the detected language.
if (( HANDLERS_TOTAL == 0 )); then
  exit 0
fi

RATIO=$(format_ratio "$HANDLERS_WITH_TRACE" "$HANDLERS_TOTAL")

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson with_trace "$HANDLERS_WITH_TRACE" \
  --argjson total "$HANDLERS_TOTAL" \
  --argjson ratio "$RATIO" \
  '{
    id: "trace-propagation-ratio",
    kind: "ratio",
    evidence: {
      language: $lang,
      handlers_with_trace: $with_trace,
      handlers_total: $total,
      ratio: $ratio
    },
    summary: "\($with_trace)/\($total) request-handler files reference trace context (\($lang))"
  }'
