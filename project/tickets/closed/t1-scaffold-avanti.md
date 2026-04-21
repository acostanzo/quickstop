---
id: t1
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# T1 — Scaffold plugins/avanti/

## Context

First ticket of avanti Phase 1. Bring the plugin into existence with correct directory shape, a parseable `plugin.json`, and marketplace registration so the rest of Phase 1 has a home to land in.

## What landed

- `plugins/avanti/.claude-plugin/plugin.json` — v0.1.0, standard author block matching sibling plugins, `pronto` extension block declaring the `project-record` audit at `weight_hint: 0.05` and `command: "/avanti:audit --json"` (the backing skill ships in T10).
- `plugins/avanti/README.md` — minimal stub covering role, skill surface, and installation. T11 will finalize alongside the thresholds reference.
- `.claude-plugin/marketplace.json` — avanti registered with source `./plugins/avanti` and matching keywords.
- Root `README.md` — avanti section added alongside the other plugin entries.

## Acceptance

- `plugins/avanti/.claude-plugin/plugin.json` parses as valid JSON (verified).
- `.claude-plugin/marketplace.json` parses as valid JSON (verified).
- Directory shape matches sibling plugins: `.claude-plugin/`, `README.md`, plus skills/references/templates directories created on demand as T2-T10 populate them.
- `/reload-plugins` and `claude --plugin-dir plugins/avanti` cleanroom load deferred to A1 (fresh-machine acceptance bar).

## Notes

Scaffolded following smith's convention by hand rather than running `/smith` interactively — the plan's requirements are fully specified, and smith's AskUserQuestion flow is optimized for human operators rather than a batch execution session. Output shape matches what smith would produce.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
