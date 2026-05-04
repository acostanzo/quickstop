#!/usr/bin/env bash
# Deterministic sibling discovery for pronto's audit.
#
# Usage:
#   discover-siblings.sh <CLAUDE_PLUGIN_ROOT>
#
# Walks the parent directory of pronto's own plugin root looking for
# loaded sibling plugins. Emits a JSON array on stdout of the shape
#   [
#     {
#       "name": "<plugin-name>",
#       "plugin_root": "<absolute-path-to-plugin-dir>",
#       "version": "<plugin-version>",
#       "compatible_pronto": "<range>",
#       "native_declarations": [ { "dimension": "...", "command": "..." }, ... ]
#     }
#   ]
#
# Every co-located plugin with a readable plugin.json is emitted; pronto
# itself is skipped (it does not audit itself). `native_declarations` is
# the plugin's `pronto.audits` array (empty `[]` when absent) — siblings
# without that block are still emitted so the orchestrator can reach
# parser-agent dispatch (Sub-path B) for them via recommendations.json.
#
# Why parent-walk: when pronto is loaded into a Claude Code session,
# `${CLAUDE_PLUGIN_ROOT}` resolves to the directory it was loaded from —
# either `~/.claude/plugins/pronto@<source>/` (for /plugin install) or
# `<repo>/plugins/pronto/` (for --plugin-dir). In both layouts, sibling
# plugins are siblings on disk: one directory up. Walking the parent is
# the only source of truth that captures both cases without depending on
# `installed_plugins.json` (which doesn't list --plugin-dir loads) or
# the audit-target's `marketplace.json` (which describes what plugins
# the target *expects*, not what's actually loaded into this session).
#
# This script is the deterministic counterpart to Phase 2 of SKILL.md.
# The orchestrator captures its stdout and uses the array as
# INSTALLED_SIBLINGS — no LLM-controlled enumeration.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <CLAUDE_PLUGIN_ROOT>" >&2
  exit 2
fi

PRONTO_ROOT="$1"

if [[ ! -d "$PRONTO_ROOT" ]]; then
  echo "Error: CLAUDE_PLUGIN_ROOT '$PRONTO_ROOT' is not a directory" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not found on PATH" >&2
  exit 2
fi

PARENT="$(dirname "$PRONTO_ROOT")"

shopt -s nullglob
RECORDS=()
for plugin_dir in "$PARENT"/*/; do
  plugin_dir="${plugin_dir%/}"
  plugin_json="$plugin_dir/.claude-plugin/plugin.json"
  [[ -f "$plugin_json" ]] || continue

  name=$(jq -r '.name // empty' "$plugin_json" 2>/dev/null || true)
  [[ -z "$name" ]] && continue
  [[ "$name" == "pronto" ]] && continue

  audits=$(jq -c '.pronto.audits // []' "$plugin_json" 2>/dev/null || echo '[]')

  version=$(jq -r '.version // "unknown"' "$plugin_json" 2>/dev/null || echo "unknown")
  compat=$(jq -r '.pronto.compatible_pronto // ""' "$plugin_json" 2>/dev/null || true)

  record=$(jq -n \
    --arg name "$name" \
    --arg root "$plugin_dir" \
    --arg version "$version" \
    --arg compat "$compat" \
    --argjson audits "$audits" \
    '{
       name: $name,
       plugin_root: $root,
       version: $version,
       compatible_pronto: $compat,
       native_declarations: $audits
     }')
  RECORDS+=("$record")
done
shopt -u nullglob

if (( ${#RECORDS[@]} == 0 )); then
  echo "[]"
else
  printf '%s\n' "${RECORDS[@]}" | jq -s '. | sort_by(.name)'
fi
