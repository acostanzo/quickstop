#!/usr/bin/env bash
# observations-to-score.test.sh — exhaustive shell tests for the
# observations-to-score translator helper.
#
# Run: ./observations-to-score.test.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER="$SCRIPT_DIR/observations-to-score.sh"

PASS=0
FAIL=0
FAILURES=()

# Build a controlled rubric stub so tests are independent of the real
# rubric.md. Every test gets the same stanza set; the test fixtures
# cover all four kinds, missing rules, and the weight-mode branches.
RUBRIC_FIXTURE="$(mktemp -t h4-test-rubric.XXXXXX.md)"
trap 'rm -f "$RUBRIC_FIXTURE"' EXIT

cat > "$RUBRIC_FIXTURE" <<'RUBRIC_EOF'
# Test rubric stub

## Observation translation rules

### `test-ratio-dim` translation rules

```json
{
  "observations": [
    {
      "id": "ratio-obs",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.80, "score": 100 },
        { "gte": 0.50, "score": 75 },
        { "gte": 0.20, "score": 50 },
        { "else": 25 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

### `test-count-dim` translation rules

```json
{
  "observations": [
    {
      "id": "count-obs",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 5, "score": 100 },
        { "gte": 3, "score": 75 },
        { "gte": 1, "score": 50 },
        { "else": 0 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

### `test-presence-dim` translation rules

```json
{
  "observations": [
    {
      "id": "presence-obs",
      "kind": "presence",
      "rule": "boolean",
      "present": 100,
      "absent": 30
    }
  ],
  "default_rule": "passthrough"
}
```

### `test-score-dim` translation rules

```json
{
  "observations": [
    {
      "id": "score-obs",
      "kind": "score",
      "rule": "passthrough"
    }
  ],
  "default_rule": "passthrough"
}
```

### `test-multi-dim` translation rules

```json
{
  "observations": [
    {
      "id": "ratio-a",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.5, "score": 80 },
        { "else": 40 }
      ]
    },
    {
      "id": "count-b",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 1, "score": 100 },
        { "else": 0 }
      ]
    },
    {
      "id": "presence-c",
      "kind": "presence",
      "rule": "boolean",
      "present": 90,
      "absent": 10
    },
    {
      "id": "score-d",
      "kind": "score",
      "rule": "passthrough"
    }
  ],
  "default_rule": "passthrough"
}
```

### `test-weighted-dim` translation rules

```json
{
  "observations": [
    {
      "id": "wa",
      "kind": "score",
      "rule": "passthrough",
      "weight": 0.75
    },
    {
      "id": "wb",
      "kind": "score",
      "rule": "passthrough",
      "weight": 0.25
    }
  ],
  "default_rule": "passthrough"
}
```

### `test-mixed-weight-dim` translation rules

```json
{
  "observations": [
    {
      "id": "ma",
      "kind": "score",
      "rule": "passthrough",
      "weight": 0.50
    },
    {
      "id": "mb",
      "kind": "score",
      "rule": "passthrough"
    }
  ],
  "default_rule": "passthrough"
}
```

### `test-unknown-kind-dim` translation rules

```json
{
  "observations": [
    {
      "id": "weird",
      "kind": "telepathy",
      "rule": "vibes"
    }
  ],
  "default_rule": "passthrough"
}
```

RUBRIC_EOF

export PRONTO_RUBRIC_PATH="$RUBRIC_FIXTURE"

# write_input <path> <json>
write_input() {
  local path="$1" body="$2"
  echo "$body" > "$path"
}

# expect_branch <name> <dimension> <input-json> <jq-expression> <expected-string>
# Run helper, parse stdout with jq, compare equal.
expect_branch() {
  local name="$1" dim="$2" body="$3" jq_expr="$4" expected="$5"
  local input out got
  input="$(mktemp -t h4-test-in.XXXXXX.json)"
  write_input "$input" "$body"
  if ! out="$("$HELPER" "$dim" "$input" 2>/dev/null)"; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: helper exited non-zero. Output: $out")
    rm -f "$input"
    return
  fi
  got="$(echo "$out" | jq -rc "$jq_expr")"
  if [[ "$got" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: jq '$jq_expr' expected='$expected' got='$got'")
  fi
  rm -f "$input"
}

# expect_exit <name> <dimension> <input-json> <expected-rc>
expect_exit() {
  local name="$1" dim="$2" body="$3" expected="$4"
  local input out rc
  input="$(mktemp -t h4-test-in.XXXXXX.json)"
  write_input "$input" "$body"
  out="$("$HELPER" "$dim" "$input" 2>&1)"
  rc=$?
  rm -f "$input"
  if (( rc == expected )); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: expected exit=$expected got=$rc out=$out")
  fi
}

# ----- ratio kind: band edges ------------------------------------------

expect_branch "ratio: top band (1.0)"  test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "ratio: top band edge (0.80)" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":0.80},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "ratio: just below top (0.79)" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":0.79},"summary":"x"}]}' \
  '.composite_score' '75'

expect_branch "ratio: middle band (0.50)" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":0.50},"summary":"x"}]}' \
  '.composite_score' '75'

expect_branch "ratio: lower band (0.30)" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":0.30},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "ratio: else (0.05)" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":0.05},"summary":"x"}]}' \
  '.composite_score' '25'

