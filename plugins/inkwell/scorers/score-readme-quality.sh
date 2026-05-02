#!/usr/bin/env bash
# score-readme-quality.sh — emit a `readme-arrival-coverage`
# observation for the code-documentation dimension.
#
# Reads README.md at <REPO_ROOT> and counts how many of the five
# arrival questions from roll-your-own/code-documentation.md are
# answered. Loose case-insensitive match on section headers — README
# layouts vary widely and a strict-match scorer would reject perfectly
# clear documentation just because the section is titled `## Quick
# Start` instead of `## Install`.
#
# The five arrival questions:
#   1. What does this project do?    H1 followed by paragraph text,
#                                    OR `## (About|Overview)`
#   2. Who is it for?                `## (Users?|Audience|For)`
#   3. How do I install / run it?    `## (Install|Setup|Quickstart|
#                                       Usage|Getting Started)`
#   4. What's the status?            `## (Status|Project Status)`
#                                    OR a status-badge line
#                                       (`[![...](...)](...)`)
#   5. Where do I go next?           `## (Docs?|Documentation|See
#                                       Also|Next)`
#                                    OR a `[docs/](...)` link
#
# Empty-scope short-circuit: README.md absent -> omit observation
# (no stdout) and exit 0. The translator's case-3 carve-out handles
# missing observations downstream.
#
# Usage:
#   score-readme-quality.sh <REPO_ROOT>
#
# Exit 0 on success (one-line JSON observation on stdout, or empty
# stdout for empty scope). Exit 2 on argument or environment errors.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$HERE/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <REPO_ROOT>" >&2
  exit 2
fi
REPO_ROOT="$1"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required" >&2
  exit 2
fi

README="$REPO_ROOT/README.md"
if [[ ! -f "$README" ]]; then
  exit 0  # empty-scope short-circuit
fi

EXPECTED=5
MATCHED=0

# ---- Q1: What does this project do? -----------------------------------
# Loose match: an `## About` / `## Overview` section anywhere, OR the H1
# title is followed by at least one non-blank, non-heading line of body
# text before the next section.
q1_hit=0
if grep -qiE '^## +(About|Overview)' "$README"; then
  q1_hit=1
else
  # awk: find first `^# ` line; check whether any subsequent line before
  # the next `^## ` (or EOF) is non-blank and not a heading line.
  q1_body=$(awk '
    BEGIN { in_intro = 0 }
    /^# +/ && in_intro == 0 { in_intro = 1; next }
    in_intro == 1 && /^## +/ { exit }
    in_intro == 1 && NF > 0 && $0 !~ /^#/ { print "yes"; exit }
  ' "$README")
  [[ "$q1_body" == "yes" ]] && q1_hit=1
fi
(( q1_hit == 1 )) && MATCHED=$((MATCHED + 1))

# ---- Q2: Who is it for? ----------------------------------------------
if grep -qiE '^## +(Users?|Audience|For [A-Za-z])' "$README"; then
  MATCHED=$((MATCHED + 1))
fi

# ---- Q3: How do I install / run it? ----------------------------------
if grep -qiE '^## +(Install|Installation|Setup|Quickstart|Quick Start|Usage|Getting Started)' "$README"; then
  MATCHED=$((MATCHED + 1))
fi

# ---- Q4: What's the status? ------------------------------------------
# Section header OR a Markdown badge line (shields.io / similar:
# `[![alt](image-url)](target-url)`). The badge regex is intentionally
# narrow — a plain `[text](url)` link doesn't count as a status badge.
q4_hit=0
if grep -qiE '^## +(Status|Project Status)' "$README"; then
  q4_hit=1
elif grep -qE '\[!\[[^]]*\]\([^)]+\)\]\([^)]+\)' "$README"; then
  q4_hit=1
fi
(( q4_hit == 1 )) && MATCHED=$((MATCHED + 1))

# ---- Q5: Where do I go next? -----------------------------------------
# Section header OR a `[anything](docs/...)` link to a docs/ tree.
q5_hit=0
if grep -qiE '^## +(Docs?|Documentation|See Also|Next|Further Reading|Resources)' "$README"; then
  q5_hit=1
elif grep -qE '\[[^]]+\]\(docs/' "$README"; then
  q5_hit=1
fi
(( q5_hit == 1 )) && MATCHED=$((MATCHED + 1))

RATIO=$(format_ratio "$MATCHED" "$EXPECTED")

jq -nc \
  --argjson matched "$MATCHED" \
  --argjson expected "$EXPECTED" \
  --argjson ratio "$RATIO" \
  '{
    id: "readme-arrival-coverage",
    kind: "ratio",
    evidence: {
      matched: $matched,
      expected: $expected,
      ratio: $ratio
    },
    summary: "\($matched)/\($expected) README arrival questions covered"
  }'
