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

### `lint-posture` translation rules

```json
{
  "observations": [
    {
      "id": "linter-strictness-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "formatter-configured-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 1, "score": 100 },
        { "else": 0 }
      ]
    },
    {
      "id": "ci-lint-wired-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "lint-suppression-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 101, "score": 25 },
        { "gte": 51,  "score": 50 },
        { "gte": 21,  "score": 70 },
        { "gte": 6,   "score": 85 },
        { "gte": 1,   "score": 95 },
        { "else": 100 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

### `code-documentation` translation rules

```json
{
  "observations": [
    {
      "id": "readme-arrival-coverage",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "docs-coverage-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.95, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.30, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "docs-staleness-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 30, "score": 30 },
        { "gte": 10, "score": 60 },
        { "gte": 3,  "score": 85 },
        { "else": 100 }
      ]
    },
    {
      "id": "broken-internal-links-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 5, "score": 30 },
        { "gte": 2, "score": 60 },
        { "gte": 1, "score": 85 },
        { "else": 100 }
      ]
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

# ----- v1 payload: hard-error (deprecated 2026-04-28) -----------------
#
# Pre-deprecation, a v1-only envelope (no $schema_version) silently
# fell through to legacy `composite_score` passthrough. Post-deprecation,
# the translator hard-errors with exit 4. See phase-2-passthrough-
# deprecation.md for the rationale: every in-repo sibling shipped on
# v2 with M1/M2/M3, so v1-only payloads can no longer reach the
# translator from a current-build pronto path.

expect_exit "v1 payload: rejected (no \$schema_version)" test-ratio-dim \
  '{"plugin":"sib","dimension":"x","categories":[],"composite_score":78}' \
  4

expect_exit "v1 payload: rejected even when composite=0" test-ratio-dim \
  '{"plugin":"sib","dimension":"x","categories":[],"composite_score":0}' \
  4

expect_exit "v1 payload: rejected even when composite=100" test-ratio-dim \
  '{"plugin":"sib","dimension":"x","categories":[],"composite_score":100}' \
  4

expect_exit "v1 payload: rejected with no composite_score either" test-ratio-dim \
  '{"plugin":"x","dimension":"y","categories":[]}' \
  4

expect_exit "schema_version present but != 2: rejected" test-ratio-dim \
  '{"$schema_version":1,"composite_score":50}' \
  4

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

# ----- v2 envelope, no observations field, no composite: null + passthrough -

expect_branch "v2 no obs field no composite: null score" test-ratio-dim \
  '{"$schema_version":2}' \
  '.composite_score' 'null'

expect_branch "v2 no obs field no composite: passthrough_used" test-ratio-dim \
  '{"$schema_version":2}' \
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

# ----- lint-posture stanza coverage -----------------------------------
#
# The four-observation lint-posture shape lintguini emits in 2b3.
# Stub stanza (above in RUBRIC_FIXTURE) is byte-identical to the real
# stanza in plugins/pronto/references/rubric.md. If the two ever drift,
# this test stays green (it's testing against its own stub) but the
# lintguini snapshots.test.sh fails — surfacing the drift through the
# locked envelope.json round-trip.
#
# Per-observation band coverage (each observation tested in isolation
# against the lint-posture stanza), then four-observation composites
# verifying the calibration table from the 2b3 ticket.

# linter-strictness-ratio band edges
expect_branch "lint-posture linter: top (1.00)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "lint-posture linter: edge 0.80" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.80},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "lint-posture linter: edge 0.60" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.60},"summary":"x"}]}' \
  '.composite_score' '70'

expect_branch "lint-posture linter: edge 0.40" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.40},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "lint-posture linter: just below 0.40 (else)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.39},"summary":"x"}]}' \
  '.composite_score' '30'

# formatter-configured-count: boolean dressed as count
expect_branch "lint-posture formatter: configured 1" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"formatter-configured-count","kind":"count","evidence":{"configured":1},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "lint-posture formatter: configured 0" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"formatter-configured-count","kind":"count","evidence":{"configured":0},"summary":"x"}]}' \
  '.composite_score' '0'

