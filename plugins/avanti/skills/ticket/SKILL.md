---
name: ticket
description: Draft a new plan-scoped ticket from the avanti template into project/tickets/open/
disable-model-invocation: true
argument-hint: <slug> --plan <plan-slug>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# /avanti:ticket — Draft a new ticket

You are the `/avanti:ticket` orchestrator. When the user runs `/avanti:ticket <slug> --plan <plan-slug>`, mint the next plan-scoped ticket ID, copy `templates/ticket.md` into `project/tickets/open/<id>-<slug>.md`, fill the frontmatter, and update the plan's `tickets:` array to include the new ID. Every ticket belongs to a plan — invocation without `--plan` is an error.

Read `${CLAUDE_PLUGIN_ROOT}/references/sdlc-conventions.md` if you are uncertain about any lifecycle, ID-mint, or frontmatter rule.

## Phase 0: Parse and validate

### Step 1: Parse arguments

`$ARGUMENTS` takes the form `<slug> --plan <plan-slug>`. Extract:

- **SLUG** — the ticket's kebab-case suffix (the part after `<id>-` in the filename).
- **PLAN_SLUG** — the value that follows `--plan`.

If `--plan` is missing or has no value, abort:

```
/avanti:ticket requires a --plan <plan-slug> argument.
Every ticket belongs to a plan; there are no standalone tickets.
Usage: /avanti:ticket <slug> --plan <plan-slug>
```

Validate **SLUG** and **PLAN_SLUG** against `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. On failure, use AskUserQuestion to re-prompt for whichever is invalid.

### Step 2: Locate the repo root

Run `git rev-parse --show-toplevel 2>/dev/null`. Abort if this fails. Store as **REPO_ROOT**.

### Step 3: Resolve the plan

Glob for `project/plans/*/${PLAN_SLUG}.md` under REPO_ROOT. If zero matches, abort:

```
No plan with slug "${PLAN_SLUG}" found under project/plans/.
Check the slug or draft the plan first with /avanti:plan ${PLAN_SLUG}.
```

If multiple match (should never happen per collision rules in `/avanti:plan`), abort and list all matches for the user to resolve.

Store the single matching path as **PLAN_PATH**.

### Step 4: Confirm the tickets directory exists

If `${REPO_ROOT}/project/tickets/open/` does not exist, abort with a pointer to `/pronto:init`.

## Phase 1: Mint the ID

### Step 1: Read the plan's frontmatter

Read PLAN_PATH. Extract the `tickets:` array from the YAML frontmatter block.

- If the frontmatter has no `tickets:` key → treat as empty array `[]`.
- If `tickets:` is present but empty (`[]`) → starting fresh.
- If `tickets:` holds `[t1, t2, …]` → use those.

Parse the integer suffix from each entry that matches `^t\d+$` (e.g., `t3` → `3`). **Ignore entries that do not match** — plans commonly carry acceptance-bar IDs (`a1`, `a2`, …) in the same `tickets:` array, and those are not minted by this skill. Store the max of the `t`-prefixed IDs as **MAX_ID** (default `0` if no matching entries exist).

### Step 2: Mint

**NEW_ID** = `t${MAX_ID + 1}`.

### Step 3: Check for file collision

Glob for `project/tickets/*/${NEW_ID}-*.md` under REPO_ROOT. For every match, read the file's frontmatter and check whether `plan:` equals **PLAN_SLUG**. **Only abort if a same-plan match exists** — different plans legitimately each have their own `t1`, `t2`, … sequence, so a `t1-foo.md` under another plan is not a collision. If a same-plan match is found, abort: "Ticket id ${NEW_ID} is already in use by `<path>` under plan `${PLAN_SLUG}`." (Cross-plan IDs sharing the same numeric prefix are by design — see `references/sdlc-conventions.md#plan-scoped-ticket-ids`.)

Also glob for `project/tickets/*/*-${SLUG}.md`. Slug uniqueness is **repo-wide** because filenames don't carry the plan slug — two plans both choosing the slug `foo` would produce filename collisions. If any match, warn the user clearly and abort:

```
A ticket with slug "${SLUG}" already exists at <path>.
Pick a different slug.
```

## Phase 2: Render and write

### Step 1: Read the template and today's date

Read `${CLAUDE_PLUGIN_ROOT}/templates/ticket.md` as **TEMPLATE**. Run `date +%Y-%m-%d` as **TODAY**.

### Step 2: Gather authoring input

Use AskUserQuestion to collect:

1. **Ticket title** — short, descriptive. Used as the H1 after frontmatter.
2. **Context paragraph** — one paragraph explaining what this ticket is for and where it sits in the plan.

Store as **TITLE** and **CONTEXT**.

### Step 3: Fill placeholders

Produce **RENDERED** by applying these substitutions to TEMPLATE:

- `id: TODO` → `id: ${NEW_ID}`
- `plan: TODO` → `plan: ${PLAN_SLUG}`
- `updated: TODO` → `updated: ${TODAY}`
- `# TODO — <ticket title>` → `# ${NEW_ID} — ${TITLE}`
- The "TODO: one short paragraph..." under `## Context` → ${CONTEXT}
- `project/plans/active/<plan-slug>.md` in the Links block → `project/plans/active/${PLAN_SLUG}.md` (leave as-is if the plan lives in `draft/` or `done/` — the convention is to reference the active path; stale links are rare and not worth guarding)

Leave the acceptance-criteria, notes, and other TODO sections intact for the author to fill in.

### Step 4: Write

Write RENDERED to `${REPO_ROOT}/project/tickets/open/${NEW_ID}-${SLUG}.md`.

## Phase 3: Update the plan

Use Edit on PLAN_PATH to add NEW_ID to the `tickets:` array in the plan's frontmatter.

- If `tickets:` holds `[t1, t2, t3]` → rewrite to `[t1, t2, t3, ${NEW_ID}]`.
- If `tickets:` is empty `[]` → rewrite to `[${NEW_ID}]`.
- If there is no `tickets:` key → add one immediately after `status:`.

Also bump the plan's `updated:` to TODAY — any new ticket is a meaningful plan-level change.

## Phase 4: Report

Tell the user:

```
Ticket drafted: project/tickets/open/${NEW_ID}-${SLUG}.md
Plan updated:   ${PLAN_PATH} (tickets: […, ${NEW_ID}])

Next:
  - Fill in the acceptance criteria and any notes.
  - Move to in-progress by editing status (folder stays put).
  - Close with /avanti:promote ticket:${NEW_ID}-${SLUG} when done.
```

## Error handling

- **`--plan` missing**: abort immediately with the "every ticket belongs to a plan" message. Never fall through to a default plan.
- **Plan not found**: name the missing slug and point to `/avanti:plan`.
- **ID collision** (file exists with NEW_ID): abort — something is out of sync; the user should inspect the tickets directory before continuing.
- **Slug collision** (any existing ticket matches `*-${SLUG}.md`): abort with the existing path.
- **Write failure after plan edit**: revert the plan edit if possible (restore the original `tickets:` and `updated:`), then re-raise.
