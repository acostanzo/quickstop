---
id: t1
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T1 — Scaffold plugins/pronto/

## Context

First ticket of pronto Phase 1. Generates the plugin skeleton that subsequent tickets populate. Smith is interactive (requires user-facing AskUserQuestion responses) and cannot run autonomously in this session, so the skeleton was hand-authored against smith's template conventions and the sibling-plugin shape (claudit, skillet, commventional).

## Acceptance

- `plugins/pronto/.claude-plugin/plugin.json` — parses as valid JSON, author block matches sibling convention (`"name": "quickstop"`), empty `pronto.audits` extension block per plan, v0.1.0.
- `plugins/pronto/README.md` — plugin overview with command table and architecture block; extended with rubric + contract links in T2.
- `plugins/pronto/{skills,agents,references}/` — empty directories created; populated by T2–T12.
- Marketplace registration: entry added to `.claude-plugin/marketplace.json`; pronto section added to root `README.md` matching existing sibling format.
- Grep for author-specific strings (`anthony|batcomputer|batdev|batvault|alfred|grapple-gun|batctl|mind-palace`) inside `plugins/pronto/`: zero matches.

## Deviation from plan

Plan says "Run `smith` in quickstop to generate `plugins/pronto/`". Smith's Phase 2 uses `AskUserQuestion` throughout, which routes to the human operator. Since this session executes autonomously, the skeleton was produced manually against smith's output template. The resulting tree is identical in shape to what smith would have produced, with two intentional deviations:

1. `author.name` set to `"quickstop"` (matching claudit/skillet/commventional) rather than `"Anthony Costanzo"` (smith default) — required for the DoD grep check.
2. `pronto.audits` extension block included at scaffold time per plan directive, rather than being added in a later ticket.