# ci-lint-wired-ratio mirrors linter ladder; spot-check one in-band + one else.
expect_branch "lint-posture ci: 1.00" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"ci-lint-wired-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "lint-posture ci: 0.00 (else)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"ci-lint-wired-ratio","kind":"ratio","evidence":{"ratio":0.00},"summary":"x"}]}' \
  '.composite_score' '30'

# lint-suppression-count: six-band ladder from clean (0) to rotted (>100).
expect_branch "lint-posture supp: 0 (clean)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":0},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "lint-posture supp: 1 (occasional)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":1},"summary":"x"}]}' \
  '.composite_score' '95'

expect_branch "lint-posture supp: 6 (manageable)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":6},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "lint-posture supp: 21 (concerning)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":21},"summary":"x"}]}' \
  '.composite_score' '70'

expect_branch "lint-posture supp: 50 (still concerning, gte 21)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":50},"summary":"x"}]}' \
  '.composite_score' '70'

expect_branch "lint-posture supp: 51 (heavy)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":51},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "lint-posture supp: 100 (still heavy, gte 51)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":100},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "lint-posture supp: 101 (rotted)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":101},"summary":"x"}]}' \
  '.composite_score' '25'

# Four-observation composites — calibration table from the 2b3 ticket.
# python-mid: 0.50 / 1 / 1.00 / 2 -> 50, 100, 100, 95 -> mean 86.
expect_branch "lint-posture composite: python-mid (86)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.50},"summary":"x"},{"id":"formatter-configured-count","kind":"count","evidence":{"configured":1},"summary":"x"},{"id":"ci-lint-wired-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"},{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":2},"summary":"x"}]}' \
  '.composite_score' '86'

# ruby-mid: 0.60 / 1 / 1.00 / 2 -> 70, 100, 100, 95 -> mean 91.
expect_branch "lint-posture composite: ruby-mid (91)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.60},"summary":"x"},{"id":"formatter-configured-count","kind":"count","evidence":{"configured":1},"summary":"x"},{"id":"ci-lint-wired-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"},{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":2},"summary":"x"}]}' \
  '.composite_score' '91'

# typescript-mid: 0.33 / 1 / 1.00 / 2 -> 30, 100, 100, 95 -> mean 81.
expect_branch "lint-posture composite: typescript-mid (81)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.33},"summary":"x"},{"id":"formatter-configured-count","kind":"count","evidence":{"configured":1},"summary":"x"},{"id":"ci-lint-wired-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"},{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":2},"summary":"x"}]}' \
  '.composite_score' '81'

# python-low / ruby-low / typescript-low all land at 28 under the F-band shape.
# Pick python-low (linter ratio 0.25, formatter 0, ci 0.00, supp 60 -> 30/0/30/50 -> 28).
expect_branch "lint-posture composite: python-low (28)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":0.25},"summary":"x"},{"id":"formatter-configured-count","kind":"count","evidence":{"configured":0},"summary":"x"},{"id":"ci-lint-wired-ratio","kind":"ratio","evidence":{"ratio":0.00},"summary":"x"},{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":60},"summary":"x"}]}' \
  '.composite_score' '28'

# *-high: all signals at the top -> 100/100/100/100 -> 100.
expect_branch "lint-posture composite: *-high (100)" lint-posture \
  '{"$schema_version":2,"observations":[{"id":"linter-strictness-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"},{"id":"formatter-configured-count","kind":"count","evidence":{"configured":1},"summary":"x"},{"id":"ci-lint-wired-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"},{"id":"lint-suppression-count","kind":"count","evidence":{"suppressions":0},"summary":"x"}]}' \
  '.composite_score' '100'

# ----- code-documentation stanza coverage ------------------------------
#
# The four-observation code-documentation shape inkwell emits in 2a3.
# Stub stanza (above in RUBRIC_FIXTURE) is byte-identical to the real
# stanza in plugins/pronto/references/rubric.md. If the two ever drift,
# this test stays green (it's testing against its own stub) but the
# inkwell snapshots.test.sh fails — surfacing the drift through the
# locked envelope.json round-trip.
#
# Per-observation band coverage (each observation tested in isolation
# against the code-documentation stanza), then four-observation
# composites verifying the calibration table from the 2a3 ticket.

# readme-arrival-coverage band edges (0.40/0.60/0.80/1.00 ladder).
expect_branch "code-documentation readme: top (1.00)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "code-documentation readme: edge 0.80" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":0.80},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "code-documentation readme: edge 0.60" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":0.60},"summary":"x"}]}' \
  '.composite_score' '70'

