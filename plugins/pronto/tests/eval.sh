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

# Expected rubric dimensions — the 8 dims pronto's audit must emit for a
# run to be contract-compliant. Source of truth:
#   plugins/pronto/references/rubric.md        (dimension rows)
#   plugins/pronto/references/report-format.md (JSON dimensions[] shape)
# Hardcoded (not dynamically discovered) so the harness does not drift
# silently if the rubric gains or loses a dimension — any change should
# be a deliberate edit here, paired with updates to the references above.
EXPECTED_DIMS=(
  agents-md
  claude-code-config
  code-documentation
  commit-hygiene
  event-emission
  lint-posture
  project-record
  skills-quality
)
EXPECTED_DIMS_CSV=$(IFS=,; echo "${EXPECTED_DIMS[*]}")

CATEGORIZE_HELPER="$SCRIPT_DIR/eval-categorize.sh"

FIXTURE_NAME="mid"
N=10
OUTPUT="$SCRIPT_DIR/eval-results.json"
# Default model alias. Pinned so failure-rate measurements across runs
# are comparable — without a pin every run is implicitly "current CLI
# default model", and a silent default bump between baseline and
# verification would confound the H2b acceptance bar.
EVAL_MODEL="${EVAL_MODEL:-sonnet}"
# Optional durable destination for per-run artefacts. When empty, runs
# go to a mktemp dir that's deleted on exit (matches prior behaviour).
PRESERVE_RUNS="${EVAL_PRESERVE_RUNS:-}"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--fixture <name>] [--n <int>] [--output <path>]
                        [--model <name>] [--preserve-runs <dir>]

Options:
  --fixture <name>        Fixture entry in fixtures.json (default: mid)
  --n <int>               Number of audit runs (default: 10)
  --output <path>         Path to write eval-results.json
                          (default: $SCRIPT_DIR/eval-results.json)
  --model <name>          Claude model alias passed to claude -p
                          (default: $EVAL_MODEL; override via EVAL_MODEL)
  --preserve-runs <dir>   Keep per-run artefacts (stdout, stderr,
                          meta.json, normalized JSON, aggregates) in
                          this directory instead of deleting them.
                          Override via EVAL_PRESERVE_RUNS.
  -h, --help              Show this help and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture)        FIXTURE_NAME="${2:-}"; shift 2 ;;
    --n)              N="${2:-}"; shift 2 ;;
    --output)         OUTPUT="${2:-}"; shift 2 ;;
    --model)          EVAL_MODEL="${2:-}"; shift 2 ;;
    --preserve-runs)  PRESERVE_RUNS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$EVAL_MODEL" ]]; then
  echo "Error: --model must be non-empty (got empty string)" >&2
  exit 2
fi

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

if [[ ! -x "$CATEGORIZE_HELPER" ]]; then
  echo "Error: categorize helper not found or not executable: $CATEGORIZE_HELPER" >&2
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
if [[ -n "$PRESERVE_RUNS" ]]; then
  mkdir -p "$PRESERVE_RUNS"
  RUNS_DIR="$PRESERVE_RUNS"
else
  RUNS_DIR="$(mktemp -d -t pronto-eval-runs.XXXXXX)"
fi

