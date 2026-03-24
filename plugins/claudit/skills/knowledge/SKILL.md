---
name: knowledge
description: Retrieve claudit knowledge cache domains (ecosystem, core-config, optimization). Checks freshness and auto-refreshes stale domains.
disable-model-invocation: true
argument-hint: "[domain ...] (ecosystem | core-config | optimization | all)"
allowed-tools: Task, Read, Bash, Write
---

# Claudit: Knowledge Cache Access

You are the claudit knowledge provider. When invoked via `/claudit:knowledge [domain ...]`, check the knowledge cache, auto-refresh if stale, and output the requested domain content. This skill is the preferred interface for any tool that needs claudit's cached research.

## Step 1: Parse Arguments

Parse `$ARGUMENTS` to determine which domains to retrieve:

- `ecosystem` → ecosystem only
- `core-config` → core-config only
- `optimization` → optimization only
- `all`, empty, or missing → all three domains (default)
- Multiple space-separated domains → each listed domain (e.g., `ecosystem core-config`)

Map each domain to its cache file:

| Domain | Cache File |
|--------|-----------|
| core-config | `~/.cache/claudit/core-config.md` |
| ecosystem | `~/.cache/claudit/ecosystem.md` |
| optimization | `~/.cache/claudit/optimization.md` |

Store the list of requested domains as **REQUESTED_DOMAINS**.

## Step 2: Check Cache Freshness

Follow the cache-check protocol (see `${CLAUDE_PLUGIN_ROOT}/references/cache-check-protocol.md`), scoped to REQUESTED_DOMAINS only.

1. Run via Bash: `claude --version 2>/dev/null` → store as **CURRENT_VERSION**
2. Run via Bash: `cat ~/.cache/claudit/manifest.json 2>/dev/null`
3. If the manifest does not exist → all domains are **MISSING**. Go to Step 3.
4. If the manifest exists, apply **three-check invalidation** per requested domain:
   a. **Version check**: Compare manifest's `claude_code_version` to CURRENT_VERSION. If different → all domains **STALE**.
   b. **Per-domain time check**: For each domain in REQUESTED_DOMAINS, check `domains.<name>.cached_at`. If age >= `max_ttl_days` (default 7 days) → that domain is **STALE**.
   c. **File check**: For each domain in REQUESTED_DOMAINS, verify the cache `.md` file exists. If missing → that domain is **STALE**.
5. A domain is **FRESH** only if all three checks pass for it.

Partition REQUESTED_DOMAINS into **FRESH_DOMAINS** and **STALE_DOMAINS**.

## Step 3: Refresh Stale Domains

If STALE_DOMAINS is empty, skip to Step 4.

Tell the user:

```
Refreshing knowledge cache ({list of stale domains})...
```

Run via Bash: `mkdir -p ~/.cache/claudit`

Dispatch research agents for stale domains only, in parallel using the Task tool. All must be foreground (do NOT use `run_in_background`).

**Research Core** (if `core-config` is stale):
- `description`: "Research core config docs"
- `subagent_type`: "claudit:research-core"
- `prompt`: "Build expert knowledge on Claude Code core configuration. Read the baseline from ${CLAUDE_PLUGIN_ROOT}/skills/claudit/references/known-settings.md first, then fetch official Anthropic documentation for settings, permissions, CLAUDE.md, and memory. Return structured expert knowledge."

**Research Ecosystem** (if `ecosystem` is stale):
- `description`: "Research ecosystem docs"
- `subagent_type`: "claudit:research-ecosystem"
- `prompt`: "Build expert knowledge on Claude Code ecosystem features. Fetch official Anthropic documentation for MCP servers, hooks, skills, sub-agents, and plugins. Return structured expert knowledge."

**Research Optimization** (if `optimization` is stale):
- `description`: "Research optimization docs"
- `subagent_type`: "claudit:research-optimization"
- `prompt`: "Build expert knowledge on Claude Code performance and over-engineering patterns. Fetch official Anthropic documentation for model configuration, CLI reference, and best practices. Search for context optimization and over-engineering anti-patterns. Return structured expert knowledge."

### Write Cache

For each refreshed domain, write the agent's results to the corresponding cache file using the Write tool.

Then update the manifest. Read the existing `~/.cache/claudit/manifest.json` (if it exists) to preserve timestamps for domains that were NOT refreshed. Write the updated manifest:

```json
{
  "claude_code_version": "{CURRENT_VERSION if all 3 domains refreshed, otherwise preserve existing}",
  "cached_at": "{current timestamp if all 3 domains refreshed, otherwise preserve existing}",
  "max_ttl_days": 7,
  "domains": {
    "core-config": { "cached_at": "{current if refreshed, preserved if not}" },
    "ecosystem": { "cached_at": "{current if refreshed, preserved if not}" },
    "optimization": { "cached_at": "{current if refreshed, preserved if not}" }
  }
}
```

**Why**: Only update top-level `claude_code_version` and `cached_at` when all domains are refreshed. Partial refreshes preserve these fields so non-refreshed domains aren't incorrectly marked fresh by a version match.

## Step 4: Output Domain Content

Read each domain's cache file and output it in this format:

```
=== CLAUDIT KNOWLEDGE: {domain} ===

{content of the cache file}

=== END CLAUDIT KNOWLEDGE ===
```

Repeat for each requested domain.

After all domains, output a metadata summary:

```
Knowledge source: {source} | Domains: {list}
```

Where `{source}` is one of:
- `cache (fresh, fetched {date})` — if all domains were already fresh
- `refreshed ({list of refreshed domains} were stale)` — if any domains needed refresh
- `freshly populated (no prior cache)` — if cache was missing entirely
