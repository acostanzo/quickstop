---
name: refresh
description: Force-refresh claudit's cached Claude Code docs by re-fetching Anthropic documentation (spawns web-research agents, overwrites the local cache). Run only when the user explicitly asks to refresh the claudit cache.
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

Persist the refreshed domains and update the manifest by following the **Cache Write Procedure** in `${CLAUDE_PLUGIN_ROOT}/references/cache-check-protocol.md`, passing CURRENT_VERSION and the set of domains you refreshed in Step 4.

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
  any agent task  — building a skill, configuring an MCP, authoring
                    CLAUDE.md, etc. — can pull current Claude Code
                    knowledge from the cache instead of re-fetching
                    docs.
```
