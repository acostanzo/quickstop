---
phase: 1.5
status: draft
tickets: [t1, t2, t3, t4, t5, a1, a2]
updated: 2026-04-21
---

# Pronto Phase 1.5 — Bugfix pass from live dogfood

## Why this phase exists

Phase 1 merged on 2026-04-21 and the first live dogfood of `/pronto:audit` (against `acostanzo/quickstop` itself) surfaced seven new findings that could not be observed in simulation. Four are shipped bugs: the audit's own JSON output violates its contract (N1/N2), SKILL.md documents wrong subagent names (N4), and — most seriously — the composite is **non-deterministic across runs** (N3: 55/D, 60/C, 57/D on the same commit `f4f7aec`). Additionally, `disable-model-invocation: true` on `claudit:knowledge` and `avanti:audit` blocks pronto's orchestrator from dispatching them as specified (A2+N5 — architectural).

Phase 2 (new siblings: inkwell, lintguini, autopompa) should not build on top of an orchestrator whose output is non-reproducible. This phase closes those bugs first. It is explicitly **not** new-feature work — pure debt repayment.

## Scope

Five tickets organized into three sequential PRs:

| PR | Tickets | Lands when |
|---|---|---|
| PR 1 — Mechanical cleanup | T1, T2, T3 | Reviewed and green |
| PR 2 — Orchestration dispatch | T4 (requires design call first) | After Alfred confirms the design decision |
| PR 3 — Determinism + eval harness | T5, A1, A2 | After PR 1 and PR 2 land |

PR 1 and PR 2 are small and mechanical/surgical. PR 3 is the real engineering — it splits internally into eval-harness work and variance-reduction work, both on the same branch, each as its own atomic commit, but shipped together so the harness validates the fix.

## Out of scope

- New sibling plugins (Phase 2).
- Rubric calibration items (B1-B5 from the dogfood findings). Those are tuning knobs, not bugs; handled in a separate pass after this one stabilizes the harness.
- UX polish items (C-series from dogfood findings). Same reason.
- Sibling-parser correctness (N6 — claudit parser's scope confusion on `settings.json`). This lives in the `claudit` plugin, not pronto; it'll be a separate fix in that plugin.

---

## PR 1 — Mechanical cleanup

### T1 — Strip prose and code fences from `/pronto:audit --json` output

**Bug (N1):** `/pronto:audit --json` emits:
```
Emitting the JSON composite per --json output mode.

```json
{...}
```

State persisted to .pronto/state.json. Composite 57/100...
```

53 chars of prose preamble + 299 chars of prose trailer + ` ```json ... ``` ` fences. The spec at `plugins/pronto/skills/audit/SKILL.md` Phase 6 and `plugins/pronto/references/report-format.md` say explicitly: "No prose, no markdown fences. All progress output goes to stderr."

**Fix:** the `--json` branch of the audit skill must emit **only** the composite JSON to stdout. Any progress, state-persistence notice, or prose goes to stderr or is suppressed. Verify by piping the raw stdout through `jq .` in CI.

**Acceptance:** `claude -p "/pronto:audit --json" 2>/dev/null | jq -e .composite` returns the composite integer with exit 0, on a repo where the audit succeeds. No fence, no prose.

### T2 — Strip code fences from `/avanti:audit --json` output

**Bug (N2):** `/avanti:audit --json` wraps the JSON in ` ```json ... ``` ` fences (no leading/trailing prose, but still non-compliant with `plugins/avanti/skills/audit/SKILL.md` Phase 4 "no prose preamble, no trailing lines").

**Fix:** same shape as T1 but narrower — only fences to remove, no prose to drop.

**Acceptance:** `claude -p "/avanti:audit --json" 2>/dev/null | jq -e .` parses without error.

### T3 — Correct subagent_type names in `audit/SKILL.md`

**Bug (N4):** `plugins/pronto/skills/audit/SKILL.md:116` documents the parser dispatch as:
```yaml
subagent_type: pronto:parse-claudit
subagent_type: pronto:parse-skillet
subagent_type: pronto:parse-commventional
```

Claude Code actually registers these agents with the `parsers/` subdirectory namespaced in:
```
pronto:parsers:parse-claudit
pronto:parsers:parse-skillet
pronto:parsers:parse-commventional
```

Visible in the stream-json init event's `agents` array. A literal follow of Phase 4.1 dispatches to an unknown agent.

**Fix:** correct the three strings in SKILL.md. Grep the rest of `plugins/pronto/` for the same pattern and fix any other occurrences. Run `/pronto:audit` to confirm parsers dispatch correctly (they already do in practice because the sub-Claude inferred the right name — this is a doc defect that becomes a real defect on any future literal re-implementation).

**Acceptance:** grep `plugins/pronto/` for `pronto:parse-` (without `parsers:`) returns zero matches. Audit runs end-to-end.

### PR 1 shape

- Branch: `fix/pronto-phase-1-5-pr1-output-hygiene`
- Three atomic commits, one per ticket (`fix(pronto):`, `fix(avanti):`, `docs(pronto):`)
- Rebase-and-merge to main

---

## PR 2 — Orchestration dispatch decision

### T4 — Remove or document `disable-model-invocation` on orchestration targets

**Bug (A2 + N5, architectural):** Two skills that pronto's audit orchestrator is specified to dispatch carry `disable-model-invocation: true` in their frontmatter:

1. `plugins/claudit/skills/knowledge/SKILL.md` — Phase 2.5 expert-context injection
2. `plugins/avanti/skills/audit/SKILL.md` — native project-record routing

When pronto's audit runs under a sub-Claude, the Skill tool refuses to dispatch skills declared non-model-invocable. Real dogfood runs confirm: the sub-Claude skipped `/claudit:knowledge` entirely and inlined avanti's scoring logic by hand because it couldn't dispatch `/avanti:audit`. The spec in `plugins/pronto/skills/audit/SKILL.md` describes these dispatches as part of the normal orchestration flow, but the flow cannot execute as written.

**Decision required (Alfred surfaces to Anthony before T4 starts):**

- **Option A — Remove `disable-model-invocation: true`** from both skills. Pro: pronto's spec executes as written; dispatch is direct; determinism improves (no free-form inlining). Con: `/claudit:knowledge` and `/avanti:audit` become usable from any agent context, not just direct user invocation. Review whether that's desired.
- **Option B — Keep `disable-model-invocation: true`** and rewrite pronto's spec to acknowledge that these sibling audits are **executed by pronto inline** (pronto's own skill contains the scoring logic) rather than dispatched. Pro: keeps the "these skills are user-facing, not tool-target" boundary. Con: pronto now has to own a copy of the scoring logic, which duplicates what the siblings know; drift risk.
- **Option C — Hybrid.** Leave `disable-model-invocation: true` on `claudit:knowledge` (it's genuinely user-facing expert context, not a scoring producer); remove it from `avanti:audit` (it's a pure scoring producer with a wire contract).

