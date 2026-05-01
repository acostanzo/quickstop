#!/usr/bin/env bash
# end-to-end.test.sh — exercises lintguini's full audit pipeline
# (orchestrator → translator) across the three first-class language
# paths shipped by 2b2 + 2b3.
#
# Runs build-envelope.sh against three fixtures:
#   - python-mid     (4 of 8 ruff rules + ruff format + wired CI + 2 # noqa)
#   - ruby-mid       (3 of 5 cop departments + rubocop autocorrect cops
#                     + wired CI + 2 rubocop:disable / todo)
#   - typescript-mid (1 of 6 ts strict bundle + biome formatter +
#                     wired CI + 2 @ts-ignore)
#
# Each envelope pipes through pronto's observations-to-score.sh helper
# for the lint-posture dimension. The helper applies the rubric stanza
# (added in 2b3) and emits the dimension score. Asserts:
#   - exits 0 (helper accepts the envelope shape)
#   - passthrough_used: false (rubric stanza now present; case-3 only
#     fires for empty observations[] which none of the mids have)
#   - composite_score matches the predicted value from the calibration
#     verification table in phase-2-2b3-lintguini-contract-fixtures.md
#
# Predicted composites (post-rubric-stanza):
#   python-mid     -> 86 (50 + 100 + 100 + 95) / 4
#   ruby-mid       -> 91 (70 + 100 + 100 + 95) / 4
#   typescript-mid -> 81 (30 + 100 + 100 + 95) / 4
#
# These are the three rubric-derived composites — different from the
# pre-2b3 transitional inline-math composites (86 / 89 / 82) because
# the ladder is non-linear at the band boundaries. None cross a
# letter-grade boundary on the calibration set.

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

  # composite_score in the envelope is null — the orchestrator delegates
  # scoring to the rubric stanza. Asserting null here locks the
  # post-2b3-excision contract; if the orchestrator ever re-introduces
  # inline scoring math, this assertion catches it.
  assert_eq "$name envelope composite_score" "null" "$(echo "$envelope" | jq -r '.composite_score')"

  # Pipe through the pronto helper. Rubric stanza is now in place, so
  # case-3 passthrough does NOT fire — the helper computes the
  # composite from observations[] against the lint-posture stanza.
  echo "$envelope" > "$ENV_FILE"
  local helper_out helper_exit
  helper_out="$("$HELPER" lint-posture "$ENV_FILE" 2>/dev/null)" && helper_exit=$? || helper_exit=$?
  if (( helper_exit != 0 )); then
    echo "FAIL [$name helper exit]: expected 0, got $helper_exit" >&2
    fail=1
  fi
  assert_eq "$name passthrough_used" "false"               "$(echo "$helper_out" | jq -r .passthrough_used)"
  assert_eq "$name helper composite" "$expected_composite" "$(echo "$helper_out" | jq -r .composite_score)"

  echo "  $name: rubric composite_score=$expected_composite, passthrough_used=false"
}

# python-mid: ratio 0.50 -> band gte 0.40 = 50; (50 + 100 + 100 + 95) / 4 = 86.
run_fixture python-mid     86

# ruby-mid: ratio 0.60 -> band gte 0.60 = 70; (70 + 100 + 100 + 95) / 4 = 91.
run_fixture ruby-mid       91

# typescript-mid: ratio 0.33 -> else band 30; (30 + 100 + 100 + 95) / 4 = 81.
run_fixture typescript-mid 81

if (( fail == 0 )); then
  echo "end-to-end.test.sh: PASS (3 fixtures: python/ruby/typescript)"
  exit 0
else
  echo "end-to-end.test.sh: FAIL" >&2
  exit 1
fi
