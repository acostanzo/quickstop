#!/usr/bin/env bash
# end-to-end.test.sh — the lifted 2b1 deferred smoke, now exercising
# all three first-class language paths shipped by 2b2.
#
# Runs build-envelope.sh against three fixtures:
#   - python-mid     (4 of 8 ruff rules + ruff format + wired CI + 2 # noqa)
#   - ruby-mid       (3 of 5 cop departments + rubocop autocorrect cops
#                     + wired CI + 2 rubocop:disable / todo)
#   - typescript-mid (1 of 6 ts strict bundle + biome formatter +
#                     wired CI + 2 @ts-ignore)
#
# Each envelope pipes through pronto's observations-to-score.sh helper
# for the lint-posture dimension. The helper's output asserts:
#   - exits 0 (helper accepts the envelope shape)
#   - passthrough_used: true (no rubric stanza for lint-posture yet —
#     that lands in 2b3)
#   - composite_score equals the envelope's composite_score (case-3
#     passthrough behaviour)
#
# Per-fixture composite_score is hard-asserted to lock the
# transitional math (replaced in 2b3 by the rubric stanza). python-mid
# is the regression bar — its 86 must hold across the JS/TS dispatch
# split and the ruby branch addition.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
BUILD="$PLUGIN_ROOT/bin/build-envelope.sh"
HELPER="$REPO_ROOT/plugins/pronto/agents/parsers/scorers/observations-to-score.sh"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

ENV_FILE="$(mktemp -t lintguini-end-to-end.XXXXXX.json)"
trap 'rm -f "$ENV_FILE"' EXIT

run_fixture() {
  local name="$1" expected_composite="$2"
  local fixture="$HERE/fixtures/end-to-end/$name"

  # Triple-run determinism on the orchestrator.
  local e1 e2 e3
  e1=$("$BUILD" "$fixture")
  e2=$("$BUILD" "$fixture")
  e3=$("$BUILD" "$fixture")
  if [[ "$e1" != "$e2" || "$e2" != "$e3" ]]; then
    echo "FAIL [$name build-envelope triple-run]: output diverged across runs" >&2
    fail=1
  fi
  local envelope="$e1"

  # v2 envelope shape
  assert_eq "$name schema_version" "2"            "$(echo "$envelope" | jq -r '."$schema_version"')"
  assert_eq "$name plugin"         "lintguini"    "$(echo "$envelope" | jq -r .plugin)"
  assert_eq "$name dimension"      "lint-posture" "$(echo "$envelope" | jq -r .dimension)"

  # Populated observations[]: 4 entries (linter, formatter, ci, suppression)
  assert_eq "$name observations count" "4" "$(echo "$envelope" | jq -r '.observations | length')"

  # Hard-asserted composite (locks the transitional math)
  local composite
  composite=$(echo "$envelope" | jq -r '.composite_score')
  assert_eq "$name composite_score" "$expected_composite" "$composite"

  # Pipe through the pronto helper — case-3 passthrough (no rubric
  # stanza for lint-posture yet) → passthrough_used: true.
  echo "$envelope" > "$ENV_FILE"
  local helper_out helper_exit
  helper_out="$("$HELPER" lint-posture "$ENV_FILE" 2>/dev/null)" && helper_exit=$? || helper_exit=$?
  if (( helper_exit != 0 )); then
    echo "FAIL [$name helper exit]: expected 0, got $helper_exit" >&2
    fail=1
  fi
  assert_eq "$name passthrough_used"  "true"       "$(echo "$helper_out" | jq -r .passthrough_used)"
  assert_eq "$name helper composite"  "$composite" "$(echo "$helper_out" | jq -r .composite_score)"

  echo "  $name: composite_score=$composite, passthrough_used=true"
}

# python-mid: regression bar. (50 + 100 + 100 + 95) / 4 = 86.
run_fixture python-mid     86

# ruby-mid: 3/5 cop departments * 100 = 60, then (60 + 100 + 100 + 95) / 4 = 88.75 → 89.
run_fixture ruby-mid       89

# typescript-mid: 2/6 (1 strict-flag + 1 biome) * 100 ≈ 33.33,
# then (33.33 + 100 + 100 + 95) / 4 ≈ 82.08 → 82.
run_fixture typescript-mid 82

if (( fail == 0 )); then
  echo "end-to-end.test.sh: PASS (3 fixtures: python/ruby/typescript)"
  exit 0
else
  echo "end-to-end.test.sh: FAIL" >&2
  exit 1
fi
