# Research Integration

Pronto consumes cached Anthropic documentation via the **claudit knowledge cache** rather than fetching docs fresh on every audit. This document covers the consumption protocol, cache lifecycle, and fallback semantics when claudit isn't installed.

## Why cache consumption

Pronto's audit orchestrator and its parser agents benefit from current Claude Code ecosystem knowledge (MCP, hooks, skills, subagents, plugins) when scoring edge cases. Without a shared cache, each skill would fetch Anthropic docs on every run — slow, costly, and rate-limit-sensitive.

Claudit already owns the cache. Pronto is a consumer. Net effect: one cache-miss populates all downstream tools; subsequent runs across pronto, claudit, skillet, smith, and hone are cache-hits.

## Cache location and shape

Owned by claudit (see `plugins/claudit/references/cache-check-protocol.md`). Reproduced here for pronto-self-containment:

```
~/.cache/claudit/
├── manifest.json          # version, timestamps, invalidation metadata
├── core-config.md         # core configuration knowledge
├── ecosystem.md           # MCP, hooks, skills, agents, plugins
└── optimization.md        # optimization and over-engineering patterns
```

### Manifest schema

```json
{
  "claude_code_version": "2.1.81",
  "cached_at": "2026-04-21T18:00:00Z",
  "max_ttl_days": 7,
  "domains": {
    "core-config": { "cached_at": "2026-04-21T18:00:00Z" },
    "ecosystem": { "cached_at": "2026-04-21T18:00:00Z" },
    "optimization": { "cached_at": "2026-04-21T18:00:00Z" }
  }
}
```

## Pronto's cache consumption

Pronto uses the **ecosystem** domain only. It contains the knowledge relevant to the audit rubric's sibling-covered dimensions (Claude Code config, skills quality, hooks, plugins).

### Preferred access: `/claudit:knowledge ecosystem`

Always invoke claudit's knowledge skill — never inline the cache-check protocol. The skill handles freshness checks, auto-refreshes stale domains, and returns content wrapped in delimiters for easy identification:

```
=== CLAUDIT KNOWLEDGE: ecosystem ===
<cached research content>
=== END CLAUDIT KNOWLEDGE ===

Knowledge source: cache (fresh, fetched 2026-04-21) | Domains: ecosystem
```

### Consumer pattern inside `/pronto:audit`

```
Phase 2: Discover installed siblings
  → builds INSTALLED_SIBLINGS map

Phase 2.5: Load expert context
  if "claudit" in INSTALLED_SIBLINGS:
    invoke `/claudit:knowledge ecosystem`
    if returns expected delimiters:
      EXPERT_CONTEXT = content
    else:
      EXPERT_CONTEXT = ""
      note in sibling_integration_notes
  else:
    EXPERT_CONTEXT = ""
    (no fallback — pronto doesn't ship its own research agents)
```

### Passing EXPERT_CONTEXT to parsers

When dispatching parser agents in Phase 4, include EXPERT_CONTEXT in the dispatch prompt:

```
=== EXPERT CONTEXT (from claudit cache) ===
<ecosystem knowledge>
=== END EXPERT CONTEXT ===

Then the per-parser brief.
```

Parsers use EXPERT_CONTEXT as a supplement, not a replacement for their deterministic scoring. Scoring rules (category weights, deduction tables) are pronto's rubric decisions, not decisions derived from docs on each run. The context informs finding quality — e.g., the claudit parser can reference specific best-practices by name when emitting a `findings[]` entry.

## Invalidation semantics

Pronto defers entirely to claudit's three-check invalidation:

1. **Version check** — if the user's Claude Code version differs from the manifest's `claude_code_version`, every domain is stale.
2. **Per-domain time check** — each domain's `cached_at` is compared against `max_ttl_days` (7 days default). Older than that → stale.
3. **File check** — if a required `.md` file is absent, that domain is stale.

Pronto does not duplicate this logic. `/claudit:knowledge ecosystem` applies all three checks and auto-refreshes on its own.

## First-run / cold-cache behavior

On a fresh machine with claudit installed but its cache not yet populated:

1. First `/pronto:audit` invokes `/claudit:knowledge ecosystem`.
2. Claudit's knowledge skill detects a missing cache, dispatches its `research-ecosystem` agent, writes `~/.cache/claudit/ecosystem.md`, and returns the populated content.
3. Pronto proceeds with EXPERT_CONTEXT populated — same code path as a warm cache.

The first run is slower (one research-agent dispatch; typically 10–30 seconds). Every subsequent run across any consumer (pronto, claudit, skillet, smith, hone) is a cache hit until the cache goes stale.

## When claudit is not installed

Pronto's fallback is "no expert context." Parsers run with their deterministic scoring logic alone. The audit completes — it's degraded, not broken.

The audit report surfaces this in `sibling_integration_notes`:

```
expert context unavailable (install claudit for research-informed audit depth)
```

Pronto does not ship its own research agents. If ecosystem docs are needed and claudit isn't installed, the right move is to install claudit — not to duplicate its research surface in pronto.

## Cache refresh from outside pronto

Consumers can explicitly refresh:

- `/claudit:refresh [domain]` — forces a refresh regardless of TTL.
- `/claudit:status` — shows current cache freshness per domain.

Pronto's audit will pick up refreshed cache on the next run; there's no pronto-side refresh command.

## Summary

- **Cache owner**: claudit.
- **Consumer**: pronto's `/pronto:audit` via `/claudit:knowledge ecosystem`.
- **Invalidation**: claudit's three-check protocol (version + per-domain TTL + file existence); no pronto-side duplication.
- **Cold cache**: populated on first invocation; ~10–30s one-time cost.
- **Claudit absent**: degraded-but-complete audit; surfaced in integration notes.
- **Refresh**: via `/claudit:refresh`, not pronto.