cleanup() {
  local rc=$?
  if [[ -d "$WORKTREE" ]]; then
    git -C "$FIXTURE_REPO" worktree remove --force "$WORKTREE" >/dev/null 2>&1 \
      || rm -rf "$WORKTREE"
  fi
  git -C "$FIXTURE_REPO" worktree prune >/dev/null 2>&1 || true
  if [[ -n "${RUNS_DIR:-}" && -d "$RUNS_DIR" ]]; then
    if [[ -n "$PRESERVE_RUNS" ]]; then
      echo "Per-run artefacts preserved at: $RUNS_DIR" >&2
    else
      rm -rf "$RUNS_DIR"
    fi
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

PLUGIN_DIRS=(pronto avanti claudit skillet commventional inkwell lintguini towncrier)
PLUGIN_ARGS=()
for p in "${PLUGIN_DIRS[@]}"; do
  if [[ -d "$REPO_ROOT/plugins/$p" ]]; then
    PLUGIN_ARGS+=(--plugin-dir "$REPO_ROOT/plugins/$p")
  fi
done

echo "Plan: $N runs of '/pronto:audit --json' against fixture worktree" >&2
echo "Plugins loaded from: $REPO_ROOT/plugins/{$(IFS=,; echo "${PLUGIN_DIRS[*]}")}" >&2
echo "Model: $EVAL_MODEL" >&2
echo "Runs dir: $RUNS_DIR" >&2
echo >&2

START_TS=$(date +%s)
FAILED_RUNS=0
SUCCESS_RUNS=0
RUN_JSON_FILES=()

# write_meta — emit per-run meta.json. Always called once per run, success
# or failure, so post-hoc analysis sees a complete picture without needing
# to cross-reference stdout files. Failure runs carry an embedded
# `failure` object from the categorize helper; success runs carry the
# composite/grade pair.
write_meta() {
  local meta_file="$1" run_index="$2" exit_code="$3" duration="$4" outcome="$5"
  local extra_args=("${@:6}")
  jq -n \
    --argjson run "$run_index" \
    --arg model "$EVAL_MODEL" \
    --argjson exit_code "$exit_code" \
    --argjson dur "$duration" \
    --arg outcome "$outcome" \
    --arg stdout_rel "run-$run_index.stdout" \
    --arg stderr_rel "run-$run_index.stderr" \
    "${extra_args[@]}" \
    '{
       run: $run,
       model: $model,
       exit_code: $exit_code,
       duration_seconds: $dur,
       outcome: $outcome,
       stdout_path: $stdout_rel,
       stderr_path: $stderr_rel
     } + $extra' \
    > "$meta_file"
}

