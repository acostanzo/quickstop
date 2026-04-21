---
name: improve
description: Walk the weakest-scoring rubric dimensions from the last audit and offer per-dimension remediation (install recommended plugin, walk through roll-your-own, or skip)
disable-model-invocation: true
allowed-tools: Read, Glob, Bash, Write, Edit, AskUserQuestion
---

# Pronto: Improve

You are the Pronto improve skill. When the user runs `/pronto:improve`, walk the lowest-scoring rubric dimensions from the last audit and for each offer a coherent next step. Append a journal entry to today's pulse file after the interactive session.

## Phase 0: Resolve environment

1. **REPO_ROOT**: `git rev-parse --show-toplevel 2>/dev/null`. Abort if not a git repo.
2. **PLUGIN_ROOT**: `${CLAUDE_PLUGIN_ROOT}`.
3. **STATE_PATH**: `${REPO_ROOT}/.pronto/state.json`.
4. **TODAY**: `date -u +"%Y-%m-%d"` — UTC date for the pulse file.

## Phase 1: Load state

Read `${STATE_PATH}`:

- **File missing**: tell the user `/pronto:audit` hasn't run yet. Suggest running it and stop. Do not synthesize state from scratch.
- **File malformed**: tell the user the state is corrupt and suggest `/pronto:audit --json` to regenerate. Stop.
- **File valid**: parse into **STATE**.

## Phase 2: Load registries

1. `${PLUGIN_ROOT}/references/recommendations.json` → **RECS**.
2. Discover installed siblings the same way `/pronto:audit` and `/pronto:status` do.

## Phase 3: Rank dimensions

Build a ranked list of dimensions from STATE:

- Order ascending by `score`.
- Ties broken by descending `weight` (higher-weight dimensions surface first when scores are equal).
- Filter to dimensions where `score < 75` (B threshold) — dimensions already at B-or-better are "good enough" for this pass.
- Cap at the top 5 weakest for the interactive walk (avoids a long menu). The rest are mentioned in the summary for completeness.

If the filtered list is empty:

```
Every dimension is at B or better. No improvements queued.
Composite: <score>/100 (<grade>). Run /pronto:audit after repo changes to re-evaluate.
```

Stop (still append a "no improvements queued" pulse entry).

## Phase 4: Walk dimensions interactively

For each dimension in the ranked list, present the current state and offer choices.

### Per-dimension presentation

```
[Dimension <N>/<total>] <dimension_label> (<dimension_slug>)
  Current: <score>/100 — <source-description>
  Weight: <weight>
  Recommended sibling: <plugin-name> (<plugin_status>)
  Roll-your-own: references/roll-your-own/<slug>.md

Source description format:
  - sibling          → "sibling <plugin> scored <score>"
  - kernel-presence-cap → "kernel presence check passed; capped at 50 until <plugin> installed"
  - presence-fail    → "presence check failed"
  - kernel-owned     → "kernel check: <pass|fail>"
```

### Per-dimension options

Use AskUserQuestion with the following options. Omit options that don't apply.

**Option: Install recommended sibling** (only if `plugin_status == "shipped"` or `"phase-1b"`, AND sibling not already installed)

- Label: `Install <plugin-name>`
- Description: `Runs /plugin install <plugin-name>@quickstop. You'll re-run /pronto:audit after to pick up the depth score.`

**Option: Walk through roll-your-own** (always available)

- Label: `Walk roll-your-own — <dimension_slug>.md`
- Description: `Open references/roll-your-own/<slug>.md and walk the "Concrete first step" section together.`

**Option: Skip**

- Label: `Skip this dimension`
- Description: `Leave as-is; move to the next.`

**Option: Stop walking** (offered on every dimension after the first)

- Label: `Stop — I'll come back later`
- Description: `Exit the walk now. Remaining dimensions show in the summary.`

### Acting on the selection

**Install**: tell the user the install command and instruct Claude to run it in the main loop (`/plugin install <name>@quickstop`). After the install completes, note in the follow-up summary that the user should `/pronto:audit` to re-score.

**Walk roll-your-own**: Read `${PLUGIN_ROOT}/references/roll-your-own/<slug>.md`. Surface the "Concrete first step" section first, then the "Minimum viable setup" — these are the actionable pieces. If the user wants to act now, offer specific file-scaffolding help from the doc.

**Skip**: record the skip in the walk log, move on.

**Stop walking**: break out of the loop, emit summary for completed dimensions + mention of what's left.

## Phase 5: Append pulse entry

Write a pulse entry summarizing the walk to `${REPO_ROOT}/project/pulse/${TODAY}.md`. If the file doesn't exist:

```markdown
# Pulse — <TODAY>
```

Then append the entry:

```markdown
## <HH:MM> — /pronto:improve walk

Composite: <score>/100 (<grade>).

Dimensions walked (weakest first):
- <slug>: <action taken> (was <score>/100)
- <slug>: <action taken> (was <score>/100)
...

Siblings newly installed (if any): <list>
Roll-your-own walked (if any): <list>
Skipped: <list>
```

Where `<action taken>` is one of: `installed <plugin>`, `walked roll-your-own`, `skipped`, `stopped walk here`.

HH:MM is UTC with minute precision.

## Phase 6: Final summary

Print a one-screen final summary:

```
=== /pronto:improve complete ===
Repo: <REPO_ROOT>
Dimensions reviewed: <N>/<total-below-threshold>
Actions taken: <N install>, <M walk>, <K skip>
Pulse entry: project/pulse/<TODAY>.md

Next:
  1. /pronto:audit to re-score dimensions you installed siblings for.
  2. /pronto:improve again to pick up where you left off.
=== END ===
```

## Interactivity and budget

- Interactive via AskUserQuestion per dimension. The walk is paced by the user; no auto-advance.
- Each AskUserQuestion should be fast — options precomputed, no mid-question agent dispatch.
- Reading a roll-your-own doc should be immediate; don't paginate artificially.
- Budget: a typical walk of 3 weakest dimensions with one install + one walk + one skip should take ≤3 minutes of wall time, dominated by human decision latency.

## Error handling

- STATE missing → suggest `/pronto:audit`, stop.
- STATE malformed → suggest re-audit, stop.
- User dismisses the first AskUserQuestion → treat as "skip all," emit a minimal pulse entry noting the session was opened but no action taken, stop cleanly.
- Pulse file write fails → surface the error but don't lose the walk summary — print the summary to the user as a last resort.

## Notes

- **Never install programmatically.** Each install is a user-confirmed `/plugin install` invocation. Pronto proposes, Claude Code's install flow runs, user is in the loop.
- **Roll-your-own doesn't auto-apply.** `/pronto:improve` walks *through* the doc with the user; it doesn't execute the recommendations autonomously. Fix application is user-driven.
- **Pulse entry is the only artifact written.** No state changes to `.pronto/state.json`. State updates happen on the next `/pronto:audit` run — improve is advisory, not state-mutating.
- **Cap at 5 dimensions per session.** Long walks exhaust attention; leave the rest for next time. The pulse entry records what's left.