expect_branch "ratio: numerator/denominator form" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"numerator":1,"denominator":2},"summary":"x"}]}' \
  '.composite_score' '75'

# ----- count kind: ladder ----------------------------------------------

expect_branch "count: top (10)" test-count-dim \
  '{"$schema_version":2,"observations":[{"id":"count-obs","kind":"count","evidence":{"count":10},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "count: edge (5)" test-count-dim \
  '{"$schema_version":2,"observations":[{"id":"count-obs","kind":"count","evidence":{"count":5},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "count: middle (3)" test-count-dim \
  '{"$schema_version":2,"observations":[{"id":"count-obs","kind":"count","evidence":{"count":3},"summary":"x"}]}' \
  '.composite_score' '75'

expect_branch "count: middle (2)" test-count-dim \
  '{"$schema_version":2,"observations":[{"id":"count-obs","kind":"count","evidence":{"count":2},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "count: edge (1)" test-count-dim \
  '{"$schema_version":2,"observations":[{"id":"count-obs","kind":"count","evidence":{"count":1},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "count: zero (else)" test-count-dim \
  '{"$schema_version":2,"observations":[{"id":"count-obs","kind":"count","evidence":{"count":0},"summary":"x"}]}' \
  '.composite_score' '0'

expect_branch "count: domain-named field" test-count-dim \
  '{"$schema_version":2,"observations":[{"id":"count-obs","kind":"count","evidence":{"configured":3},"summary":"x"}]}' \
  '.composite_score' '75'

# ----- presence kind ---------------------------------------------------

expect_branch "presence: true" test-presence-dim \
  '{"$schema_version":2,"observations":[{"id":"presence-obs","kind":"presence","evidence":{"present":true},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "presence: false" test-presence-dim \
  '{"$schema_version":2,"observations":[{"id":"presence-obs","kind":"presence","evidence":{"present":false},"summary":"x"}]}' \
  '.composite_score' '30'

# ----- score kind (passthrough) ---------------------------------------

expect_branch "score: 87 passthrough" test-score-dim \
  '{"$schema_version":2,"observations":[{"id":"score-obs","kind":"score","evidence":{"score":87},"summary":"x"}]}' \
  '.composite_score' '87'

expect_branch "score: 0 passthrough" test-score-dim \
  '{"$schema_version":2,"observations":[{"id":"score-obs","kind":"score","evidence":{"score":0},"summary":"x"}]}' \
  '.composite_score' '0'

# ----- missing rule: drop + record ------------------------------------

expect_branch "missing rule: dropped recorded" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"},{"id":"unknown-id","kind":"ratio","evidence":{"ratio":0.5},"summary":"x"}]}' \
  '.dropped[0].id' 'unknown-id'

expect_branch "missing rule: dropped reason" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"},{"id":"unknown-id","kind":"ratio","evidence":{"ratio":0.5},"summary":"x"}]}' \
  '.dropped[0].reason' 'no rubric rule registered'

expect_branch "missing rule: scoring continues with remaining" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"},{"id":"unknown-id","kind":"ratio","evidence":{"ratio":0.5},"summary":"x"}]}' \
  '.composite_score' '100'

# ----- all-dropped: fall through to passthrough ----------------------

expect_branch "all dropped: passthrough used" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"unknown-id","kind":"ratio","evidence":{"ratio":0.5},"summary":"x"}],"composite_score":61}' \
  '.passthrough_used' 'true'

expect_branch "all dropped: composite from legacy" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"unknown-id","kind":"ratio","evidence":{"ratio":0.5},"summary":"x"}],"composite_score":61}' \
  '.composite_score' '61'

# ----- both observations[] and composite_score: prefers observations -

expect_branch "prefers observations over composite_score" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"}],"composite_score":42}' \
  '.composite_score' '100'

expect_branch "prefers observations: passthrough_used false" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"}],"composite_score":42}' \
  '.passthrough_used' 'false'

