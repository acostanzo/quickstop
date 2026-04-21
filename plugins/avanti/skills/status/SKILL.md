---
name: status
description: Summarize active plans, open tickets, proposed ADRs, and the latest pulse entry
disable-model-invocation: true
argument-hint: "[--verbose]"
allowed-tools: Read, Bash, Glob, Grep
---

# /avanti:status — Summarize work in flight

You are the `/avanti:status` orchestrator. When the user runs `/avanti:status`, walk `project/` and summarize what work is in flight: active plans, open tickets, proposed ADRs, and the latest pulse entry. Default output is a two-line summary; `--verbose` expands to a full dump.

Read `${CLAUDE_PLUGIN_ROOT}/references/sdlc-conventions.md` if you need to recheck what "active" or "open" mean.

## Phase 0: Parse and locate

### Step 1: Parse flags

- `--verbose` in `$ARGUMENTS` → set **VERBOSE = true**, else false.

### Step 2: Locate the repo root

Run `git rev-parse --show-toplevel 2>/dev/null`. Abort on failure — `/avanti:status` expects to be inside a repo. Store as **REPO_ROOT**.

### Step 3: Detect scaffold

Check whether `${REPO_ROOT}/project/` exists. If it does not, report cleanly and exit:

```
No project/ directory in this repo. Nothing to report.
Run /pronto:init to scaffold one.
```

## Phase 1: Gather

Run these Globs and file scans in parallel where possible:

### Active plans

Glob `project/plans/active/*.md`. For each match, read the file's frontmatter to get `updated:`. Also run `git log -1 --format=%cI -- <path>` (via Bash) to get the last commit date touching the file. Prefer the git commit date if available; fall back to frontmatter `updated:` if git has no history for the file yet.

Store as **ACTIVE_PLANS** (list of `{slug, updated, last_commit}` records).

### Open tickets

Glob `project/tickets/open/*.md`. For each, read frontmatter to get `id:`, `status:` (open vs in-progress), `plan:`, and `updated:`. Also get last-commit date via git log.

Store as **OPEN_TICKETS** (list of `{id, slug, plan, status, updated, last_commit}` records).

### Proposed ADRs

Glob `project/adrs/*.md`. For each, read frontmatter `status:`. Keep the ones where `status: proposed`.

Store as **PROPOSED_ADRS** (list of `{id, slug, updated}` records).

### Latest pulse entry

Glob `project/pulse/*.md`. Pick the one whose filename sorts highest (ISO date, so lexicographic = chronological). Store the path as **LATEST_PULSE_FILE** (may be `null` if no pulse files exist).

If LATEST_PULSE_FILE is not null, read the file and find the last `## HH:MM` sub-header and the paragraph immediately after it. Store as **LATEST_PULSE_ENTRY** = `{date, time, message}`. If no entries appear below the date header (file is header-only), note "day-file exists but no entries yet."

## Phase 2: Render

### Two-line summary (default)

Always print this, even in `--verbose` mode (as a leader):

```
Plans: N active | Tickets: N open (M in-progress) | ADRs: N proposed | Pulse: <date> @ <time>
<latest pulse message, truncated to ~100 chars if longer>
```

Empty-state variants:

- No active plans, no open tickets, no proposed ADRs: `Plans: 0 | Tickets: 0 | ADRs: 0 | Pulse: <date @ time, or "never">`
- No pulse files at all: `Pulse: never`
- Pulse file exists but is header-only: `Pulse: <date> (empty)`

If VERBOSE is false, stop here.

### Verbose dump

If VERBOSE is true, continue with an expanded listing:

```
ACTIVE PLANS (${len(ACTIVE_PLANS)}):
  - <slug>    updated <date>    last touched <date>
  - <slug>    updated <date>    last touched <date>

OPEN TICKETS (${len(OPEN_TICKETS)}):
  - <id>-<slug>    plan: <plan-slug>    status: <open|in-progress>    updated <date>    age <N> days
  - …

PROPOSED ADRS (${len(PROPOSED_ADRS)}):
  - <NNN>-<slug>    updated <date>

LATEST PULSE:
  project/pulse/<date>.md @ <time>
  <full message>
```

Sort active plans by last-touched descending (most recent first). Sort open tickets by age descending (oldest first — these are the ones most likely to be stale). Sort proposed ADRs by id ascending.

If a category is empty, show `  (none)` under its header rather than omitting the section.

### Age calculation

"Age" for tickets is `(today - last_commit_date)` in whole days. For the first-ever run with no commit history, use `(today - frontmatter_updated)`.

## Error handling

- **`project/` missing**: clean early exit with pointer to `/pronto:init`.
- **Glob returns nothing in a subdir**: that's valid — report `(none)` in the category.
- **Frontmatter parse fails on a file**: include it in a `MALFORMED (N):` section at the bottom of verbose output (path + the parse error). Don't crash the whole status report over one bad file.
- **Git log unavailable for a file** (new and uncommitted): fall back to frontmatter `updated:`; mark last-touched as "(uncommitted)" in verbose output.