**Recommended:** Option C. `avanti:audit` is spec'd with `--json` output shape and a pronto wire contract — it's meant to be called by tools. `claudit:knowledge` is a "tell the user about the ecosystem" skill; its output is narrative, not structured, and pronto can live without it in Phase 1.5 (flag as a polish item for Phase 2).

**Fix (assuming Option C):**
1. Remove `disable-model-invocation: true` from `plugins/avanti/skills/audit/SKILL.md` frontmatter.
2. Update `plugins/pronto/skills/audit/SKILL.md` Phase 2.5 to note that `/claudit:knowledge` is intentionally not dispatched from the audit path — expert context is available via direct `/claudit:knowledge` invocation by the user.
3. Update `plugins/pronto/references/report-format.md` if it referenced the claudit:knowledge dispatch.
4. Re-run dogfood; confirm `sibling_integration_notes` no longer reports "avanti: invoked inline" or "expert context unavailable."

**Acceptance:** a fresh `/pronto:audit` run dispatches `/avanti:audit` via the Skill tool rather than inlining. `sibling_integration_notes` reflects direct dispatch. Composite includes avanti's score via wire contract, not fallback.

### PR 2 shape

- Branch: `fix/pronto-phase-1-5-pr2-orchestration-dispatch`
- Two atomic commits: (1) remove disable flag on avanti, (2) update pronto spec text + references
- Rebase-and-merge to main
- **Paused until Alfred confirms the design decision with Anthony**

---

## PR 3 — Determinism + eval harness

### T5 — Mechanize the scoreable dimensions (variance reduction)

**Bug (N3, in part):** parser-agent outputs vary run-to-run because they rely on LLM judgment for scores that should be mechanical. Real-run spread:

- claudit: 85 → 94 (9pt spread across 3 runs)
- skillet: 91 → 97 (6pt spread)
- project-record: 50 → 100 (50pt spread — one run routed to kernel-presence-cap)

**Fix shape (per-dimension audit):**

For each rubric dimension, classify scoring logic into:

- **Mechanical** — countable or regex-matchable (e.g., "number of files with JSDoc header," "presence of `.github/workflows/`," "commit-message regex matches conventional prefix"). Replace LLM judgment with a deterministic count/regex. Variance → 0.
- **Judgment** — genuinely fuzzy (e.g., "is this CLAUDE.md well-structured?"). Keep LLM in the loop but rewrite the parser agent prompt with a rigid output contract, tight score bands (e.g., 5-point granularity, not 100-point), and an explicit refusal clause for out-of-band output.

Deliverable: a pass through each of the 8 dimensions, with a per-dimension note in `plugins/pronto/references/rubric.md` describing which parts are mechanical vs judgment. Aim: ≥70% of composite weight comes from mechanical scoring.