expect_branch "code-documentation readme: edge 0.40" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":0.40},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "code-documentation readme: just below 0.40 (else)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":0.20},"summary":"x"}]}' \
  '.composite_score' '30'

# docs-coverage-ratio band edges (0.30/0.60/0.80/0.95 ladder — note
# the gte 0.95 top band is tighter than readme-arrival's gte 1.00).
expect_branch "code-documentation docs: top (1.00)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "code-documentation docs: edge 0.95" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.95},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "code-documentation docs: just below 0.95" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.94},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "code-documentation docs: edge 0.80" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.80},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "code-documentation docs: edge 0.60" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.60},"summary":"x"}]}' \
  '.composite_score' '70'

expect_branch "code-documentation docs: edge 0.30" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.30},"summary":"x"}]}' \
  '.composite_score' '50'

expect_branch "code-documentation docs: just below 0.30 (else)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.00},"summary":"x"}]}' \
  '.composite_score' '30'

# docs-staleness-count: four-band ladder (0 / 3 / 10 / 30).
expect_branch "code-documentation stale: 0 (clean else)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":0},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "code-documentation stale: 2 (still clean, else)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":2},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "code-documentation stale: 3 (forgivable)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":3},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "code-documentation stale: 9 (still forgivable, gte 3)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":9},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "code-documentation stale: 10 (concerning)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":10},"summary":"x"}]}' \
  '.composite_score' '60'

expect_branch "code-documentation stale: 29 (still concerning, gte 10)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":29},"summary":"x"}]}' \
  '.composite_score' '60'

expect_branch "code-documentation stale: 30 (rotted)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":30},"summary":"x"}]}' \
  '.composite_score' '30'

# broken-internal-links-count: four-band ladder (0 / 1 / 2 / 5).
expect_branch "code-documentation broken: 0 (clean else)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":0},"summary":"x"}]}' \
  '.composite_score' '100'

expect_branch "code-documentation broken: 1 (isolated)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":1},"summary":"x"}]}' \
  '.composite_score' '85'

expect_branch "code-documentation broken: 2 (maintenance)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":2},"summary":"x"}]}' \
  '.composite_score' '60'

expect_branch "code-documentation broken: 4 (still maintenance, gte 2)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":4},"summary":"x"}]}' \
  '.composite_score' '60'

expect_branch "code-documentation broken: 5 (rotted)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":5},"summary":"x"}]}' \
  '.composite_score' '30'

# Four-observation composites — calibration table from the 2a3 ticket.
# low: 0.20 / 0.00 / 18 / 4 -> 30, 30, 60, 60 -> mean 45.
expect_branch "code-documentation composite: low (45)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":0.20},"summary":"x"},{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.00},"summary":"x"},{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":18},"summary":"x"},{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":4},"summary":"x"}]}' \
  '.composite_score' '45'

# mid: 0.80 / 0.72 / 6 / 1 -> 85, 70, 85, 85 -> mean 81.25 round 81.
expect_branch "code-documentation composite: mid (81)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":0.80},"summary":"x"},{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.72},"summary":"x"},{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":6},"summary":"x"},{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":1},"summary":"x"}]}' \
  '.composite_score' '81'

# high: 1.00 / 0.95 / 0 / 0 -> 100, 100, 100, 100 -> mean 100.
expect_branch "code-documentation composite: high (100)" code-documentation \
  '{"$schema_version":2,"observations":[{"id":"readme-arrival-coverage","kind":"ratio","evidence":{"ratio":1.00},"summary":"x"},{"id":"docs-coverage-ratio","kind":"ratio","evidence":{"ratio":0.95},"summary":"x"},{"id":"docs-staleness-count","kind":"count","evidence":{"stale_files":0},"summary":"x"},{"id":"broken-internal-links-count","kind":"count","evidence":{"broken":0},"summary":"x"}]}' \
  '.composite_score' '100'

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
