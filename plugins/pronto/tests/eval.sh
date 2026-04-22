#!/usr/bin/env bash
# Pronto audit determinism harness.
#
# Runs /pronto:audit --json N times against a pinned fixture worktree and
# reports variance statistics (composite mean/stddev/min/max, grade
# distribution and flip rate, per-dimension mean/stddev).
#
# This is the measurement layer. It does not enforce pass/fail thresholds —
# threshold enforcement is PR 3b's concern. Exit codes indicate execution
# success, not variance quality.
#
# Exit codes:
#   0  all runs completed and results written
#   2  fixture lookup / worktree setup failed
#   3  one or more audit invocations failed (partial results still written)
#   4  jq / aggregation failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FIXTURES_FILE="$SCRIPT_DIR/fixtures.json"

FIXTURE_NAME="mid"
N=10
OUTPUT="$SCRIPT_DIR/eval-results.json"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--fixture <name>] [--n <int>] [--output <path>]

Options:
  --fixture <name>   Fixture entry in fixtures.json (default: mid)
  --n <int>          Number of audit runs (default: 10)
  --output <path>    Path to write eval-results.json
                     (default: $SCRIPT_DIR/eval-results.json)
  -h, --help         Show this help and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture) FIXTURE_NAME="${2:-}"; shift 2 ;;
    --n)       N="${2:-}"; shift 2 ;;
    --output)  OUTPUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if ! [[ "$N" =~ ^[0-9]+$ ]] || [[ "$N" -lt 1 ]]; then
  echo "Error: --n must be a positive integer (got: $N)" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not found on PATH" >&2
  exit 4
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Error: claude CLI is required but not found on PATH" >&2
  exit 2
fi

if [[ ! -f "$FIXTURES_FILE" ]]; then
  echo "Error: fixtures.json not found at $FIXTURES_FILE" >&2
  exit 2
fi

FIXTURE_ENTRY=$(jq -c --arg n "$FIXTURE_NAME" '.fixtures[$n] // empty' "$FIXTURES_FILE")
if [[ -z "$FIXTURE_ENTRY" ]]; then
  echo "Error: fixture '$FIXTURE_NAME' not found in $FIXTURES_FILE" >&2
  exit 2
fi

FIXTURE_REPO_REL=$(echo "$FIXTURE_ENTRY" | jq -r '.repo')
FIXTURE_SHA=$(echo "$FIXTURE_ENTRY" | jq -r '.sha')
FIXTURE_DESC=$(echo "$FIXTURE_ENTRY" | jq -r '.description // ""')

if [[ -z "$FIXTURE_SHA" || "$FIXTURE_SHA" == "null" ]]; then
  echo "Error: fixture '$FIXTURE_NAME' has no pinned sha" >&2
  exit 2
fi

if [[ "$FIXTURE_REPO_REL" == "." ]]; then
  FIXTURE_REPO="$REPO_ROOT"
