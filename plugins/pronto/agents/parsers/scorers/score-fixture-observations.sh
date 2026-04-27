#!/usr/bin/env bash
# score-fixture-observations.sh — synthetic v2 fixture script.
#
# Emits a hand-crafted v2 audit payload with observations[] covering all
# four kinds (ratio, count, presence, score). Used by the unit suite
# (observations-to-score.test.sh) and by anyone exercising the H4
# translator without depending on a real sibling shipping native v2
# emission yet.
#
# This script is NOT wired into the eval harness or the live audit
# path. It is a fixture, not a parser. The eval harness still runs
# against the existing shipped scorers (which emit v1) so that the
# byte-equivalence invariant for the v1 passthrough rule is exercised
# in the harness; this fixture exercises the v2 translation path on
# demand.
#
# Usage:
#   score-fixture-observations.sh [--dimension <slug>]
#
# With no arguments, emits the default claude-code-config payload.
# With --dimension <slug>, emits a payload targeted at that dimension
# (slugs supported: claude-code-config, skills-quality, commit-hygiene).
#
# Exit 0 on success. Exit 2 on argument errors.

set -euo pipefail

DIMENSION="claude-code-config"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dimension) DIMENSION="${2:-}"; shift 2 ;;
    -h|--help)
      cat >&2 <<EOF
Usage: $(basename "$0") [--dimension <slug>]

Emits a synthetic v2 sibling-audit JSON payload with hand-crafted
observations[] covering all four kinds. Use as a fixture for the
H4 observations-to-score translator.
EOF
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required" >&2
  exit 2
fi

case "$DIMENSION" in
  claude-code-config)
    jq -n '{
      "$schema_version": 2,
      plugin: "fixture-observations",
      dimension: "claude-code-config",
      categories: [],
      observations: [
        {
          id: "claude-md-redundancy-ratio",
          kind: "ratio",
          evidence: { redundant_lines: 17, total_lines: 142, ratio: 0.12 },
          summary: "12% of CLAUDE.md lines restate built-in instructions"
        },
        {
          id: "mcp-server-count",
          kind: "count",
          evidence: { configured: 3, registered: 3 },
          summary: "3 MCP servers configured, all registered"
        },
        {
          id: "settings-default-mode-explicit",
          kind: "presence",
          evidence: { present: true },
          summary: "permissions.defaultMode declared in .claude/settings.json"
        },
        {
          id: "broad-allow-glob-count",
          kind: "count",
          evidence: { count: 0 },
          summary: "No broad Bash(*)/Write(*) allow entries"
        },
        {
          id: "claude-md-line-count",
          kind: "count",
          evidence: { count: 142 },
          summary: "CLAUDE.md is 142 non-blank lines"
        }
      ],
      composite_score: 78,
      letter_grade: "B",
      recommendations: []
    }'
    ;;
  skills-quality)
    jq -n '{
      "$schema_version": 2,
      plugin: "fixture-observations",
      dimension: "skills-quality",
      categories: [],
      observations: [
        {
          id: "skill-frontmatter-completeness-ratio",
          kind: "ratio",
          evidence: { complete: 7, total: 8, ratio: 0.875 },
          summary: "7/8 skills have full frontmatter"
        },
        {
          id: "skill-skeletal-count",
          kind: "count",
          evidence: { count: 0 },
          summary: "No skeletal skills (<20 non-blank lines)"
        },
        {
          id: "skill-todo-marker-count",
          kind: "count",
          evidence: { count: 1 },
          summary: "1 TODO marker across SKILL.md files"
        },
        {
          id: "skill-broken-references-count",
          kind: "count",
          evidence: { count: 0 },
          summary: "All references/ pointers resolve"
        }
      ],
      composite_score: 90,
      letter_grade: "A",
      recommendations: []
    }'
    ;;
  commit-hygiene)
    jq -n '{
      "$schema_version": 2,
      plugin: "fixture-observations",
      dimension: "commit-hygiene",
      categories: [],
      observations: [
        {
          id: "conventional-commit-ratio",
          kind: "ratio",
          evidence: { matches: 48, total: 50, ratio: 0.96 },
          summary: "96% of recent commits match conventional-commit shape"
        },
        {
          id: "auto-trailer-count",
          kind: "count",
          evidence: { count: 0 },
          summary: "No automated Co-Authored-By trailers in recent history"
        },
        {
          id: "auto-attribution-marker-count",
          kind: "count",
          evidence: { count: 0 },
          summary: "No Generated with Claude Code markers"
        },
        {
          id: "review-signal-presence",
          kind: "presence",
          evidence: { present: false },
          summary: "Review-comment signal not sampled (network-free audit)"
        }
      ],
      composite_score: 100,
      letter_grade: "A+",
      recommendations: []
    }'
    ;;
  *)
    echo "Unknown dimension: $DIMENSION" >&2
    echo "Supported: claude-code-config, skills-quality, commit-hygiene" >&2
    exit 2
    ;;
esac