**This is the variance-reduction lever that gives the biggest return.**

### A1 — Eval harness

**The measurement layer N3 needs.**

**Fixture:** a committed `plugins/pronto/tests/fixtures/` directory containing 2-3 bare reference repos as git submodules or vendored trees:
- `fixture-ideal/` — a hand-crafted repo that should score ~90/A
- `fixture-mid/` — the quickstop repo itself (known composite ~60/C)
- `fixture-empty/` — a bare repo that should score ~10/F

**Harness:** `plugins/pronto/tests/eval.sh` — runs `/pronto:audit --json` N times (default N=10) against each fixture, aggregates:

```
Fixture: fixture-mid
Runs: 10
Composite: mean=58.4 stddev=2.1 min=55 max=61
Grade: C×7 D×3 (grade-flip rate 30%)
Per-dimension:
  claudit-config: mean=92.1 stddev=3.4
  skills-quality: mean=94.5 stddev=2.1
  ... etc.

Pass criteria (configurable):
  composite stddev ≤ 1.0  → FAIL (2.1)
  grade-flip rate ≤ 5%    → FAIL (30%)
```

**Output:** stdout summary + `plugins/pronto/tests/eval-results.json` for tracking over time.

**Usage:**
- Run manually: `plugins/pronto/tests/eval.sh`
- Run in CI on every PR to `plugins/pronto/` or `plugins/{claudit,skillet,commventional,avanti}/` (sibling changes can affect pronto's scores).
- Track per-commit stddev in `plugins/pronto/tests/eval-history.ndjson` (append-only).

### A2 — Eval harness proves T5 worked

Run the harness before T5, record the baseline. Run after T5, record the improvement. The PR commit message body includes the numbers. If stddev on composite doesn't drop below 1.0 after T5, the PR isn't done — either iterate on T5 or document the residual variance and the cost of closing the remaining gap.

**Acceptance for PR 3:**
1. `plugins/pronto/tests/eval.sh` exists, runs, produces the summary + results JSON.
2. Baseline stddev recorded in PR commit body.
3. Post-T5 stddev ≤ 1.0 on composite; grade-flip rate ≤ 5% on the mid fixture.
4. Per-dimension table in `plugins/pronto/references/rubric.md` documents mechanical vs judgment split.

### PR 3 shape

- Branch: `fix/pronto-phase-1-5-pr3-determinism`
- Commits: (1) `test(pronto): add eval harness and fixtures`, (2) `feat(pronto): mechanize scoreable dimensions`, (3) `docs(pronto): document rubric mechanical/judgment split` (if separate from 2)
- Rebase-and-merge to main

---

## Definition of Done

- PRs #1, #2, #3 all merged to main.
- `plugins/pronto/tests/eval.sh` exists and passes its criteria.
- A fresh dogfood run against `acostanzo/quickstop` produces:
  - `--json` output that `jq` parses cleanly (N1/N2 closed).
  - Sibling dispatch notes showing avanti dispatched directly (N5 closed).
  - Composite stddev ≤ 1.0 across 10 back-to-back runs (N3 closed).
  - Subagent names in SKILL.md matching the registered names (N4 closed).
- `project/tickets/closed/phase-1-5-*.md` records for each T-ticket with executed evidence.
- `project/pulse/` entries for each PR landing.

## What NOT to do

- **No Phase 2 work.** New siblings stay on the backlog.
- **No rubric calibration tuning** (B1-B5 from dogfood). Separate pass.
- **No cross-plugin refactors.** The scope is pronto + two targeted sibling changes (avanti frontmatter, possibly claudit expert-context note). Anything wider is out of scope.
- **Do not skip the eval baseline recording.** The whole point is to have a before/after number. "I ran it and it seemed better" is not acceptable evidence.
- **Do not hand-wave on T5.** If a dimension is genuinely judgment-only, say so explicitly and document why it can't be mechanized; don't silently leave it fuzzy and claim the stddev gain came from elsewhere.

## Sequencing note

PR 1 is safe to start immediately — the fixes are mechanical and uncontroversial.
PR 2 requires Alfred's design-decision ping to Anthony first (Option A / B / C).
PR 3 waits on both: PR 2 because dispatch behavior affects the eval baseline; PR 1 because the harness parses `--json` output.

## Session execution

A single autonomous session on batdev executes all three PRs sequentially in a worktree at `~/projects/quickstop-pronto-phase-1-5/`. The session pauses between PRs to let Alfred review and merge, not just to let it rip end-to-end. Alfred's review at each merge point is the guardrail.

## First action (session)

1. Commit this plan to `project/plans/active/phase-1-5-pronto.md` as the first atomic commit on branch `fix/pronto-phase-1-5-pr1-output-hygiene`.
2. Execute T1, T2, T3.
3. Open PR 1.
4. Wait for Alfred merge signal before starting PR 2.
