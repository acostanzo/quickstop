#!/usr/bin/env bash
# compatible-pronto-check.sh — verify a sibling's compatible_pronto declaration
# against pronto's running version per ADR-004 §2.
#
# Usage:
#   compatible-pronto-check.sh <pronto_version> <compatible_pronto_range>
#
# Both arguments are strings. <compatible_pronto_range> may be empty (signals
# the sibling did not declare it). Outputs a single-line JSON object on stdout:
#
#   {"branch": "in_range" | "out_of_range" | "unset" | "malformed", "message": "..."}
#
# Branches map to ADR-004 §2's handshake outcomes (plus a fourth for sibling-side
# parse failures — see "malformed" below):
#   - in_range:     sibling's range covers pronto's version. Caller dispatches normally.
#   - out_of_range: sibling's range excludes pronto's version. Caller skips the sibling
#                   and falls back to presence-only scoring; emits a version-mismatch finding.
#   - unset:        sibling has no compatible_pronto. Caller dispatches anyway and emits
#                   a soft finding noting the missing handshake.
#   - malformed:    sibling's range can't be parsed as space-separated <op>MAJOR.MINOR.PATCH
#                   clauses (e.g. caret/tilde syntax, partial versions, prerelease tags).
#                   Caller skips the sibling and falls back to presence-only scoring with
#                   a hard finding naming the unparseable range. Distinct from caller-side
#                   bugs (missing/invalid pronto_version), which exit non-zero.
#
# Exit codes:
#   0   on any successful classification (in_range, out_of_range, unset, malformed —
#       all four are signals to the caller, not errors)
#   2   on caller-side bugs only: missing or non-semver pronto_version, or an internal
#       desync between the entrypoint op parser and clause_satisfied. Sibling-supplied
#       garbage is the malformed branch above, not exit 2.
#
# Range syntax: space-separated AND clauses. Each clause is <op><version> where:
#   op      ∈ { >=, <=, >, <, =, "" }   (empty op treated as "=")
#   version is strictly MAJOR.MINOR.PATCH (no prerelease, no build metadata).
#
# Range examples:
#   ">=0.1.0"               — minimum version, no upper bound
#   ">=0.1.0 <0.3.0"        — bounded range
#   "0.1.4"                 — exact match
#
# Prerelease and build-metadata semver suffixes are out of scope for v1. If a sibling
# needs them later, this script grows; ADR-004 §2 is silent on that question today.

set -euo pipefail

PRONTO_VERSION="${1:-}"
RANGE="${2-}"  # the "${VAR-}" form lets an empty string through without unset-error

err() {
  printf 'compatible-pronto-check: %s\n' "$1" >&2
  exit 2
}

is_valid_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ver_cmp A B → echoes -1 / 0 / 1 for A<B / A==B / A>B
ver_cmp() {
  local a="$1" b="$2"
  local IFS=. A B
  read -ra A <<< "$a"
  read -ra B <<< "$b"
  local i av bv
  for i in 0 1 2; do
    av=${A[i]:-0}
    bv=${B[i]:-0}
    if (( av < bv )); then echo -1; return 0; fi
    if (( av > bv )); then echo 1; return 0; fi
  done
  echo 0
}

# clause_satisfied <pronto_version> <op> <clause_version> → exit 0 if satisfied, 1 if not
clause_satisfied() {
  local pv="$1" op="$2" cv="$3"
  local cmp
  cmp="$(ver_cmp "$pv" "$cv")"
  case "$op" in
    '>='|'') (( cmp >= 0 )) ;;
    '<=')   (( cmp <= 0 )) ;;
    '>')    (( cmp >  0 )) ;;
    '<')    (( cmp <  0 )) ;;
    '=')    (( cmp == 0 )) ;;
    *) err "internal: clause_satisfied received unknown op '$op' — entrypoint parser and clause_satisfied are out of sync" ;;
  esac
}

emit_json() {
  local branch="$1" message="$2"
  jq -nc --arg b "$branch" --arg m "$message" '{branch: $b, message: $m}'
}

# --- entrypoint ---

if [[ -z "$PRONTO_VERSION" ]]; then
  err "pronto_version argument is required"
fi
if ! is_valid_version "$PRONTO_VERSION"; then
  err "pronto_version '$PRONTO_VERSION' is not a strict MAJOR.MINOR.PATCH semver"
fi

# Trim leading/trailing whitespace; jq's `.pronto.compatible_pronto // ""` may
# pass through whitespace-padded strings depending on the source manifest.
RANGE="${RANGE#"${RANGE%%[![:space:]]*}"}"
RANGE="${RANGE%"${RANGE##*[![:space:]]}"}"

if [[ -z "$RANGE" ]]; then
  emit_json "unset" \
    "Sibling does not declare compatible_pronto; dispatching at sibling's risk per ADR-004 §2."
  exit 0
fi

# Tokenize on whitespace; each token is one clause.
read -ra CLAUSES <<< "$RANGE"

failing_clause=""
for clause in "${CLAUSES[@]}"; do
  # Parse op + version. Order matters: check 2-char ops before 1-char ops.
  op="" cv=""
  if [[ "$clause" == '>='* ]]; then
    op='>='
    cv="${clause:2}"
  elif [[ "$clause" == '<='* ]]; then
    op='<='
    cv="${clause:2}"
  elif [[ "$clause" == '>'* ]]; then
    op='>'
    cv="${clause:1}"
  elif [[ "$clause" == '<'* ]]; then
    op='<'
    cv="${clause:1}"
  elif [[ "$clause" == '='* ]]; then
    op='='
    cv="${clause:1}"
  else
    op='='
    cv="$clause"
  fi

  if ! is_valid_version "$cv"; then
    # Sibling-supplied range clause is unparseable. Distinct from caller bugs
    # (missing/invalid pronto_version) — those still err with rc=2. Sibling
    # malformed input becomes the `malformed` branch with rc=0 so the
    # orchestrator's parse-and-branch flow handles it uniformly per ADR-004 §2.
    emit_json "malformed" \
      "Sibling's compatible_pronto clause '$clause' has invalid version '$cv' (expect MAJOR.MINOR.PATCH; full range: '$RANGE')."
    exit 0
  fi

  if ! clause_satisfied "$PRONTO_VERSION" "$op" "$cv"; then
    failing_clause="$clause"
    break
  fi
done

if [[ -z "$failing_clause" ]]; then
  emit_json "in_range" \
    "pronto $PRONTO_VERSION satisfies sibling's compatible_pronto range '$RANGE'."
else
  emit_json "out_of_range" \
    "pronto $PRONTO_VERSION does not satisfy sibling's compatible_pronto clause '$failing_clause' (full range: '$RANGE')."
fi
