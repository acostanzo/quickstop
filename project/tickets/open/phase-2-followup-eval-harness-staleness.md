---
id: phase-2-followup-eval-harness-staleness
plan: phase-2-pronto
status: open
updated: 2026-05-03
---

# Phase 2 follow-up — eval harness fixture pin is stale; investigate pronto's sibling-dispatch behaviour against pre-Phase-2 fixtures

## Scope

Surfaced during the Phase 2 acceptance bar verification on 2026-05-02 (smoke run N=3 against the canonical `mid` fixture). The hard acceptance bars are met (composite stddev=0, grade flip 0%, JSON-emission 100%) — this ticket addresses an orthogonal finding that does **not** gate Phase 2 closure but warrants follow-up.

The `mid` fixture in `plugins/pronto/tests/fixtures.json` pins quickstop at sha `7650b49ec9828494f066ec56682a8b653791bfcc` — the Phase 1.5 PR 2 merge, dated 2026-04-24. That predates the entire Phase 2 sibling track (inkwell/lintguini/towncrier shipped 2026-05-01 → 2026-05-02). When the harness checks out the fixture worktree at that sha, the worktree's own `plugins/pronto/references/recommendations.json` reflects the *old* Phase-2-plus posture: inkwell tagged "Phase 2+", lintguini tagged "Phase 2+", event-emission still recommends "autopompa" (the deprecated name retired in PR #80).

## What the smoke surfaced

Pronto's audit ran 3× against the fixture worktree, loading working-tree pronto + all three new siblings via `--plugin-dir`. Per-dimension results for the new dimensions:

| Dimension | Score | Source | Notes (verbatim from audit) |
|---|---|---|---|
| `code-documentation` | 50 | `kernel-presence-cap` | `inkwell not shipped (Phase 2+); README.md present with 108 non-blank lines; capped at 50` |
| `lint-posture` | 0 | `presence-fail` | `lintguini not shipped (Phase 2+); no language-appropriate lint config file detected` |
| `event-emission` | 50 | `kernel-presence-cap` | `autopompa not shipped (Phase 2+); observability grep matched (towncrier plugin and related references); capped at 50` |

The audit's narrative ("autopompa not shipped", "Phase 2+") matches the *fixture's* old `plugins/pronto/references/recommendations.json`, **not** the harness-loaded one (which has the post-PR-#80 / post-PR-#82 shipped state with autopompa retired). The slash commands themselves work — direct invocation via `claude -p "/inkwell:audit --json" --plugin-dir plugins/inkwell` produces a valid v2 envelope with populated observations[]. The dispatch failure is upstream of slash-command resolution: pronto's audit decides the new siblings are Phase-2+ and skips Sub-path A entirely.

## Two hypotheses, both deserve investigation

1. **LLM path-confusion**: pronto's audit SKILL.md tells the LLM to read `${CLAUDE_PLUGIN_ROOT}/references/recommendations.json` (the harness-loaded path). The LLM may be using a relative-path shortcut that resolves against CWD (the fixture worktree) instead.

2. **CLAUDE_PLUGIN_ROOT collision**: when the audit target's working tree contains its own `plugins/pronto/` (which quickstop's monorepo always will), Claude Code's resolution of `${CLAUDE_PLUGIN_ROOT}` might pick the audit-target copy over the `--plugin-dir`-loaded one.

A small probe could distinguish: instrument the audit to echo which `recommendations.json` path it actually reads, run once. If it's reading from `${REPO_ROOT}/plugins/pronto/...`, hypothesis 2; if from `${CLAUDE_PLUGIN_ROOT}/plugins/pronto/...` but with stale content, hypothesis 1.

## Why this isn't a Phase 2 blocker

The Phase 2 acceptance bar (per `project/plans/active/phase-2-pronto.md`) measures variance and emission rate, not "every sibling dispatches against every historical fixture." The variance bar is met (stddev=0, well below ≤1.0). The emission bar is met (3/3 success, generalises trivially given the deterministic mechanical scoring path). Each new sibling has its own `snapshots.test.sh` covering dispatch correctness against its own fixtures (verified during 2a3/2b3/2c3 review passes — all PASS).

The dispatch issue surfaces only against fixtures that predate the new siblings — a quickstop-internal harness concern, not a real-world consumer concern. A consumer running `/pronto:audit` against their own current codebase loads pronto + all enabled siblings, with no fixture pin and no pre-Phase-2 plugins/pronto in their tree.

## Resolution paths

Two complementary fixes:

1. **Bump the `mid` fixture pin** to a current main sha (post-2c3-merge) so the fixture worktree contains the new sibling state. Future eval-harness runs see the new world. Cost: a one-line edit to `fixtures.json` plus a follow-up note in the harness README about why the pin moved. Trade-off: invalidates the historical pre/after-T5 baseline comparison that A2 captured against `7650b49`. Either accept the loss or add a separate `mid-historical` fixture for that baseline reference.

2. **Investigate and fix pronto's sibling-dispatch path**. Whichever hypothesis the probe surfaces, the long-term fix is making pronto's audit robust to fixtures whose own `plugins/pronto/` is older than the harness-loaded pronto. The cleanest shape is probably an explicit absolute-path read using `$CLAUDE_PLUGIN_ROOT` rather than relying on the LLM to substitute correctly.

## Acceptance

- The probe distinguishes hypotheses 1 vs 2.
- The fix lands such that pronto's audit, run from a session with `--plugin-dir <working-tree>/plugins/pronto`, reads recommendations.json from that loaded plugin regardless of what's in the audit target's `plugins/pronto/`.
- A re-run smoke against the `mid` fixture (current pin or bumped, doesn't matter) shows the new siblings dispatching via Sub-path A and producing real per-dimension scores.
- No regression on existing siblings (claudit/skillet/commventional via Sub-path B continue to dispatch correctly).

## References

- `project/plans/active/phase-2-pronto.md` — Phase 2 plan, acceptance bar.
- `project/tickets/closed/phase-1-5-a2-harness-proof.md` — A2 ticket; established the `mid` fixture pin.
- `plugins/pronto/skills/audit/SKILL.md` — audit dispatcher; the `${CLAUDE_PLUGIN_ROOT}` reads here are where the path resolution happens.
- `plugins/pronto/tests/eval.sh`, `plugins/pronto/tests/fixtures.json` — harness shape and fixture pin.
- ADR-005 §5 — discovery contract.
- Smoke evidence (until rotated): `/tmp/eval-phase2-smoke.json`, `/tmp/eval-phase2-smoke.log`, `/tmp/pronto-eval-runs.2XVqK2/run-*.stdout` on Batdev.
