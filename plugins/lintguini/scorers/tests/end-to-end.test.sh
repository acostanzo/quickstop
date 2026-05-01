#!/usr/bin/env bash
# end-to-end.test.sh — the lifted 2b1 deferred smoke.
#
# Runs build-envelope.sh against a small python fixture (4 of 8 ruff
# rules + ruff format + 1 wired CI surface + 2 suppression markers),
# then pipes the envelope through pronto's
# observations-to-score.sh helper for the lint-posture dimension.
#
# Asserts:
#   - build-envelope.sh emits a v2 envelope with populated observations[]
#   - composite_score is numeric (transitional math; replaced in 2b3)
#   - observations-to-score.sh exits 0 against the envelope
#   - the helper's output reports passthrough_used: true (no rubric
#     stanza for lint-posture yet — that lands in 2b3)
#   - the helper's output composite_score equals the envelope's
#     composite_score (case-3 passthrough behaviour)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
BUILD="$PLUGIN_ROOT/bin/build-envelope.sh"
HELPER="$REPO_ROOT/plugins/pronto/agents/parsers/scorers/observations-to-score.sh"
FIXTURE="$HERE/fixtures/end-to-end/python-mid"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

# Triple-run determinism on the orchestrator.
e1=$("$BUILD" "$FIXTURE")
e2=$("$BUILD" "$FIXTURE")
e3=$("$BUILD" "$FIXTURE")
if [[ "$e1" != "$e2" || "$e2" != "$e3" ]]; then
  echo "FAIL [build-envelope triple-run]: output diverged across runs" >&2
  fail=1
fi
ENVELOPE="$e1"

# v2 envelope shape
assert_eq "schema_version"     "2"            "$(echo "$ENVELOPE" | jq -r '."$schema_version"')"
assert_eq "plugin"             "lintguini"    "$(echo "$ENVELOPE" | jq -r .plugin)"
assert_eq "dimension"          "lint-posture" "$(echo "$ENVELOPE" | jq -r .dimension)"

# Populated observations[]: linter, formatter, ci-lint, suppression — 4 entries
assert_eq "observations count" "4" "$(echo "$ENVELOPE" | jq -r '.observations | length')"

# composite_score is numeric (not null)
COMPOSITE=$(echo "$ENVELOPE" | jq -r '.composite_score')
if ! [[ "$COMPOSITE" =~ ^[0-9]+$ ]]; then
  echo "FAIL [composite_score]: expected integer, got '$COMPOSITE'" >&2
  fail=1
fi

# Pipe through the pronto helper. case-3 passthrough (no stanza for
# lint-posture in rubric.md yet) → passthrough_used: true; the helper
# emits the envelope's composite_score as the dimension score.
ENV_FILE="$(mktemp -t lintguini-end-to-end.XXXXXX.json)"
trap 'rm -f "$ENV_FILE"' EXIT
echo "$ENVELOPE" > "$ENV_FILE"

HELPER_OUT="$("$HELPER" lint-posture "$ENV_FILE" 2>/dev/null)"
HELPER_EXIT=$?
if (( HELPER_EXIT != 0 )); then
  echo "FAIL [helper exit]: expected 0, got $HELPER_EXIT" >&2
  fail=1
fi

assert_eq "passthrough_used"      "true"        "$(echo "$HELPER_OUT" | jq -r .passthrough_used)"
assert_eq "helper composite"      "$COMPOSITE"  "$(echo "$HELPER_OUT" | jq -r .composite_score)"

if (( fail == 0 )); then
  echo "end-to-end.test.sh: PASS (composite_score=$COMPOSITE, passthrough_used=true)"
  exit 0
else
  echo "end-to-end.test.sh: FAIL" >&2
  exit 1
fi
