---
id: t5
plan: phase-1-5-pronto
status: closed
updated: 2026-04-24
---

# T5 — Mechanize the scoreable dimensions (variance reduction)

## What landed

Two atomic commits on branch `feat/pronto-phase-1-5-pr3b-mechanize`:

- `18c379c feat(pronto): mechanize scoreable dimensions` — the T5 change.
- `1f93185 docs(pronto): document rubric mechanical/judgment split` — the T5 doc deliverable.

A follow-up refactor (`1d348fe refactor(pronto): extract audit presence
checks to helper script`) refines the mechanization by pulling the inline
presence Bash out of `SKILL.md` into a helper script. Same semantics;
reduces sub-Claude spec surface to reduce the stub-emission failure mode
that pre-existed the mechanization.

## Scope of the mechanization

Every score path in pronto's audit is now deterministic shell code. No
LLM judgment participates in any rubric scoring.

### Parser-owned dimensions (were fuzzy; now mechanical)

| Dimension | Weight | Mechanization |
|---|---:|---|
| `claude-code-config` | 25 | `plugins/pronto/agents/parsers/scorers/score-claudit.sh` — shell scorer with `nblines`, hook counts via `jq`, fixed regex set for "prose restating built-in", explicit MCP-server reachability check, aggregate-instruction-line count. |
| `skills-quality` | 10 | `plugins/pronto/agents/parsers/scorers/score-skillet.sh` — per-`SKILL.md` frontmatter field presence, line-count thresholds, `TODO` counts, stray-file detection, broken `references/` pointer detection with plugin-level fallback resolution. |
| `commit-hygiene` | 15 | `plugins/pronto/agents/parsers/scorers/score-commventional.sh` — `git log --no-merges -n 50` regex match ratios, auto-trailer counts, "Generated with Claude Code" counts. Conventional Comments defaults to 100 (network-free); GitHub API variance no longer enters the score path. |

Determinism verified locally: `sha256sum` of each scorer's output over
three consecutive invocations against a fresh fixture worktree was
byte-identical in all three cases.

The three parser agents (`agents/parsers/{claudit,skillet,commventional}.md`)
are now thin Haiku wrappers: they execute the corresponding scorer
script with the dispatching prompt's `REPO_ROOT` and emit its stdout
verbatim. A refusal clause forbids interpreting, summarizing, or
"sanity-checking" the result.

### Orchestrator-owned presence fallbacks (were prose; now shell)

`plugins/pronto/skills/audit/SKILL.md` Phase 4.3 delegates each
presence-fallback dimension to a helper script:

```
${CLAUDE_PLUGIN_ROOT}/skills/audit/presence-check.sh <dimension> ${REPO_ROOT}
```

The script has subcommands for `skills-quality`, `commit-hygiene`,
`lint-posture`, and `event-emission`. Each uses a fixed canonical
invocation (`compgen -G`, `git log -20` regex ratio, explicit lint
config file list, `grep -rqE` with documented `--exclude-dir` set).
This kills the `event-emission` stddev=15.7 observed in the PR 3a
baseline (sub-Claude composing its own grep with different exclusions
per run) and centralizes the commands so future maintenance is one-file.

### Orchestrator math (was LLM arithmetic; now jq)

`SKILL.md` Phase 5 aggregation instructs the orchestrator to compute
weighted contributions and the composite via `jq`, not in its head.
`round(sum(x))` and `sum(round(x))` differ; leaving the math to an
LLM contributed ~1pt of composite stddev for free.

### Dimensions that were already mechanical

- `agents-md` (10) — kernel binary check. Unchanged.
- `project-record` (5) — avanti's native `/avanti:audit --json`
  declared in `plugins/avanti/.claude-plugin/plugin.json`. Unchanged.
- `code-documentation` (15) — kernel README check. Unchanged.

## Composite weight that is now mechanical

**100%.** All 100 weight points route through deterministic shell or
native-sibling JSON. The 70% target in the plan is comfortably
exceeded; no residual judgment dimension remains.

See `plugins/pronto/references/rubric.md` §"Mechanical vs judgment
split" for the per-dimension table and rationale.

## Acceptance

Threshold enforcement is A2's bar (`project/tickets/closed/phase-1-5-a2-harness-proof.md`),
not T5's. T5's deliverables:

- ✓ Per-dimension audit complete; classification recorded in `rubric.md`.
- ✓ ≥70% of composite weight on mechanical paths — actual: 100%.
- ✓ Three scorer scripts committed under `agents/parsers/scorers/`.
- ✓ Three parser agents rewritten as thin script wrappers.
- ✓ Orchestrator Phase 4.3 presence checks factored to a helper script; Phase 5 aggregation tightened to jq.
- ✓ Plugin version bumped (pronto 0.1.3 → 0.1.4) across `plugin.json`,
  `marketplace.json`, and `README.md`; `./scripts/check-plugin-versions.sh`
  passes.

## Links

- Plan: `project/plans/active/phase-1-5-pronto.md` (PR 3 / T5).
- Companion ticket: `project/tickets/closed/phase-1-5-a2-harness-proof.md` (before/after proof).
- Commits: `18c379c`, `1f93185`, `1d348fe`.
