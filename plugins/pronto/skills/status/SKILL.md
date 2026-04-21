---
name: status
description: Show pronto readiness snapshot — last audit score, installed siblings, dimensions below threshold, dimensions not configured
disable-model-invocation: true
argument-hint: "[--verbose]"
allowed-tools: Read, Glob, Bash
---

# Pronto: Status

You are the Pronto status reporter. When the user runs `/pronto:status` (or `--verbose`), produce a concise snapshot of the repo's readiness. Read-only — never mutates state.

## Arguments

Parse `$ARGUMENTS`:
- Contains `--verbose` → **VERBOSE = true**.
- Otherwise → **VERBOSE = false**.

## Phase 0: Resolve environment

1. **REPO_ROOT**: `git rev-parse --show-toplevel 2>/dev/null`. If this fails, tell the user status must run inside a git repo and stop.
2. **PLUGIN_ROOT**: `${CLAUDE_PLUGIN_ROOT}`.
3. **STATE_PATH**: `${REPO_ROOT}/.pronto/state.json`.

## Phase 1: Load state

Read `${STATE_PATH}`:

- **File missing**: emit the "no audit yet" snapshot (see below), suggest running `/pronto:audit`, stop.
- **File malformed**: emit a degraded snapshot noting state corruption and suggest re-running `/pronto:audit --json` to regenerate.
- **File valid**: parse into **STATE** — contains `last_audit`, `composite_score`, `composite_grade`, `dimensions{}`.

## Phase 2: Discover siblings

Mirror the discovery logic from `/pronto:audit` Phase 2:

- Read `${REPO_ROOT}/.claude-plugin/marketplace.json` if present.
- Read `~/.claude/plugins/installed_plugins.json` if present.
- Build **INSTALLED** — a list of `(plugin_name, version, scope)` tuples where scope is `project` (marketplace) or `global` (installed_plugins).

## Phase 3: Load registries

Read `${PLUGIN_ROOT}/references/recommendations.json` — needed to look up each dimension's `dimension_label` and `recommended_plugin`.

## Phase 4: Compute display

### Below-threshold dimensions

A dimension is "below threshold" if its score is <= 50 per the presence-cap. Collect these for the summary.

### Not-configured dimensions

A dimension is "not configured" if its `source` in STATE is `presence-fail` OR its `source` is `kernel-presence-cap` AND the recommended sibling is not in INSTALLED. Collect these.

### Fresh-installed dimensions

A dimension is "fresh-installed" if the recommended sibling is in INSTALLED but the dimension's `source` in STATE is not `sibling` — meaning the sibling was installed after the last audit. These show up as "re-run /pronto:audit to pick up the installed sibling."

## Phase 5: Emit summary

### Two-line summary (default)

```
Pronto: <composite_score>/100 (<composite_grade>) — last audit <relative-time>
  <N> dimensions below threshold | <M> not configured | <K> siblings installed
```

Examples:
- `Pronto: 72/100 (C) — last audit 4 hours ago`
- `Pronto: 45/100 (D) — last audit 2 days ago`

Relative time: render as `just now` (<5 min), `X minutes ago` (<1 hour), `X hours ago` (<24 hour), `X days ago` (≥1 day).

Append a one-line next-step suggestion:

- If below-threshold count > 0 → `  Next: /pronto:improve to walk weakest dimensions`.
- Else if fresh-installed count > 0 → `  Next: /pronto:audit to pick up newly-installed <plugin>`.
- Else → `  Up to date. No improvements queued.`

### No-audit-yet snapshot

If STATE is missing:

```
Pronto: no audit run yet.
  Installed siblings: <list or "none">
  Next: /pronto:audit to generate your first scorecard.
```

### Verbose snapshot

If VERBOSE:

```
=== PRONTO STATUS ===
Repo: <REPO_ROOT>
Last audit: <timestamp> (<relative-time>)
Composite: <score>/100  Grade: <grade>

Dimensions (weakest first):
  event-emission         0/100   F   × not configured            recommended: autopompa (Phase 2+)
  skills-quality        50/100   D   ⊘ presence-cap              recommended: skillet
  ...
  claude-code-config    82/100   B   ✓ claudit                   installed v2.6.0

Installed siblings:
  ✓ claudit       v2.6.0  (global)
  ✓ pronto        v0.1.0  (local)
  ⊘ skillet       not installed
  ⊘ commventional not installed

Configuration state:
  - .pronto/state.json: present (valid)
  - Recommendations loaded: 8 dimensions
  - Siblings discovered: <N>

Next actions:
  1. /pronto:improve — interactive walk through weakest dimensions
  2. /pronto:audit — re-run if siblings have changed
=== END ===
```

## Performance

Status is read-only and should complete in under 1 second. No agent dispatch, no sibling invocation, no depth analysis.

## Error handling

- `.pronto/state.json` missing → no-audit-yet snapshot (not an error).
- `state.json` malformed → degraded snapshot with a clear hint to re-run `/pronto:audit`.
- `recommendations.json` missing → abort with clear error (plugin install is damaged).
- `installed_plugins.json` missing → treat as "no siblings installed globally" (not an error — common on fresh installs).

## Notes

- **Read-only always.** Status never writes. If the state is stale or corrupt, status reports that state — it doesn't auto-repair.
- **Relative time is computed from `now`, not from wall-clock in the state.** So running status at midnight UTC after a morning audit shows "X hours ago" — the user doesn't need to know the state was written before timezone ambiguity.
- **Verbose output is for debugging and deep inspection.** The two-line summary is the ergonomic default.
