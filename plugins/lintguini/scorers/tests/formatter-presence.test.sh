#!/usr/bin/env bash
# formatter-presence.test.sh — exercise score-formatter-presence.sh
# against per-language formatted/unformatted fixtures + go (implicit)
# + empty. Triple-runs each for byte-equivalence.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-formatter-presence.sh"
FIXTURES="$HERE/fixtures/formatter-presence"
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
    fail=1
  fi
  printf '%s' "$r1"
}

# python-formatted: [tool.ruff.format] → configured=1
out=$(triple_run "$FIXTURES/python-formatted")
assert_eq "python-formatted id"         "formatter-configured-count" "$(echo "$out" | jq -r .id)"
assert_eq "python-formatted kind"       "count"                      "$(echo "$out" | jq -r .kind)"
assert_eq "python-formatted language"   "python"                     "$(echo "$out" | jq -r .evidence.language)"
assert_eq "python-formatted configured" "1"                          "$(echo "$out" | jq -r .evidence.configured)"

# python-unformatted: [tool.ruff.lint] only → configured=0
out=$(triple_run "$FIXTURES/python-unformatted")
assert_eq "python-unformatted configured" "0" "$(echo "$out" | jq -r .evidence.configured)"

# js-biome-formatted
out=$(triple_run "$FIXTURES/js-biome-formatted")
assert_eq "js-biome-formatted language"   "javascript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "js-biome-formatted configured" "1"          "$(echo "$out" | jq -r .evidence.configured)"

# js-prettier: .prettierrc fallback
out=$(triple_run "$FIXTURES/js-prettier")
assert_eq "js-prettier configured" "1" "$(echo "$out" | jq -r .evidence.configured)"

# js-unformatted: package.json only
out=$(triple_run "$FIXTURES/js-unformatted")
assert_eq "js-unformatted configured" "0" "$(echo "$out" | jq -r .evidence.configured)"

# ts-formatted: tsconfig.json + biome.json with formatter.enabled=true → configured=1
# Verifies the JS/TS dispatch split surfaces language=typescript correctly.
out=$(triple_run "$FIXTURES/ts-formatted")
assert_eq "ts-formatted language"   "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-formatted configured" "1"          "$(echo "$out" | jq -r .evidence.configured)"

# ts-unformatted: tsconfig.json + package.json (no biome, no prettier) → configured=0
out=$(triple_run "$FIXTURES/ts-unformatted")
assert_eq "ts-unformatted language"   "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-unformatted configured" "0"          "$(echo "$out" | jq -r .evidence.configured)"

# rust-formatted: rustfmt.toml present
out=$(triple_run "$FIXTURES/rust-formatted")
assert_eq "rust-formatted configured" "1" "$(echo "$out" | jq -r .evidence.configured)"

# rust-unformatted: Cargo.toml only
out=$(triple_run "$FIXTURES/rust-unformatted")
assert_eq "rust-unformatted configured" "0" "$(echo "$out" | jq -r .evidence.configured)"

# go: go.mod present → implicit gofmt
out=$(triple_run "$FIXTURES/go")
assert_eq "go language"   "go" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "go configured" "1"  "$(echo "$out" | jq -r .evidence.configured)"

# ruby-formatted: Gemfile + .rubocop.yml with Layout/Style cops → configured=1
out=$(triple_run "$FIXTURES/ruby-formatted")
assert_eq "ruby-formatted language"   "ruby" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ruby-formatted configured" "1"    "$(echo "$out" | jq -r .evidence.configured)"

# ruby-unformatted: Gemfile only (no .rubocop.yml, no standard.yml, no .rufo) → configured=0
out=$(triple_run "$FIXTURES/ruby-unformatted")
assert_eq "ruby-unformatted language"   "ruby" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ruby-unformatted configured" "0"    "$(echo "$out" | jq -r .evidence.configured)"

# empty: no language → no observation
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "formatter-presence.test.sh: PASS"
  exit 0
else
  echo "formatter-presence.test.sh: FAIL" >&2
  exit 1
fi
