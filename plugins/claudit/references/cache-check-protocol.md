# Claudit Knowledge Cache Check Protocol

This reference defines the standard procedure for checking the claudit knowledge cache. Any agent task that wants current Claude Code knowledge — building a skill, configuring an MCP, authoring CLAUDE.md, debugging hooks — can read the cache via `/claudit:knowledge` instead of re-fetching docs. The protocol below is what `/claudit` itself uses internally; external consumers should normally just invoke `/claudit:knowledge` and let it apply the protocol.

## Cache Location

```
~/.cache/claudit/
├── manifest.json          # version, timestamps, invalidation metadata
├── core-config.md         # core configuration knowledge
├── ecosystem.md           # ecosystem knowledge (MCP, hooks, skills, agents, plugins)
└── optimization.md        # optimization and over-engineering knowledge
```

## Manifest Schema

```json
{
  "claude_code_version": "2.1.81",
  "cached_at": "2026-03-23T14:30:00Z",
  "max_ttl_days": 7,
  "domains": {
    "core-config": { "cached_at": "2026-03-23T14:30:00Z" },
    "ecosystem": { "cached_at": "2026-03-23T14:30:00Z" },
    "optimization": { "cached_at": "2026-03-23T14:30:00Z" }
  }
}
```

## Cache Check Procedure

To determine if the cache (or a specific domain) is fresh:

1. Run via Bash: `claude --version 2>/dev/null` → store as **CURRENT_VERSION**
2. Run via Bash: `cat ~/.cache/claudit/manifest.json 2>/dev/null`
3. If the manifest does not exist → **MISSING** (no cache available)
4. If the manifest exists, apply **three-check invalidation**:
   a. **Version check**: Compare the manifest's `claude_code_version` to CURRENT_VERSION. If different → **STALE**.
   b. **Per-domain time check**: For each domain you need, check that domain's `cached_at` (inside `domains`). Compute its age vs the current date. If age >= `max_ttl_days` (default 7 days) → that domain is **STALE**.
   c. **File check**: Verify the required cache `.md` file(s) exist on disk. If any needed file is missing → **STALE**.
5. Cache is **FRESH** only if all three checks pass for every domain you need.

**Important**: Always check per-domain `cached_at` timestamps (not the top-level `cached_at`), because partial refreshes may update some domains but not others.

## Cache Write Procedure

After research agents return, persist the refreshed domains and update the manifest. This is the single source of truth for cache writes — both `/claudit:refresh` and `/claudit:knowledge` (when auto-refreshing) follow it.

Given **CURRENT_VERSION** (from `claude --version`) and the set of **refreshed domains**:

1. For each refreshed domain, write the agent's results to its cache file via the Write tool:
   - `~/.cache/claudit/core-config.md`
   - `~/.cache/claudit/ecosystem.md`
   - `~/.cache/claudit/optimization.md`
2. Read the existing `~/.cache/claudit/manifest.json` (if any) to preserve timestamps for domains that were **not** refreshed.
3. Write `~/.cache/claudit/manifest.json`:
   - Set each refreshed domain's `cached_at` to the current timestamp; preserve the rest.
   - Update the top-level `claude_code_version` and `cached_at` **only when all three domains were refreshed** (via `all` or all three named); otherwise preserve the existing top-level values.

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

**Why**: Consumers check per-domain `cached_at` for TTL and the top-level `claude_code_version` for version invalidation. Updating those top-level fields on a partial refresh would incorrectly mark non-refreshed domains as fresh.

## Preferred Interface: `/claudit:knowledge`

The `/claudit:knowledge [domain ...]` skill is the preferred way to access the cache. It handles freshness checks, auto-refreshes stale domains, and outputs content in a standard format. Consumers should invoke this skill rather than inlining the protocol below.

If claudit is not installed, consumers should fall back to their own research agents.

## Domain Quick Reference

| Domain | Covers |
|---|---|
| `core-config` | Settings, permissions, CLAUDE.md, memory system. |
| `ecosystem` | MCP servers, plugins, hooks, skills, sub-agents. |
| `optimization` | Performance patterns, over-engineering detection. |

A skill or agent task building against Claude Code's plugin / skill / agent / hook surface typically wants `ecosystem`. A task editing CLAUDE.md or configuring permissions wants `core-config`. A task tightening an existing config for performance wants `optimization`. `all` returns every domain. The audit (`/claudit`) reads `all`.
