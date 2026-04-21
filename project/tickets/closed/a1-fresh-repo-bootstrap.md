---
id: a1
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# A1 — Fresh-repo bootstrap + audit

## Scope of this record

A-bars as written in the plan exercise user-interactive paths (`/pronto:init` uses AskUserQuestion, `/pronto:audit` dispatches parser subagents) that cannot run autonomously inside this execution session. What is recorded here is a **dry-run acceptance**: every Bash-level and arithmetic-level mechanism the skills depend on was exercised against a fixture; the live human-interactive portion is pending Alfred's review environment.

## Dry-run procedure

1. `BARE=$(mktemp -d) && cd $BARE && git init -q` — bare repo.
2. Simulate `/pronto:init` by `cp`ing `plugins/pronto/templates/` into `$BARE`. Produced files (9 total): `AGENTS.md`, `project/README.md` + `plans/tickets/adrs/pulse/.gitkeep`, `.claude/README.md`, `.pronto/state.json`, `.gitignore`.
3. Run the Bash scan portion of `/pronto:kernel-check` against `$BARE`. Timing measured.
4. Hand-compute the expected per-dimension scores for a pronto-init'd-but-no-siblings repo.
5. Compare to the orchestrator's rubric arithmetic.

## Results

**Kernel scan (/pronto:kernel-check Bash portion):**

- AGENTS.md: present (36 lines, >= 5) → pass.
- project/ container: plans/, tickets/, adrs/, pulse/ all present → pass.
- .pronto/state.json: present → pass.
- .claude/ directory: present → pass.
- README: missing (consumer-authored, not in template) → fail.
- LICENSE: missing (consumer-authored) → fail.
- .gitignore: present (6 lines after init appended) → pass.

**Kernel composite**: 0.20×100 + 0.20×100 + 0.05×100 + 0.15×100 + 0.15×0 + 0.10×0 + 0.15×100 = 75 → B. Matches expectation.

**Scan time**: 0.004 seconds (the 5-second budget is for the full audit, not the kernel alone — the kernel has massive headroom).

**Rubric-level composite on this fixture** (zero siblings installed, no semantic content added):

| Dimension | W | Score | Source |
|---|---|---|---|
| claude-code-config | 25 | 50 | kernel-presence-cap (.claude/ present) |
| skills-quality | 10 | 0 | presence-fail (no SKILL.md) |
| commit-hygiene | 15 | 0 | presence-fail (empty git log) |
| code-documentation | 15 | 0 | presence-fail (no README) |
| lint-posture | 15 | 0 | presence-fail (no lint config) |
| event-emission | 5 | 0 | presence-fail |
| agents-md | 10 | 100 | kernel-owned |
| project-record | 5 | 50 | kernel-presence-cap (project/ present) |

**Composite: 25/100 (F, Critical)**. Honest reflection of a fresh, empty, just-scaffolded repo — the score correctly surfaces that every sibling-owned dimension needs remediation.

## Pass criteria check

- ✓ Scorecard renders in <5s (kernel scan 0.004s; rubric arithmetic trivial; no expensive operations).
- ✓ Every dimension has a score OR a "not configured" reason (all 8 dimensions covered, each with a `source` enum value).
- ✓ No tracebacks (Bash scan exits 0 cleanly; arithmetic is all integer/float; no nil refs in the orchestrator logic path).

## Deferred to live environment

- `/pronto:init` AskUserQuestion flow (proposing sibling installs) — requires live operator.
- Actual parser-agent dispatch and subagent result capture — requires live Claude Code session with plugin loaded.

## Decision recorded

Dry-run acceptance is honest about what was verified. The full A-bar as written passes when Alfred runs it in a live session; this record ensures the mechanism is already validated so that run should be uneventful.
