#!/usr/bin/env bash
# score-metrics-presence.sh — emit a `metrics-instrumentation-count`
# observation for the event-emission dimension.
#
# Detects the repo's primary language and reports two signals:
#
#   configured     — boolean (0 or 1) — is a metrics library imported
#                    or declared as a dependency?
#   metrics_sites  — integer count of metrics-defining call sites
#                    (counters, histograms, gauges, summaries, statsd
#                     incr/gauge/histogram).
#
# Per language (configured):
#   python      `from prometheus_client import`, `import prometheus_client`,
#               `from opentelemetry.metrics import`, `from statsd import`,
#               `import datadog`  (in *.py)
#   typescript / javascript
#               `from "prom-client"`, `from "@opentelemetry/sdk-metrics"`,
#               `from "node-statsd"`, `from "hot-shots"`,
#               `from "datadog-metrics"`  (in *.ts/*.tsx/*.js/*.jsx)
#   go          `prometheus/client_golang`, `go.opentelemetry.io/otel/metric`,
#               `cactus/go-statsd-client`  (in *.go)
#   rust        `prometheus`, `metrics`, `opentelemetry` keys in
#               Cargo.toml's [dependencies] block.
#
# Per language (metrics_sites):
#   python      Counter(, Histogram(, Gauge(, Summary(,
#               meter.create_(counter|histogram|up_down_counter),
#               statsd.(incr|gauge|histogram)(
#   typescript / javascript
#               new (Counter|Histogram|Gauge|Summary)(, createCounter(,
#               createHistogram(, .observe(,
#               statsd.(increment|gauge|histogram)(
#   go          prometheus.NewCounter(Vec)?(, prometheus.NewHistogram(Vec)?(,
#               prometheus.NewGauge(Vec)?(, .Float64Counter(,
#               .Int64Histogram(
#   rust        counter!(, gauge!(, histogram!(, register_counter!(
#
# Empty-scope short-circuit:
#   - language == none                         -> omit observation
#   - configured == 0 AND metrics_sites == 0   -> omit observation
#   - configured == 1, metrics_sites == 0      -> emit (the
#       "imported but unused" signal — infra exists but isn't used)
#
# Evidence shape: emits both `metrics_sites` (the canonical domain
# field, kept for downstream introspection) and `count` (a duplicate
# of `metrics_sites` consumed by the H4 translator's count-extractor).
# The translator's lookup chain is `count` → `configured` → `value` →
# first-numeric, and `configured` is a boolean we don't want
# laddered, so the explicit `count` field disambiguates which integer
# the rubric stanza scores against.
#
# Usage:
#   score-metrics-presence.sh <REPO_ROOT>
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
METRICS_SITES=0

case "$LANG_DETECTED" in
  python)
    CONFIG_RE='(from[[:space:]]+prometheus_client[[:space:]]+import|import[[:space:]]+prometheus_client|from[[:space:]]+opentelemetry\.metrics[[:space:]]+import|from[[:space:]]+statsd[[:space:]]+import|import[[:space:]]+datadog($|[[:space:]]))'
    SITES_RE='(Counter\(|Histogram\(|Gauge\(|Summary\(|meter\.create_(counter|histogram|up_down_counter)|statsd\.(incr|gauge|histogram)\()'
    ;;
  typescript|javascript)
    CONFIG_RE='(from[[:space:]]+["'\'']prom-client["'\'']|from[[:space:]]+["'\'']@opentelemetry/sdk-metrics["'\'']|from[[:space:]]+["'\'']node-statsd["'\'']|from[[:space:]]+["'\'']hot-shots["'\'']|from[[:space:]]+["'\'']datadog-metrics["'\''])'
    SITES_RE='(new[[:space:]]+(Counter|Histogram|Gauge|Summary)\(|createCounter\(|createHistogram\(|\.observe\(|statsd\.(increment|gauge|histogram)\()'
    ;;
  go)
    CONFIG_RE='(prometheus/client_golang|go\.opentelemetry\.io/otel/metric|cactus/go-statsd-client)'
    SITES_RE='(prometheus\.NewCounter(Vec)?\(|prometheus\.NewHistogram(Vec)?\(|prometheus\.NewGauge(Vec)?\(|\.Float64Counter\(|\.Int64Histogram\()'
    ;;
  rust)
    # Rust configured detection is parse-bounded to the [dependencies]
    # block of Cargo.toml — `metrics = "0.21"` outside [dependencies]
    # (e.g. as a section header anywhere else) doesn't count.
    if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
      CONFIGURED=$(awk '
        BEGIN { in_deps = 0; configured = 0 }
        /^\[dependencies\][[:space:]]*$/ { in_deps = 1; next }
        /^\[/ && in_deps                 { in_deps = 0 }
        in_deps && /^(prometheus|metrics|opentelemetry)[[:space:]]*=/ { configured = 1 }
        END { print configured }
      ' "$REPO_ROOT/Cargo.toml")
    fi
    SITES_RE='(counter!\(|gauge!\(|histogram!\(|register_counter!\()'
    ;;
esac

FILES_LIST="$(mktemp -t towncrier-metrics-files.XXXXXX)"
trap 'rm -f "$FILES_LIST"' EXIT
language_source_files "$REPO_ROOT" "$LANG_DETECTED" > "$FILES_LIST"

# Source-file-based configured detection (rust uses Cargo.toml above).
if [[ "$LANG_DETECTED" != "rust" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if grep -qE "$CONFIG_RE" "$f" 2>/dev/null; then
      CONFIGURED=1
      break
    fi
  done < "$FILES_LIST"
fi

METRICS_SITES=$(count_pattern_hits "$SITES_RE" "$FILES_LIST")

# Empty-scope: nothing detected and no call sites → omit.
if (( CONFIGURED == 0 )) && (( METRICS_SITES == 0 )); then
  exit 0
fi

if (( CONFIGURED == 1 )) && (( METRICS_SITES > 0 )); then
  SUMMARY="$METRICS_SITES metrics-defining call site(s) ($LANG_DETECTED, library configured)"
elif (( CONFIGURED == 1 )); then
  SUMMARY="0 metrics-defining call sites ($LANG_DETECTED, library imported but unused)"
else
  SUMMARY="$METRICS_SITES metrics-defining call site(s) ($LANG_DETECTED, no library import detected)"
fi

jq -nc \
  --arg lang "$LANG_DETECTED" \
  --argjson configured "$CONFIGURED" \
  --argjson sites "$METRICS_SITES" \
  --arg summary "$SUMMARY" \
  '{
    id: "metrics-instrumentation-count",
    kind: "count",
    evidence: {
      language: $lang,
      configured: $configured,
      metrics_sites: $sites,
      count: $sites
    },
    summary: $summary
  }'
