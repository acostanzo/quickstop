# Claudit Knowledge Cache Check Protocol

This reference defines the standard procedure for checking the claudit knowledge cache. All consumers (claudit, skillet, smith, hone) should follow this protocol for consistent behavior.

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

## Preferred Interface: `/claudit:knowledge`

The `/claudit:knowledge [domain ...]` skill is the preferred way to access the cache. It handles freshness checks, auto-refreshes stale domains, and outputs content in a standard format. Consumers should invoke this skill rather than inlining the protocol below.

If claudit is not installed, consumers should fall back to their own research agents.

## Consumer Quick Reference

| Consumer | Domains Needed | Access Method |
|----------|---------------|--------------|
| `/claudit` | core-config, ecosystem, optimization | `/claudit:knowledge all` |
| `/skillet:*` | ecosystem | `/claudit:knowledge ecosystem` with fallback |
| `/smith` | ecosystem | `/claudit:knowledge ecosystem` with fallback |
| `/hone` | ecosystem | `/claudit:knowledge ecosystem` with fallback |