# ----- v1 payload: uses passthrough -----------------------------------

expect_branch "v1 payload: passthrough used" test-ratio-dim \
  '{"plugin":"sib","dimension":"x","categories":[],"composite_score":78}' \
  '.passthrough_used' 'true'

expect_branch "v1 payload: composite preserved" test-ratio-dim \
  '{"plugin":"sib","dimension":"x","categories":[],"composite_score":78}' \
  '.composite_score' '78'

expect_branch "v1 payload byte-equiv 0" test-ratio-dim \
  '{"plugin":"sib","dimension":"x","categories":[],"composite_score":0}' \
  '.composite_score' '0'

expect_branch "v1 payload byte-equiv 100" test-ratio-dim \
  '{"plugin":"sib","dimension":"x","categories":[],"composite_score":100}' \
  '.composite_score' '100'

# ----- equal-weight default: 1/2/4 obs --------------------------------

expect_branch "equal weight: 1 obs" test-score-dim \
  '{"$schema_version":2,"observations":[{"id":"score-obs","kind":"score","evidence":{"score":80},"summary":"x"}]}' \
  '.composite_score' '80'

expect_branch "equal weight: 2 obs (mean)" test-multi-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-a","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"},{"id":"count-b","kind":"count","evidence":{"count":1},"summary":"x"}]}' \
  '.composite_score' '90'

expect_branch "equal weight: 4 obs (mean)" test-multi-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-a","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"},{"id":"count-b","kind":"count","evidence":{"count":1},"summary":"x"},{"id":"presence-c","kind":"presence","evidence":{"present":true},"summary":"x"},{"id":"score-d","kind":"score","evidence":{"score":70},"summary":"x"}]}' \
  '.composite_score' '85'

# ----- explicit weights summing to 1.0 --------------------------------

expect_branch "explicit weights: 0.75 + 0.25" test-weighted-dim \
  '{"$schema_version":2,"observations":[{"id":"wa","kind":"score","evidence":{"score":100},"summary":"x"},{"id":"wb","kind":"score","evidence":{"score":0},"summary":"x"}]}' \
  '.composite_score' '75'

expect_branch "explicit weights: reversed" test-weighted-dim \
  '{"$schema_version":2,"observations":[{"id":"wa","kind":"score","evidence":{"score":0},"summary":"x"},{"id":"wb","kind":"score","evidence":{"score":100},"summary":"x"}]}' \
  '.composite_score' '25'

# ----- mixed weights: stanza loader rejects ---------------------------

expect_exit "mixed weights rejected" test-mixed-weight-dim \
  '{"$schema_version":2,"observations":[{"id":"ma","kind":"score","evidence":{"score":50},"summary":"x"},{"id":"mb","kind":"score","evidence":{"score":50},"summary":"x"}]}' \
  3

expect_exit "unknown kind rejected" test-unknown-kind-dim \
  '{"$schema_version":2,"observations":[{"id":"weird","kind":"telepathy","evidence":{},"summary":"x"}]}' \
  3

# ----- empty observations[] : passthrough -----------------------------

expect_branch "empty observations[]: passthrough" test-ratio-dim \
  '{"$schema_version":2,"observations":[],"composite_score":50}' \
  '.passthrough_used' 'true'

expect_branch "empty observations[]: composite preserved" test-ratio-dim \
  '{"$schema_version":2,"observations":[],"composite_score":50}' \
  '.composite_score' '50'

# ----- no composite_score either: null + passthrough_used ------------

expect_branch "no observations no composite: null score" test-ratio-dim \
  '{"plugin":"x","dimension":"y","categories":[]}' \
  '.composite_score' 'null'

expect_branch "no observations no composite: passthrough_used" test-ratio-dim \
  '{"plugin":"x","dimension":"y","categories":[]}' \
  '.passthrough_used' 'true'

# ----- output envelope shape ------------------------------------------

expect_branch "envelope has all keys" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"ratio","evidence":{"ratio":1.0},"summary":"x"}]}' \
  '[has("composite_score"), has("observations_applied"), has("passthrough_used"), has("dropped")] | all' \
  'true'

# ----- dim mismatch on observation kind: drop -----------------------

expect_branch "kind mismatch: dropped" test-ratio-dim \
  '{"$schema_version":2,"observations":[{"id":"ratio-obs","kind":"count","evidence":{"count":3},"summary":"x"}],"composite_score":99}' \
  '.dropped[0].id' 'ratio-obs'

# ----- summary --------------------------------------------------------

echo
echo "observations-to-score tests: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
  echo
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
