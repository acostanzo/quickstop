---
name: refresh
description: Force-refresh the claudit knowledge cache from official Anthropic documentation
disable-model-invocation: true
argument-hint: "[domain|all]"
allowed-tools: Task, Read, Bash, Write
---

# Claudit: Refresh Knowledge Cache

You are the claudit cache refresh orchestrator. When the user runs `/claudit:refresh`, force-refresh the knowledge cache from official Anthropic documentation.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` to determine which domains to refresh:

- `core-config` → refresh only core configuration knowledge
- `ecosystem` → refresh only ecosystem knowledge
- `optimization` → refresh only optimization knowledge
- `all`, empty, or missing → refresh all three domains (default)

## Step 2: Prepare Cache Directory

Run via Bash: `mkdir -p ~/.cache/claudit`

## Step 3: Get Current Version

Run via Bash: `claude --version 2>/dev/null` → store as **CURRENT_VERSION**

Tell the user:

```
Refreshing knowledge cache (Claude Code v{CURRENT_VERSION})...
```

## Step 4: Dispatch Research Agents

Dispatch the selected research agent(s) in parallel using the Task tool. All must be foreground (do NOT use `run_in_background`).

**Research Core** (if domain is `core-config` or `all`):
- `description`: "Research core config docs"
- `subagent_type`: "claudit:research-core"
- `prompt`: "Build expert knowledge on Claude Code core configuration. Read the baseline from ${CLAUDE_PLUGIN_ROOT}/skills/claudit/references/known-settings.md first, then fetch official Anthropic documentation for settings, permissions, CLAUDE.md, and memory. Return structured expert knowledge."

**Research Ecosystem** (if domain is `ecosystem` or `all`):
- `description`: "Research ecosystem docs"
- `subagent_type`: "claudit:research-ecosystem"
- `prompt`: "Build expert knowledge on Claude Code ecosystem features. Fetch official Anthropic documentation for MCP servers, hooks, skills, sub-agents, and plugins. Return structured expert knowledge."

**Research Optimization** (if domain is `optimization` or `all`):
- `description`: "Research optimization docs"
- `subagent_type`: "claudit:research-optimization"
- `prompt`: "Build expert knowledge on Claude Code performance and over-engineering patterns. Fetch official Anthropic documentation for model configuration, CLI reference, and best practices. Search for context optimization and over-engineering anti-patterns. Return structured expert knowledge."

## Step 5: Write Cache

For each domain that was refreshed:

1. Write the agent's results to the corresponding cache file using the Write tool:
   - `~/.cache/claudit/core-config.md`
   - `~/.cache/claudit/ecosystem.md`
   - `~/.cache/claudit/optimization.md`

2. Read the existing `~/.cache/claudit/manifest.json` (if it exists) to preserve timestamps for domains that were NOT refreshed.

3. Write `~/.cache/claudit/manifest.json`. For partial refreshes, only update the refreshed domains' `cached_at` and preserve the rest. Only update the top-level `claude_code_version` and `cached_at` when ALL domains are refreshed (either explicitly via `all` or because all three were specified):
   ```json
   {
     "claude_code_version": "{CURRENT_VERSION if all domains refreshed, otherwise preserve existing}",
     "cached_at": "{current timestamp if all domains refreshed, otherwise preserve existing}",
     "max_ttl_days": 7,
     "domains": {
       "core-config": { "cached_at": "{current if refreshed, preserved if not}" },
       "ecosystem": { "cached_at": "{current if refreshed, preserved if not}" },
       "optimization": { "cached_at": "{current if refreshed, preserved if not}" }
     }
   }
   ```

**Why**: Consumers check per-domain `cached_at` for TTL and the top-level `claude_code_version` for version invalidation. Updating these on partial refreshes would incorrectly mark non-refreshed domains as fresh. See `${CLAUDE_PLUGIN_ROOT}/references/cache-check-protocol.md` for the full cache contract.

## Step 6: Report

Display a summary:

```
╔══════════════════════════════════════════════════╗
║         CLAUDIT CACHE REFRESHED                  ║
╠══════════════════════════════════════════════════╣

Claude Code: v{CURRENT_VERSION}
Refreshed:   {list of domains refreshed}
Cached at:   {timestamp}
Expires:     {timestamp + 7 days}

Cache: ~/.cache/claudit/
╚══════════════════════════════════════════════════╝

Other tools that benefit from this cache:
  /claudit        — skips research phase on next audit
  /skillet:*      — uses ecosystem knowledge for skill analysis
  /smith, /hone   — uses ecosystem knowledge for plugin scaffolding/auditing
```
