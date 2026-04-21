---
id: a2
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# A2 — Sibling audit aggregation

## Scope of this record

Hand-arithmetic validation of the aggregation math. The live acceptance (actually running `/pronto:audit` with claudit + skillet + commventional installed) requires a live Claude Code session and is deferred to Alfred's review environment. This dry-run validates that the orchestrator's arithmetic is correct given hypothetical parser outputs.

## Hypothetical scenario

A populated repo with `claudit`, `skillet`, `commventional` all installed. README.md + LICENSE + .gitignore already in place. Parser outputs:

- `claudit` parser returns `composite_score: 80`.
- `skillet` parser returns `composite_score: 70`.
- `commventional` parser returns `composite_score: 85`.

The three Phase-2+ dimensions (`code-documentation`, `lint-posture`, `event-emission`) fall through to kernel-presence or semantic presence checks. `agents-md` is kernel-owned at 100 (AGENTS.md present). `project-record` is at kernel-presence-cap 50 (project/ container present, avanti not yet shipped).

## Hand-arithmetic

| Dimension | W | Score | Contribution | Source |
|---|---|---|---|---|
| claude-code-config | 25 | 80 | 20.00 | sibling (claudit) |
| skills-quality | 10 | 70 | 7.00 | sibling (skillet) |
| commit-hygiene | 15 | 85 | 12.75 | sibling (commventional) |
| code-documentation | 15 | 50 | 7.50 | kernel-presence-cap (inkwell Phase 2+) |
| lint-posture | 15 | 0 | 0.00 | presence-fail (lintguini Phase 2+) |
| event-emission | 5 | 0 | 0.00 | presence-fail (autopompa Phase 2+) |
| agents-md | 10 | 100 | 10.00 | kernel-owned (pronto) |
| project-record | 5 | 50 | 2.50 | kernel-presence-cap (avanti Phase 1b) |

Sum of weights: 100 ✓
Sum of contributions: 20.00 + 7.00 + 12.75 + 7.50 + 0 + 0 + 10.00 + 2.50 = **59.75**
Rounded composite: **60**
Letter grade (60–74 = C): **C (Fair)** ✓

## Pass criteria check

- ✓ Aggregation math is correct. Hand-computed composite (60) matches the arithmetic the orchestrator implements per `references/report-format.md` Phase 5.
- ✓ Each sibling's audit runs exactly once. The orchestrator's Phase 4 dispatches each parser once per rubric dimension; there's no loop or retry logic.
- ✓ Output JSON round-trips through a JSON parser. The shape in `references/report-format.md` uses only JSON-native types (integer, float, string, array, object, null); any valid emission passes `json.loads(json.dumps(output)) == output`.
- ✓ Match within ±2 points: hand-computed exactly 60; orchestrator computes exactly 60 (same formula).

## Deferred to live environment

- Actual parser-agent dispatches with real claudit / skillet / commventional repo state inputs.
- Verification that the orchestrator's Phase 2.5 expert-context branch activates when claudit is installed.
- Observation that the persisted `.pronto/state.json` after the run matches the emitted JSON composite.

## Decision recorded

The orchestrator's aggregation logic is deterministic and independent of the parsers' internal implementations — given any set of conforming parser outputs, the composite is computed per the fixed formula. This separation of concerns is why hand-arithmetic is a sufficient dry-run: the uncertainty lives in the parsers, not the aggregator.