for ((i=1; i<=N; i++)); do
  run_stdout="$RUNS_DIR/run-$i.stdout"
  run_stderr="$RUNS_DIR/run-$i.stderr"
  run_normalized="$RUNS_DIR/run-$i.normalized.json"
  run_meta="$RUNS_DIR/run-$i.meta.json"
  printf '[run %d/%d] invoking /pronto:audit --json...' "$i" "$N" >&2
  run_start=$(date +%s)
  if (cd "$WORKTREE" && claude -p "/pronto:audit --json" \
        --model "$EVAL_MODEL" \
        --dangerously-skip-permissions \
        "${PLUGIN_ARGS[@]}" \
        >"$run_stdout" 2>"$run_stderr"); then
    run_rc=0
  else
    run_rc=$?
  fi
  run_end=$(date +%s)
  run_dur=$((run_end - run_start))

  # Failure detection ladder. Each rung short-circuits to the categorize
  # block below; the categorize helper assigns the operator-facing
  # bucket (prose-contamination, partial-emission, refusal-or-empty,
  # contract-violation, exit-nonzero, other).
  outcome="success"
  contract_violation=""

  if (( run_rc != 0 )); then
    outcome="failure"
  elif ! jq -e . "$run_stdout" >/dev/null 2>&1; then
    outcome="failure"
  elif ! jq -c '{
      composite: (.composite_score // null),
      grade:     (.composite_grade // null),
      dimensions: ([.dimensions[]? | {(.dimension): .score}] | add // {})
    }' "$run_stdout" > "$run_normalized" 2>/dev/null; then
    outcome="failure"
  else
    # Contract check: a valid audit run must carry a numeric composite, a
    # letter grade, and every expected rubric dimension. Runs that parse
    # as JSON but violate the contract (e.g. sub-Claude emitted a stub,
    # or dropped half the dimensions) are not aggregated — they skew
    # means toward hallucinated values. `dimensions-partial:<names>`
    # names the missing dims so the operator sees what was dropped.
    contract_violation=$(jq -r --arg expected "$EXPECTED_DIMS_CSV" '
        def grade_re: "^(A\\+|[ABCDF])$";
        ($expected | split(",")) as $exp
        | ($exp - (.dimensions | keys)) as $missing_dims
        | [
            (if (.composite | type) != "number" then "composite-not-number" else empty end),
            (if (.grade // null) == null then "grade-missing"
             elif ((.grade | test(grade_re)) | not) then "grade-malformed"
             else empty end),
            (if (.dimensions | length) == 0 then "dimensions-empty"
             elif ($missing_dims | length) > 0 then "dimensions-partial:\($missing_dims | join("|"))"
             else empty end)
          ] | join(",")
      ' "$run_normalized")
    if [[ -n "$contract_violation" ]]; then
      outcome="failure"
    fi
  fi

  if [[ "$outcome" == "failure" ]]; then
    # The harness always redirects to $run_stderr, so the file exists
    # by the time we get here (it may be zero bytes — the helper handles
    # that as "no stderr tail in evidence").
    categorize_args=(--stdout "$run_stdout" --stderr "$run_stderr" --exit-code "$run_rc")
    if [[ -n "$contract_violation" ]]; then
      categorize_args+=(--contract "$contract_violation")
    fi

    if ! categorize_json="$("$CATEGORIZE_HELPER" "${categorize_args[@]}" 2>/dev/null)"; then
      # The helper is defensive enough that this should be unreachable,
      # but if it does fail we still must produce a meta.json — losing
      # the run from the aggregate would understate the failure rate.
      categorize_json='{"category":"other","sub_reason":"categorize-helper-failed","evidence":{"stdout_head":null,"stdout_tail":null,"stderr_tail":null}}'
    fi

    cat_label=$(echo "$categorize_json" | jq -r '"\(.category)/\(.sub_reason)"')
    printf ' FAIL (%s, %ds)\n' "$cat_label" "$run_dur" >&2

    write_meta "$run_meta" "$i" "$run_rc" "$run_dur" "failure" \
      --argjson extra "$(jq -n --argjson failure "$categorize_json" '{failure: $failure}')"

    FAILED_RUNS=$((FAILED_RUNS+1))
    continue
  fi

  composite=$(jq -r '.composite' "$run_normalized")
  grade=$(jq -r '.grade' "$run_normalized")
  printf ' ok (composite=%s grade=%s, %ds)\n' "$composite" "$grade" "$run_dur" >&2

  write_meta "$run_meta" "$i" "$run_rc" "$run_dur" "success" \
    --argjson extra "$(jq -n --argjson composite "$composite" --arg grade "$grade" '{composite: $composite, grade: $grade}')"

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

# Build failures_by_category from per-run meta files. This gives the
# operator a one-line answer to "what dominant failure mode does this
# run-batch surface" without having to grep the meta files. Counts are
# of failed runs only; success runs are absent.
FAILURES_BY_CATEGORY="$RUNS_DIR/failures_by_category.json"
shopt -s nullglob
META_FILES=( "$RUNS_DIR"/run-*.meta.json )
shopt -u nullglob

if (( ${#META_FILES[@]} > 0 )); then
  if ! jq -s '
      map(select(.outcome == "failure") | .failure.category)
      | group_by(.)
      | map({key: .[0], value: length})
      | from_entries
    ' "${META_FILES[@]}" > "$FAILURES_BY_CATEGORY"; then
    echo "Warning: failed to compute failures_by_category aggregate" >&2
    echo '{}' > "$FAILURES_BY_CATEGORY"
  fi
else
  echo '{}' > "$FAILURES_BY_CATEGORY"
fi

if [[ "$SUCCESS_RUNS" -eq 0 ]]; then
  echo "All $N runs failed — no aggregation possible." >&2
  # Write a minimal results file capturing the failure.
  jq -n \
    --arg fixture "$FIXTURE_NAME" \
    --arg sha "$FIXTURE_SHA" \
    --arg desc "$FIXTURE_DESC" \
    --arg model "$EVAL_MODEL" \
    --argjson n "$N" \
    --argjson n_failed "$FAILED_RUNS" \
    --argjson dur "$DURATION" \
    --slurpfile failures_by_category "$FAILURES_BY_CATEGORY" \
    '{
       fixture: $fixture,
       fixture_sha: $sha,
       fixture_description: $desc,
       model: $model,
       n: $n,
       n_success: 0,
       n_failed: $n_failed,
       duration_seconds: $dur,
       failures_by_category: $failures_by_category[0],
       runs: [],
       aggregates: null
     }' > "$OUTPUT"
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
    # Half-away-from-zero rounding. `floor` would truncate toward -∞ and
    # bias every displayed stat downward (68.79 → 68.7, not 68.8).
    def round1:      ((. * 10)    | round) / 10;
    def round3:      ((. * 1000)  | round) / 1000;

    . as $runs
    | ($runs | length) as $n_total
    | ($runs | map(.composite // null) | map(select(. != null))) as $comps
    | ($runs | map(.grade // null) | map(select(. != null))) as $grades
    | ([$runs[].dimensions | keys[]] | unique) as $dimkeys
    | (reduce $grades[] as $g ({}; .[$g] = ((.[$g] // 0) + 1))) as $gdist
    # Mode: pick deterministically on ties. Sort by [-count, key] so the
    # highest count wins, alphabetically-lower key breaks equal counts.
    # `mode_tied` surfaces the tie explicitly so a reader never mistakes
    # the sort-order winner for a real plurality.
    | ( if ($gdist | length) == 0 then null
        else ($gdist | to_entries | sort_by([-.value, .key]) | .[0].key)
        end ) as $mode
    | ( if ($gdist | length) == 0 then false
        else ([$gdist[]] | max) as $maxc
             | ([$gdist[] | select(. == $maxc)] | length) > 1
        end ) as $mode_tied
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
          $gdist + {
            mode:      $mode,
            mode_tied: $mode_tied,
            flip_rate: ($flip | round3)
          }
        ),
        dimensions: (
          [ $dimkeys[] as $k
            | ($runs | map(.dimensions[$k] // null) | map(select(. != null))) as $vs
            | if ($vs | length) == 0 then empty
              else { ($k): {
                  n:             ($vs | length),
                  n_total:       $n_total,
                  missing_count: ($n_total - ($vs | length)),
                  mean:          ($vs | mean | round1),
                  stddev:        ($vs | stddev | round3),
                  min:           ($vs | min),
                  max:           ($vs | max)
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
    --arg model "$EVAL_MODEL" \
    --argjson n "$N" \
    --argjson n_success "$SUCCESS_RUNS" \
    --argjson n_failed "$FAILED_RUNS" \
    --argjson dur "$DURATION" \
    --slurpfile runs "$ALL_RUNS" \
    --slurpfile failures_by_category "$FAILURES_BY_CATEGORY" \
    '{
      fixture: $fixture,
      fixture_sha: $sha,
      fixture_description: $desc,
      model: $model,
      n: $n,
      n_success: $n_success,
      n_failed: $n_failed,
      duration_seconds: $dur,
      failures_by_category: $failures_by_category[0],
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
  echo "Model: $EVAL_MODEL"
  echo "Runs: $SUCCESS_RUNS successful, $FAILED_RUNS failed (of $N total)"
  echo "Duration: $(format_dur "$DURATION")"
  if (( FAILED_RUNS > 0 )); then
    fbc_line=$(jq -r '
        to_entries
        | sort_by(-.value)
        | map("\(.key)×\(.value)")
        | join("  ")
      ' "$FAILURES_BY_CATEGORY")
    if [[ -n "$fbc_line" ]]; then
      echo "Failures by category: $fbc_line"
    fi
  fi
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
      | ($g | del(.mode, .mode_tied, .flip_rate)) as $dist
      | ($g.flip_rate // 0) as $fr
      | ($g.mode_tied // false) as $tied
      | ($dist | to_entries | sort_by(.key) | map("\(.key)×\(.value)") | join(" ")) as $d
      | "Grade distribution: \($d)  (flip rate \(($fr * 100) | floor)%\(if $tied then ", mode tied" else "" end))"
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
      | "  \(.key)\t mean=\(.value.mean)\tstddev=\(.value.stddev)\tmin=\(.value.min)\tmax=\(.value.max)\("" + (if (.value.missing_count // 0) > 0 then "\tmissing=\(.value.missing_count)" else "" end))"
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
