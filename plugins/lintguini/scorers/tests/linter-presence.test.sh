#!/usr/bin/env bash
# linter-presence.test.sh — exercise score-linter-presence.sh against
# six fixtures (python strict / loose, js+biome, rust, go, empty).
# Each fixture is triple-run to verify byte-equivalent output across
# runs (the determinism invariant from the 2b2 ticket).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-linter-presence.sh"
FIXTURES="$HERE/fixtures/linter-presence"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

triple_run() {
  local fixture="$1"
  local r1 r2 r3
  r1=$("$SCORER" "$fixture")
  r2=$("$SCORER" "$fixture")
  r3=$("$SCORER" "$fixture")
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [$(basename "$fixture")]: triple-run output diverged" >&2
    echo "  r1=$r1" >&2
    echo "  r2=$r2" >&2
    echo "  r3=$r3" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

# ---- python-strict: ruff with all 8 baseline rules → ratio 1.0
out=$(triple_run "$FIXTURES/python-strict")
assert_eq "python-strict id"        "linter-strictness-ratio" "$(echo "$out" | jq -r .id)"
assert_eq "python-strict kind"      "ratio"                   "$(echo "$out" | jq -r .kind)"
assert_eq "python-strict language"  "python"                  "$(echo "$out" | jq -r .evidence.language)"
assert_eq "python-strict configured" "8"                      "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "python-strict baseline"  "8"                       "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "python-strict ratio"     "1.0000"                  "$(echo "$out" | jq -r .evidence.ratio)"

# ---- python-loose: ruff with 4 of 8 → ratio 0.5
out=$(triple_run "$FIXTURES/python-loose")
assert_eq "python-loose configured" "4"      "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "python-loose ratio"      "0.5000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- js-biome: package.json + biome.json with recommended:true → 1/1
out=$(triple_run "$FIXTURES/js-biome")
assert_eq "js-biome language"    "javascript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "js-biome configured"  "1"          "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "js-biome baseline"    "1"          "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "js-biome ratio"       "1.0000"     "$(echo "$out" | jq -r .evidence.ratio)"

# ---- ts-strict: tsconfig.json (strict bundle + noUncheckedIndexedAccess)
#                 + eslint.config.js (with @typescript-eslint plugin) → 6/6
# strict-bundle = 4 strict-flags (capped at 4); + 1 @typescript-eslint plugin
# + 1 eslint config detected via the JS_BASE branch.
out=$(triple_run "$FIXTURES/ts-strict")
assert_eq "ts-strict language"    "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-strict configured"  "6"          "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "ts-strict baseline"    "6"          "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "ts-strict ratio"       "1.0000"     "$(echo "$out" | jq -r .evidence.ratio)"

# ---- ts-loose: tsconfig.json with one strict flag, no eslint, no biome → 1/6
out=$(triple_run "$FIXTURES/ts-loose")
assert_eq "ts-loose language"    "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-loose configured"  "1"          "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "ts-loose baseline"    "6"          "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "ts-loose ratio"       "0.1667"     "$(echo "$out" | jq -r .evidence.ratio)"

# ---- rust: Cargo.toml with [lints.rust] + [lints.clippy] each one entry → 2/2
out=$(triple_run "$FIXTURES/rust")
assert_eq "rust language"   "rust"   "$(echo "$out" | jq -r .evidence.language)"
assert_eq "rust configured" "2"      "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "rust baseline"   "2"      "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "rust ratio"      "1.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- go: go.mod + .golangci.yml with 6 enabled linters → 6/6
out=$(triple_run "$FIXTURES/go")
assert_eq "go language"   "go"     "$(echo "$out" | jq -r .evidence.language)"
assert_eq "go configured" "6"      "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "go baseline"   "6"      "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "go ratio"      "1.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- ruby-strict: Gemfile + .rubocop.yml mentioning all 5 cop departments
# (Style, Layout, Lint, Metrics, Naming) → 5/5
out=$(triple_run "$FIXTURES/ruby-strict")
assert_eq "ruby-strict language"   "ruby"   "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ruby-strict configured" "5"      "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "ruby-strict baseline"   "5"      "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "ruby-strict ratio"      "1.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- ruby-loose: Gemfile + .rubocop.yml mentioning 1 department only → 1/5
out=$(triple_run "$FIXTURES/ruby-loose")
assert_eq "ruby-loose configured" "1"      "$(echo "$out" | jq -r .evidence.configured_rules)"
assert_eq "ruby-loose baseline"   "5"      "$(echo "$out" | jq -r .evidence.baseline_rules)"
assert_eq "ruby-loose ratio"      "0.2000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- empty: no language config → empty stdout (observation omitted)
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "linter-presence.test.sh: PASS"
  exit 0
else
  echo "linter-presence.test.sh: FAIL" >&2
  exit 1
fi
