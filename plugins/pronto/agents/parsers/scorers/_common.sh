#!/usr/bin/env bash
# Shared helpers for deterministic parser scoring scripts.
#
# These helpers convert shell-measurable signals into contract-shape JSON
# fragments. They do not spawn sub-Claudes, do not use LLM judgment, and
# produce byte-identical output across runs against the same filesystem.

set -euo pipefail

# nblines <path>
#   Print the number of non-blank lines in <path>. Returns 0 if the file
#   does not exist. Used for every "lines ≥ N" threshold.
nblines() {
  local f="$1"
  if [[ -f "$f" ]]; then
    awk 'NF>0' "$f" 2>/dev/null | wc -l
  else
    echo 0
  fi
}

# clamp <n> <lo> <hi>
clamp() {
  local n="$1" lo="$2" hi="$3"
  if (( n < lo )); then echo "$lo"
  elif (( n > hi )); then echo "$hi"
  else echo "$n"
  fi
}

# grade_for <score>
#   Derive the letter grade from a 0-100 integer using the bands in
#   references/rubric.md. Kept in sync with kernel-check and the audit
#   orchestrator.
grade_for() {
  local s="$1"
  if   (( s >= 95 )); then echo "A+"
  elif (( s >= 90 )); then echo "A"
  elif (( s >= 75 )); then echo "B"
  elif (( s >= 60 )); then echo "C"
  elif (( s >= 40 )); then echo "D"
  else                     echo "F"
  fi
}

# severity_for <deduction>
#   Map a single deduction's point cost to a contract severity label.
severity_for() {
  local d="$1"
  if   (( d >= 40 )); then echo "critical"
  elif (( d >= 20 )); then echo "high"
  elif (( d >= 10 )); then echo "medium"
  else                     echo "low"
  fi
}
