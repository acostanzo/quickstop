#!/usr/bin/env bash
# inkwell-corroborate.sh — Tier 1 / Tier 2 / Tier 3 corroboration
# dispatcher for /inkwell:query.
#
# Reads a chunks block on stdin (the same block /inkwell:query's
# retrieval emits above the `---END-OF-CHUNKS---` sentinel — i.e. one
# `### <citation>` heading per cited section, followed by the section
# body). For each citation, classifies every claim into one of three
# tiers and emits a verdict on stdout:
#
#   <citation><TAB><verdict>
#
# Verdicts:
#   verified
#   drift detected (see <hint>)
#   could not corroborate
#
# Tier 1 — deterministic name-resolution. Inline code spans are checked
# against <REPO_ROOT> via grep. No LLM dispatch.
#   - file_only          (`path/to/file.ext`)         — file exists?
#   - file_symbol        (`path/to/file.ext:symbol`)  — file exists AND
#                                                       symbol grep-hits
#                                                       inside it
#   - symbol_only        (`identifierName`)           — symbol grep-hits
#                                                       across source
#                                                       extensions; on
#                                                       miss → "could
#                                                       not corroborate"
#                                                       (no penalty per
#                                                       spec)
#
# Tier 2 — LLM-judged behavioural verification. Sentences with signal
# verbs ("returns", "calls", "when X", "the default is Z", …) dispatch
# one subagent per citation via
# `${INKWELL_CORROBORATE_SUBAGENT:-claude} -p --model haiku`, bounded
# by `${INKWELL_CORROBORATE_TIMEOUT:-20}` seconds. Subagent absent,
# timed out, or unparseable → "could not corroborate" for the affected
# citation, exit 0, no crash. Per ADR-007: "corroboration never blocks
# the response."
#
# Tier 3 — annotated "could not corroborate." Citations with no
# Tier 1 or Tier 2 input — purely conceptual statements, design
# rationale, narrative — get a single "could not corroborate" line
# with no penalty. These are exactly the things docs *should* carry
# that code can't express.
#
# ADR-006 conformance: read-only against <REPO_ROOT>; only writes
# stdout and ephemeral $TMPDIR tempfiles cleaned by trap.
#
# Usage:
#   inkwell-corroborate.sh <REPO_ROOT> < chunks-block
#
# Exit 0 in every documented case (verdict emitted, tier-2 degraded,
# empty input). Exit 2 on argument errors only.

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <REPO_ROOT> < chunks-block" >&2
  exit 2
fi
REPO_ROOT="$1"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "inkwell-corroborate.sh: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

SUBAGENT_CMD="${INKWELL_CORROBORATE_SUBAGENT:-claude}"
SUBAGENT_TIMEOUT="${INKWELL_CORROBORATE_TIMEOUT:-20}"

TMP_DIR="$(mktemp -d -t inkwell-corroborate.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------------------------------------------------------------------
# Parse stdin into per-citation body files.
#
# A new section starts at every line matching `^### <citation>$`.
# Anything before the first `### ` is preamble and ignored (matches
# how inkwell-query-retrieve.sh emits `## Retrieved chunks` above the
# first citation). Citation order is preserved — verdict lines are
# emitted in the same order, so the consumer can map verdicts to the
# Sources block deterministically.
# ---------------------------------------------------------------------

