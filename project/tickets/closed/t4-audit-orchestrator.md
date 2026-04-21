---
id: t4
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T4 — /pronto:audit orchestrator + per-sibling parsers

## Context

The largest Phase 1 ticket. Four artifacts:

- `plugins/pronto/skills/audit/SKILL.md` — the orchestrator. Reads rubric, loads recommendations, discovers installed siblings, runs kernel-check, delegates per-dimension to sibling natives or parser agents, falls back to presence checks, aggregates into composite, emits markdown scorecard or JSON.
- `plugins/pronto/agents/parsers/claudit.md` — parser for claude-code-config.
- `plugins/pronto/agents/parsers/skillet.md` — parser for skills-quality.
- `plugins/pronto/agents/parsers/commventional.md` — parser for commit-hygiene.

## Phase 1 reality: parsers do the audit

None of the three sibling plugins (claudit, skillet, commventional) currently ships a `plugin.json` `pronto.audits` declaration or a `--json` output. Retrofitting is tracked in their own work, not here. So the parsers in this ticket are **lightweight depth auditors** that read repo state directly and emit contract JSON. Glue.

Specifically, parsers do NOT shell to the sibling's interactive audit command — running `/claudit` inside `/pronto:audit` would be disruptive and unreliable. Parsers are self-contained. When siblings ship native contract support, pronto's discovery picks them up and these parsers are removed in a minor version bump.

## Acceptance

- `skills/audit/SKILL.md` — frontmatter (name, description, disable-model-invocation, argument-hint `[--json]`, allowed-tools Task/Read/Glob/Grep/Bash/Write). Seven phases: resolve env → load registries → discover siblings → kernel-check → per-dim scoring → aggregate → emit + persist.
- Per-dimension scoring decision tree covers all four source enums from `report-format.md`: `sibling`, `kernel-presence-cap`, `presence-fail`, `kernel-owned`.
- Presence fallback logic for the four semantic dimensions (skills-quality via SKILL.md glob, commit-hygiene via 20-commit regex, lint-posture via config-file glob, event-emission via source-tree grep) — orchestrator-owned, not kernel-owned.
- Persists composite + per-dimension state to `${REPO_ROOT}/.pronto/state.json` for `/pronto:status` and `/pronto:improve` consumption.
- Three parser agents: each scopes a narrow slice of its sibling's rubric (claudit 6 cats at 20/20/15/15/15/15, skillet 6 cats at 20/20/15/15/15/15, commventional 3 cats at 50/30/20), reads repo state directly, emits contract-shape JSON, returns JSON only with no prose.
- All files portable — zero matches against the author-string grep.

## Decisions recorded

- **Parsers read repo state directly.** Not "parse sibling's stdout"; that sibling stdout doesn't exist in Phase 1. Parsers are functional reimplementations of narrow audit slices. The contract says this is glue; the glue is load-bearing in Phase 1.
- **Orchestrator stays read-mostly.** Only writes `${REPO_ROOT}/.pronto/state.json`. No fix application, no in-conversation mutations outside state. Fix behavior belongs to `/pronto:improve` (T8).
- **Parallel dispatch where safe.** Parsers can run concurrently (they don't contend). The orchestrator's perf target is <5s full run with all three siblings installed; parsers budget ≤2s each.
- **Discovery is registry-first, not hardcoded.** Orchestrator reads `plugin.json` for every discovered plugin and respects `pronto.audits` declarations. If a third-party plugin declares the contract, pronto picks it up without code change. Hardcoded parsers only apply to the three first-party siblings.
- **Source enum `kernel-owned` only for `agents-md`.** The `project-record` dimension is `kernel-presence-cap`/`presence-fail` until avanti ships — then it switches to `sibling`. This matches the plan's Phase 1b transition.
- **Parser model is `haiku`.** Fast, cheap — these are narrow, deterministic tasks. Matches skillet/claudit research-agent conventions.
- **Parser dispatch via `subagent_type` names prefixed with the plugin namespace.** `pronto:parse-claudit`, `pronto:parse-skillet`, `pronto:parse-commventional`. Claude Code's plugin-agent resolution uses the plugin-name:agent-name convention.