elif [[ "$FIXTURE_REPO_REL" = /* ]]; then
  FIXTURE_REPO="$FIXTURE_REPO_REL"
else
  FIXTURE_REPO="$REPO_ROOT/$FIXTURE_REPO_REL"
fi

if ! git -C "$FIXTURE_REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: fixture repo '$FIXTURE_REPO' is not a git repository" >&2
  exit 2
fi

if ! git -C "$FIXTURE_REPO" cat-file -e "$FIXTURE_SHA^{commit}" 2>/dev/null; then
  echo "Error: fixture sha '$FIXTURE_SHA' not found in $FIXTURE_REPO" >&2
  exit 2
fi

WORKTREE="/tmp/pronto-eval-fixture-${FIXTURE_NAME}-$$"
RUNS_DIR="$(mktemp -d -t pronto-eval-runs.XXXXXX)"

cleanup() {
  local rc=$?
  if [[ -d "$WORKTREE" ]]; then
    git -C "$FIXTURE_REPO" worktree remove --force "$WORKTREE" >/dev/null 2>&1 \
      || rm -rf "$WORKTREE"
  fi
  git -C "$FIXTURE_REPO" worktree prune >/dev/null 2>&1 || true
  if [[ -n "${RUNS_DIR:-}" && -d "$RUNS_DIR" ]]; then
    rm -rf "$RUNS_DIR"
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM HUP

echo "Fixture: $FIXTURE_NAME (repo=$FIXTURE_REPO, sha=${FIXTURE_SHA:0:7})" >&2
echo "Creating worktree at $WORKTREE..." >&2
if ! git -C "$FIXTURE_REPO" worktree add --detach "$WORKTREE" "$FIXTURE_SHA" >&2; then
  echo "Error: failed to create fixture worktree" >&2
  exit 2
fi

PLUGIN_DIRS=(pronto avanti claudit skillet commventional)
PLUGIN_ARGS=()
for p in "${PLUGIN_DIRS[@]}"; do
  if [[ -d "$REPO_ROOT/plugins/$p" ]]; then
    PLUGIN_ARGS+=(--plugin-dir "$REPO_ROOT/plugins/$p")
  fi
done

echo "Plan: $N runs of '/pronto:audit --json' against fixture worktree" >&2
echo "Plugins loaded from: $REPO_ROOT/plugins/{$(IFS=,; echo "${PLUGIN_DIRS[*]}")}" >&2
echo >&2

START_TS=$(date +%s)
FAILED_RUNS=0
SUCCESS_RUNS=0
RUN_JSON_FILES=()

for ((i=1; i<=N; i++)); do
  run_stdout="$RUNS_DIR/run-$i.stdout"
  run_stderr="$RUNS_DIR/run-$i.stderr"
  run_normalized="$RUNS_DIR/run-$i.normalized.json"
  printf '[run %d/%d] invoking /pronto:audit --json...' "$i" "$N" >&2
  run_start=$(date +%s)
  if (cd "$WORKTREE" && claude -p "/pronto:audit --json" \
        --dangerously-skip-permissions \
        "${PLUGIN_ARGS[@]}" \
        >"$run_stdout" 2>"$run_stderr"); then
    run_rc=0
  else
    run_rc=$?
  fi
  run_end=$(date +%s)
  run_dur=$((run_end - run_start))

  if [[ "$run_rc" -ne 0 ]]; then
    printf ' FAIL (exit %d, %ds)\n' "$run_rc" "$run_dur" >&2
    FAILED_RUNS=$((FAILED_RUNS+1))
    continue
  fi

  if ! jq -e . "$run_stdout" >/dev/null 2>&1; then
    printf ' FAIL (non-JSON stdout, %ds)\n' "$run_dur" >&2
    FAILED_RUNS=$((FAILED_RUNS+1))
    continue
  fi

  if ! jq -c '{
      composite: (.composite_score // null),
      grade:     (.composite_grade // null),
      dimensions: ([.dimensions[]? | {(.dimension): .score}] | add // {})
    }' "$run_stdout" > "$run_normalized" 2>/dev/null; then
    printf ' FAIL (jq normalize, %ds)\n' "$run_dur" >&2
    FAILED_RUNS=$((FAILED_RUNS+1))
    continue
  fi

  # Contract check: a valid audit run must carry a numeric composite, a
  # letter grade, and at least one dimension score. Runs that parse as JSON
  # but violate the contract (e.g. sub-Claude emitted a stub) are not
  # aggregated — they skew means toward hallucinated values.
  contract_violation=$(jq -r '
      def grade_re: "^(A\\+|[ABCDF])$";
      [
        (if (.composite | type) != "number" then "composite-not-number" else empty end),
        (if (.grade // null) == null then "grade-missing"
         elif ((.grade | test(grade_re)) | not) then "grade-malformed"
         else empty end),
        (if (.dimensions | length) == 0 then "dimensions-empty" else empty end)
      ] | join(",")
    ' "$run_normalized")

  if [[ -n "$contract_violation" ]]; then
    composite=$(jq -r '.composite // "?"' "$run_normalized")
    grade=$(jq -r '.grade // "?"' "$run_normalized")
    dimcount=$(jq -r '.dimensions | length' "$run_normalized")
    printf ' FAIL (contract: %s; composite=%s grade=%s dims=%s, %ds)\n' \
      "$contract_violation" "$composite" "$grade" "$dimcount" "$run_dur" >&2
    FAILED_RUNS=$((FAILED_RUNS+1))
    continue
  fi

  composite=$(jq -r '.composite' "$run_normalized")
  grade=$(jq -r '.grade' "$run_normalized")
  printf ' ok (composite=%s grade=%s, %ds)\n' "$composite" "$grade" "$run_dur" >&2
  RUN_JSON_FILES+=("$run_normalized")
  SUCCESS_RUNS=$((SUCCESS_RUNS+1))
done

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

format_dur() {
  local s=$1
  if [[ "$s" -ge 60 ]]; then
    printf '%dm %ds' $((s/60)) $((s%60))
  else
    printf '%ds' "$s"
  fi
}

echo >&2

if [[ "$SUCCESS_RUNS" -eq 0 ]]; then
  echo "All $N runs failed — no aggregation possible." >&2
  # Write a minimal results file capturing the failure.
  cat >"$OUTPUT" <<EOF
{
  "fixture": "$FIXTURE_NAME",
  "fixture_sha": "$FIXTURE_SHA",
  "fixture_description": $(printf '%s' "$FIXTURE_DESC" | jq -Rs .),
  "n": $N,
  "n_success": 0,
  "n_failed": $FAILED_RUNS,
  "duration_seconds": $DURATION,
  "runs": [],
  "aggregates": null
}
EOF
  exit 3
fi

# Combine normalized run files into a single JSON array.
ALL_RUNS="$RUNS_DIR/all.json"
if ! jq -s '.' "${RUN_JSON_FILES[@]}" > "$ALL_RUNS"; then
  echo "Error: failed to combine run files" >&2
  exit 4
fi

# Build aggregates with jq.
AGG_FILE="$RUNS_DIR/aggregates.json"
if ! jq '
    def mean:        (add / length);
    def stddev:      (. as $xs | ($xs | mean) as $mu
                       | [$xs[] | (. - $mu) | . * .] | (add / length) | sqrt);
    def round1:      (. * 10 | floor / 10);
    def round3:      (. * 1000 | floor / 1000);

    . as $runs
    | ($runs | map(.composite // null) | map(select(. != null))) as $comps
    | ($runs | map(.grade // null) | map(select(. != null))) as $grades
    | ([$runs[].dimensions | keys[]] | unique) as $dimkeys
    | (reduce $grades[] as $g ({}; .[$g] = ((.[$g] // 0) + 1))) as $gdist
    | ( if ($gdist | length) == 0 then null
        else ($gdist | to_entries | max_by(.value) | .key) end ) as $mode
    | (if $mode == null or ($grades | length) == 0 then 0
       else ($grades | map(select(. != $mode)) | length) / ($grades | length)
       end) as $flip
    | {
        composite: (
          if ($comps | length) == 0 then null
          else {
            mean:   ($comps | mean | round1),
            stddev: ($comps | stddev | round3),
            min:    ($comps | min),
            max:    ($comps | max)
          } end
        ),
        grades: (
          $gdist + { mode: $mode, flip_rate: ($flip | round3) }
        ),
        dimensions: (
          [ $dimkeys[] as $k
            | ($runs | map(.dimensions[$k] // null) | map(select(. != null))) as $vs
            | if ($vs | length) == 0 then empty
              else { ($k): {
                  n:      ($vs | length),
                  mean:   ($vs | mean | round1),
                  stddev: ($vs | stddev | round3),
                  min:    ($vs | min),
                  max:    ($vs | max)
              } } end
          ] | add // {}
        )
      }
  ' "$ALL_RUNS" > "$AGG_FILE"; then
  echo "Error: jq aggregation failed" >&2
  exit 4
fi

# Assemble final results JSON.
if ! jq \
    --arg fixture "$FIXTURE_NAME" \
    --arg sha "$FIXTURE_SHA" \
    --arg desc "$FIXTURE_DESC" \
    --argjson n "$N" \
    --argjson n_success "$SUCCESS_RUNS" \
    --argjson n_failed "$FAILED_RUNS" \
    --argjson dur "$DURATION" \
    --slurpfile runs "$ALL_RUNS" \
    '{
      fixture: $fixture,
      fixture_sha: $sha,
      fixture_description: $desc,
      n: $n,
      n_success: $n_success,
      n_failed: $n_failed,
      duration_seconds: $dur,
      runs: $runs[0],
      aggregates: .
    }' \
    "$AGG_FILE" > "$OUTPUT"; then
  echo "Error: failed to write $OUTPUT" >&2
  exit 4
fi

# Human-readable summary to stdout.
{
  echo "Fixture: $FIXTURE_NAME (repo=$(basename "$FIXTURE_REPO")@${FIXTURE_SHA:0:7})"
  if [[ -n "$FIXTURE_DESC" ]]; then
    echo "  $FIXTURE_DESC"
  fi
  echo "Runs: $SUCCESS_RUNS successful, $FAILED_RUNS failed (of $N total)"
  echo "Duration: $(format_dur "$DURATION")"
  echo

  # Composite
  comp_mean=$(jq -r '.composite.mean   // "n/a"' "$AGG_FILE")
  comp_sd=$(  jq -r '.composite.stddev // "n/a"' "$AGG_FILE")
  comp_min=$( jq -r '.composite.min    // "n/a"' "$AGG_FILE")
  comp_max=$( jq -r '.composite.max    // "n/a"' "$AGG_FILE")
  printf 'Composite: mean=%s  stddev=%s  min=%s  max=%s\n' \
    "$comp_mean" "$comp_sd" "$comp_min" "$comp_max"

  # Grade distribution
  grade_line=$(jq -r '
      .grades as $g
      | ($g | del(.mode, .flip_rate)) as $dist
      | ($g.flip_rate // 0) as $fr
      | ($dist | to_entries | sort_by(.key) | map("\(.key)×\(.value)") | join(" ")) as $d
      | "Grade distribution: \($d)  (flip rate \(($fr * 100) | floor)%)"
    ' "$AGG_FILE")
  echo "$grade_line"
  echo

  # Per-dimension
  echo "Per-dimension:"
  jq -r '
      .dimensions
      | to_entries
      | sort_by(.key)
      | .[]
      | "  \(.key)\t mean=\(.value.mean)\tstddev=\(.value.stddev)\tmin=\(.value.min)\tmax=\(.value.max)"
    ' "$AGG_FILE" | column -t -s $'\t'
  echo
  echo "Results written to $OUTPUT"
} <"$AGG_FILE"

if [[ "$FAILED_RUNS" -gt 0 ]]; then
  echo >&2
  echo "Warning: $FAILED_RUNS of $N runs failed — results reflect only successful runs." >&2
  exit 3
fi

exit 0
