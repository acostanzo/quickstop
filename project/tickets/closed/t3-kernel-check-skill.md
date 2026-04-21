---
id: t3
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T3 — Kernel presence-check skill

## Context

`plugins/pronto/skills/kernel-check/SKILL.md` — the kernel's non-delegable filesystem-existence auditor. Scans for AGENTS.md, project/ container (plus the four expected subdirs), .pronto/ tool state, .claude/ presence, README, LICENSE, .gitignore. Emits the sibling-audit contract shape with `plugin: "pronto-kernel"`, `dimension: "kernel"`, categories mapped binary (0 / 100) based on pass conditions. The orchestrator (T4) consumes these per-category scores to fill in presence-check fallback when a sibling is absent.

Scope-control decision: the kernel-check does **only filesystem-existence checks**. Semantic presence checks (≥1 SKILL.md scan for `skills-quality`, regex over git log for `commit-hygiene`, lint-config detection for `lint-posture`, observability grep for `event-emission`) belong to the orchestrator in T4. T3 restricts itself to the seven checks the plan enumerates as "non-delegable."

## Acceptance

Three-fixture check exercised by hand before commit:

| Fixture | Setup | Expected composite |
|---|---|---|
| Bare repo | `mktemp -d && git init` | 0 (F) — all checks fail |
| Pronto-init'd repo | bare + AGENTS.md + `project/{plans,tickets,adrs,pulse}/` + `.pronto/state.json` + `.claude/` + README + LICENSE + .gitignore | 100 (A+) — all pass |
| Mid-execution quickstop-pronto | current worktree | 55 (D) — `.claude`/README/LICENSE/`.gitignore` pass; AGENTS.md/project-record/tool-state fail; project/adrs missing pending T-DoD |

Scan Bash was exercised against all three and matched the arithmetic. Skill frontmatter: `name: kernel-check`, `description`, `disable-model-invocation: true`, `argument-hint: "[--json]"`, `allowed-tools: Read, Glob, Bash`. Slash invocation is `/pronto:kernel-check` per plugin namespacing. JSON output shape matches `references/sibling-audit-contract.md`; the orchestrator-facing category-to-dimension map is documented inline.

## Decisions recorded

- Kernel-check ships a **single** JSON emission per run with `dimension: "kernel"`, not one emission per rubric dimension. The orchestrator extracts per-category scores and applies rubric weights + the presence cap (50) itself. Keeps the kernel skill simple; keeps all rubric semantics in the orchestrator.
- Non-blank-line thresholds (AGENTS.md >=5, README >=10, LICENSE >=1, .gitignore >=1) use `wc -l` for simplicity. These are lenient sanity checks, not precise thresholds — blank-padded edge cases are not worth dedicated handling.
- All kernel failures share one recommendation: `/pronto:init`. Single entry point for scaffolding; no per-artifact install commands at kernel level.
- Kernel categories that don't map to rubric dimensions (`Tool-state (.pronto/)`, `LICENSE`, `.gitignore`) surface as kernel-health recommendations only — they don't contribute to the composite readiness score the orchestrator computes.