n=0
CITATIONS=()
while IFS= read -r line; do
  if [[ "$line" =~ ^###[[:space:]]+(.+)$ ]]; then
    n=$((n + 1))
    CITATIONS+=("${BASH_REMATCH[1]}")
    : > "$TMP_DIR/body.$n"
    continue
  fi
  if (( n > 0 )); then
    printf '%s\n' "$line" >> "$TMP_DIR/body.$n"
  fi
done

if (( n == 0 )); then
  exit 0
fi

# ---------------------------------------------------------------------
# Tier 1 — code-span extraction and verification.
# ---------------------------------------------------------------------

# extract_code_spans <body-file> — print one inline code span per line.
# Single-backtick wrapping only; lines inside fenced ``` blocks are
# skipped (we don't want to try to "verify" a code example).
extract_code_spans() {
  awk '
    BEGIN { in_fence = 0 }
    /^[[:space:]]*```/ { in_fence = 1 - in_fence; next }
    in_fence { next }
    {
      line = $0
      while (match(line, /`[^`]+`/)) {
        s = substr(line, RSTART + 1, RLENGTH - 2)
        print s
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

# classify_span <span> — file_symbol | file_only | symbol_only | other
classify_span() {
  local s="$1"
  if [[ "$s" =~ ^([A-Za-z0-9_./-]+\.[A-Za-z0-9]+):([A-Za-z_][A-Za-z0-9_]*)$ ]]; then
    echo "file_symbol"
    return
  fi
  if [[ "$s" =~ ^[A-Za-z0-9_./-]+\.[A-Za-z0-9]+$ ]]; then
    echo "file_only"
    return
  fi
  if [[ "$s" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "symbol_only"
    return
  fi
  echo "other"
}

# tier1_verify_file <path> — verified | drift detected (...)
tier1_verify_file() {
  local path="$1"
  if [[ -f "$REPO_ROOT/$path" ]]; then
    echo "verified"
  else
    echo "drift detected (see ${path}: file does not exist)"
  fi
}

# tier1_verify_file_symbol <path> <symbol> — verified | drift detected (...)
tier1_verify_file_symbol() {
  local path="$1" symbol="$2"
  if [[ ! -f "$REPO_ROOT/$path" ]]; then
    echo "drift detected (see ${path}: file does not exist)"
    return
  fi
  if grep -F -q -- "$symbol" "$REPO_ROOT/$path" 2>/dev/null; then
    echo "verified"
  else
    echo "drift detected (see ${path}: symbol '${symbol}' not found)"
  fi
}

# tier1_verify_symbol_only <symbol> — verified | could not corroborate
# Per spec: bare symbol without a path gets a global fan-out search;
# miss is "could not corroborate" (no penalty), not a drift verdict.
tier1_verify_symbol_only() {
  local symbol="$1"
  if grep -F -r -q \
       --include='*.ts' --include='*.tsx' \
       --include='*.js' --include='*.jsx' --include='*.mjs' --include='*.cjs' \
       --include='*.py' --include='*.go' --include='*.rs' \
       -- "$symbol" "$REPO_ROOT" 2>/dev/null; then
    echo "verified"
  else
    echo "could not corroborate"
  fi
}

# ---------------------------------------------------------------------
# Tier 2 — behavioural-claim heuristic + subagent dispatch.
# ---------------------------------------------------------------------

# has_behavioural_claim <body-file> — exit 0 if the body contains at
# least one prose sentence with a behavioural signal verb. The shape
# heuristic is intentionally narrow: we want to fire Tier 2 only when
# there's something the subagent could actually verify against code.
has_behavioural_claim() {
  awk '
    BEGIN { in_fence = 0 }
    /^[[:space:]]*```/ { in_fence = 1 - in_fence; next }
    in_fence { next }
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*[-*][[:space:]]*$/ { next }
    {
      lower = tolower($0)
      if (lower ~ /(returns?|defaults?[[:space:]]+to|the[[:space:]]+default|when[[:space:]]+[a-z]|if[[:space:]]+[a-z]|calls?[[:space:]]|verifies?|invokes?|produces?|raises?|throws?|emits?[[:space:]]|rotates?[[:space:]])/) {
        found = 1
        exit
      }
    }
    END { exit found ? 0 : 1 }
  ' "$1"
}

# tier2_dispatch <citation> <body-file> — print one verdict line.
# Graceful degradation: subagent absent, timed out, or unparseable
# stdout → "could not corroborate". Exit always 0 regardless of the
# subagent's exit code; the Tier-2 path must never propagate a failure.
tier2_dispatch() {
  local citation="$1" body_file="$2"
  if ! command -v "$SUBAGENT_CMD" >/dev/null 2>&1; then
    echo "could not corroborate"
    return
  fi
  local prompt
  prompt="Doc citation: ${citation}
Doc claim (excerpt):
$(cat "$body_file")

Repository root: ${REPO_ROOT}

Question: does the code in this repository support the doc's
behavioural claim? Read the relevant source files and reply with
exactly one of:
- verified
- drift detected: <one-line reason>
- could not corroborate

No other prose. No preamble. The single-line reply is your entire
output."

  local raw firstline lower
  raw="$(timeout "$SUBAGENT_TIMEOUT" "$SUBAGENT_CMD" -p --model haiku <<<"$prompt" 2>/dev/null || true)"
  firstline="$(printf '%s' "$raw" | awk 'NF { print; exit }')"
  lower="$(printf '%s' "$firstline" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    verified*)
      echo "verified" ;;
    "drift detected"*|"drift-detected"*)
      local reason="${firstline#*[: -]}"
      reason="${reason## }"
      if [[ -z "$reason" || "$reason" == "$firstline" ]]; then
        echo "drift detected (subagent verdict)"
      else
        echo "drift detected (${reason})"
      fi
      ;;
    *)
      echo "could not corroborate" ;;
  esac
}

# ---------------------------------------------------------------------
# Per-citation dispatch loop — emit one or more verdict lines per
# citation. Ordering: Tier 1 spans first (in chunk order), Tier 2
# next (one verdict per citation if behavioural claims found),
# Tier 3 fallback if neither produced anything.
# ---------------------------------------------------------------------

emit_verdict() {
  local citation="$1" verdict="$2"
  printf '%s\t%s\n' "$citation" "$verdict"
}

for ((i = 1; i <= n; i++)); do
  citation="${CITATIONS[i-1]}"
  body_file="$TMP_DIR/body.$i"
  emitted=0

  # Tier 1 — code spans.
  while IFS= read -r span; do
    [[ -z "$span" ]] && continue
    case "$(classify_span "$span")" in
      file_symbol)
        path="${span%%:*}"
        symbol="${span#*:}"
        verdict="$(tier1_verify_file_symbol "$path" "$symbol")"
        emit_verdict "$citation" "$verdict"
        emitted=1
        ;;
      file_only)
        verdict="$(tier1_verify_file "$span")"
        emit_verdict "$citation" "$verdict"
        emitted=1
        ;;
      symbol_only)
        verdict="$(tier1_verify_symbol_only "$span")"
        emit_verdict "$citation" "$verdict"
        emitted=1
        ;;
      other)
        : ;;  # not code-shaped; defer to Tier 2 / Tier 3
    esac
  done < <(extract_code_spans "$body_file" | LC_ALL=C sort -u)

  # Tier 2 — behavioural assertions. One subagent dispatch per
  # citation that carries behavioural shape. Per the brief: keep this
  # simple; sharper claim batching is M6 stretch work.
  if has_behavioural_claim "$body_file"; then
    verdict="$(tier2_dispatch "$citation" "$body_file")"
    emit_verdict "$citation" "$verdict"
    emitted=1
  fi

  # Tier 3 — conceptual fallback. Nothing to verify against code.
  if (( emitted == 0 )); then
    emit_verdict "$citation" "could not corroborate"
  fi
done
