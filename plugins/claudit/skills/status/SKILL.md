---
name: status
description: Show claudit knowledge cache status — freshness, TTL, and domain coverage
disable-model-invocation: true
allowed-tools: Read, Bash
---

# Claudit: Knowledge Cache Status

You are the claudit cache status reporter. When the user runs `/claudit:status`, display the current state of the knowledge cache.

## Step 1: Get Current Version

Run via Bash: `claude --version 2>/dev/null` → store as **CURRENT_VERSION**

## Step 2: Read Manifest

Read `~/.cache/claudit/manifest.json`.

**If the file does not exist** (Read returns an error):

```
╔══════════════════════════════════════════════════╗
║         CLAUDIT KNOWLEDGE CACHE                  ║
╠══════════════════════════════════════════════════╣

No knowledge cache found.

Run /claudit:refresh or /claudit to populate the cache.

The knowledge cache speeds up repeated audits and provides
expert context to /skillet, /smith, and /hone.
╚══════════════════════════════════════════════════╝
```

Stop here.

## Step 3: Compute Freshness

Parse the manifest JSON and compute:

1. **Version match**: Compare `claude_code_version` in manifest to CURRENT_VERSION
   - Match → `✓ matches`
   - Mismatch → `✗ stale (cached: {old}, current: {new})`

2. **Per-domain TTL**: For each domain in `domains`, compute:
   - Age = current date minus domain's `cached_at`
   - TTL remaining = `max_ttl_days` minus age (in days and hours)
   - If TTL remaining <= 0 → `expired`

3. **Overall status**: Cache is **FRESH** if version matches AND all domains have TTL remaining > 0. Otherwise **STALE**.

## Step 4: Verify Domain Files

For each domain, check if the corresponding cache file exists:
- `~/.cache/claudit/core-config.md`
- `~/.cache/claudit/ecosystem.md`
- `~/.cache/claudit/optimization.md`

Run via Bash: `ls -la ~/.cache/claudit/*.md 2>/dev/null` to get file sizes.

## Step 5: Display Status

```
╔══════════════════════════════════════════════════╗
║         CLAUDIT KNOWLEDGE CACHE                  ║
╠══════════════════════════════════════════════════╣

Status:      {FRESH or STALE}
Claude Code: v{CURRENT_VERSION} ({version match status})

Domain             Cached            TTL Left     File
core-config        {date}            {Xd Xh}      {size or MISSING}
ecosystem          {date}            {Xd Xh}      {size or MISSING}
optimization       {date}            {Xd Xh}      {size or MISSING}

Max TTL: {max_ttl_days} days | Cache: ~/.cache/claudit/
╚══════════════════════════════════════════════════╝
```

If STALE, add:

```
Cache will be refreshed on the next /claudit run.
To refresh now: /claudit:refresh
```

If FRESH, add:

```
Consumers use /claudit:knowledge to access this cache.
Direct consumers: /claudit, /skillet:*, /smith, /hone
```
