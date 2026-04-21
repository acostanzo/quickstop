---
id: t12
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T12 — Research integration

## Context

Two artifacts:

- `plugins/pronto/references/research-integration.md` — the cache-consumption protocol documenting how pronto consumes claudit's `~/.cache/claudit/` (ecosystem domain only, preferred access via `/claudit:knowledge ecosystem`, invalidation deferred entirely to claudit's three-check scheme, cold-cache first-run behavior, graceful degradation when claudit isn't installed).
- A new `Phase 2.5: Load expert context (optional)` section in `plugins/pronto/skills/audit/SKILL.md` — invokes `/claudit:knowledge ecosystem` when claudit is installed, stores the output as EXPERT_CONTEXT, passes it to parser agents in Phase 4 dispatch prompts. Fallback is "no expert context" (empty string; note in `sibling_integration_notes`).

## Acceptance

- Audit orchestrator's Phase 2.5 wraps `/claudit:knowledge ecosystem` with three branches: (a) claudit installed + skill succeeds → EXPERT_CONTEXT populated; (b) claudit installed + skill fails → EXPERT_CONTEXT empty + integration note; (c) claudit not installed → EXPERT_CONTEXT empty + integration note; no fallback research agents.
- `references/research-integration.md` covers: cache location + shape, manifest schema, consumer pattern inside /pronto:audit, EXPERT_CONTEXT propagation to parsers, invalidation semantics (deferred to claudit), first-run cold-cache behavior, no-claudit fallback, refresh commands.
- README linked to the new reference.
- Cold-cache + warm-cache behavior documented: first run dispatches claudit's research agent (10–30s one-time), subsequent runs are cache-hits until TTL or version triggers invalidation.

## Decisions recorded

- **Ecosystem domain only.** Pronto doesn't need core-config or optimization — the audit rubric is sibling-delegated, not best-practice-derived. Ecosystem knowledge informs parser findings (what Claude Code features exist to check against) without pronto consuming the full claudit knowledge surface.
- **No pronto-side research agents.** When claudit is absent, pronto degrades to deterministic-parser-only scoring. We do not duplicate claudit's research surface; the correct remediation is installing claudit. This is consistent with pronto's meta-orchestrator identity — sibling work is sibling work.
- **Invalidation deferred.** Pronto doesn't implement its own cache-check protocol. `/claudit:knowledge ecosystem` handles freshness internally; pronto just invokes and trusts. Less code, less duplication, less drift.
- **EXPERT_CONTEXT is supplement, not source of truth.** Scoring rules (category weights, deduction tables) stay in pronto's rubric. Context informs finding quality (e.g., parsers reference specific best-practices by name in `findings[].message`) without changing the arithmetic.
- **First-run cost is visible.** The 10–30s cold-cache populate is documented as a one-time cost, not absorbed silently. Users see "refreshing knowledge cache (ecosystem)" via claudit's pass-through.
