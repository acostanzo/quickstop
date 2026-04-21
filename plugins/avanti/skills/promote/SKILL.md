---
name: promote
description: Move an artifact forward through its lifecycle and record the transition in pulse
disable-model-invocation: true
argument-hint: <artifact-path-or-shortcut> [--supersedes <adr-id>]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# /avanti:promote — Drive an artifact forward through its lifecycle

You are the `/avanti:promote` orchestrator. When the user runs `/avanti:promote <artifact>`, resolve the artifact's current state, propose the next legal transition, and on confirmation: move the file (for plans and tickets), update its frontmatter `status:` and `updated:`, and append a pulse entry noting the transition.

Read `${CLAUDE_PLUGIN_ROOT}/references/sdlc-conventions.md` for the full lifecycle model and the legal-transition rules.

## Phase 0: Parse and resolve

### Step 1: Parse the target

`$ARGUMENTS` is either a path or a shortcut. Shortcuts:

- `plan:<slug>` → `project/plans/*/<slug>.md`
- `ticket:<id-slug>` → `project/tickets/*/<id-slug>.md`
- `adr:<NNN-slug>` → `project/adrs/<NNN-slug>.md`

If a path is given directly (starts with `project/` or is absolute), use it as-is. Otherwise parse the shortcut.

### Step 2: Parse flags

Check for `--supersedes <adr-id>` in `$ARGUMENTS`. Store the target ADR id (zero-padded, e.g. `007`) as **SUPERSEDES_ID** if present, else `null`.

### Step 3: Locate the repo root

Run `git rev-parse --show-toplevel 2>/dev/null`. Abort on failure. Store as **REPO_ROOT**.

### Step 4: Resolve the file

If input was a shortcut, glob under REPO_ROOT:

- `plan:<slug>` → match `project/plans/*/<slug>.md` (zero, one, or many — see below)
- `ticket:<id-slug>` → match `project/tickets/*/<id-slug>.md`
- `adr:<NNN-slug>` → match `project/adrs/<NNN-slug>.md`

Resolution rules:

- Zero matches → abort with "No artifact found for <input>."
- Multiple matches (shouldn't happen, but guard) → abort and list all matches; the user resolves the ambiguity.
- Exactly one match → proceed. Store the path as **ARTIFACT_PATH** and the artifact type (plan / ticket / adr) as **TYPE**.

## Phase 1: Determine current state and next transition

### Step 1: Read the artifact

Read ARTIFACT_PATH. Extract `status:` from the frontmatter.

### Step 2: Derive state from folder (plan / ticket)

For plans and tickets, the folder is authoritative:

- `project/plans/draft/*.md` → `draft`
- `project/plans/active/*.md` → `active`
- `project/plans/done/*.md` → `done`
- `project/tickets/open/*.md` → `open` or `in-progress` (use frontmatter `status:` to distinguish, since both live in `open/`)
- `project/tickets/closed/*.md` → `closed`

For ADRs, the folder is flat — read `status:` from frontmatter directly.

Store the resolved current state as **CURRENT_STATE**. If `status:` and folder disagree (a convention violation), tell the user explicitly and ask whether to proceed based on folder (authoritative) or frontmatter — this is rare and worth a pause.

### Step 3: Compute the legal next state

| Type | Current | Next | Notes |
|---|---|---|---|
| plan | `draft` | `active` | move `draft/ → active/` |
| plan | `active` | `done` | move `active/ → done/`; **guard**: all tickets in plan's `tickets:` array must be in `closed` state |
| plan | `done` | — | terminal; error |
| ticket | `open` | `in-progress` | frontmatter only; folder stays in `open/` |
| ticket | `in-progress` | `closed` | move `open/ → closed/` |
| ticket | `open` | `closed` | direct close, move `open/ → closed/` (ask which if ambiguous) |
| ticket | `closed` | — | terminal; error |
| adr | `proposed` | `accepted` | frontmatter only |
| adr | `accepted` | `superseded` | frontmatter only; requires `--supersedes <id>` |
| adr | `superseded` | — | terminal; error |

### Step 3a: Guard — plan active → done

If TYPE is `plan` and NEXT_STATE is `done`, scan every ticket ID in the plan's `tickets:` frontmatter array and check that each corresponding file lives in `project/tickets/closed/`. If any ticket is not closed, abort with a clear message:

```
Cannot promote plan "${<plan-slug>}" to done: N tickets still open.
  - t3-foo (open)
  - t5-bar (in-progress)

Close each open ticket first with /avanti:promote ticket:<id-slug>.
```

This mirrors the convention stated in `references/sdlc-conventions.md`: "A plan only leaves `active` when every ticket it owns is closed."

If the current state has exactly one next legal state, use it. If multiple (ticket `open`), use AskUserQuestion to pick:

- "open → in-progress (start work)"
- "open → closed (close directly)"

If no legal next state exists (terminal) → abort with:

```
${TYPE} at ${ARTIFACT_PATH} is already in terminal state ${CURRENT_STATE}.
There is no legal forward transition. To retire or replace, author a new
artifact (plan: draft a successor; ADR: propose a new ADR that supersedes this one).
```

Store the target state as **NEXT_STATE**.

### Step 4: Guard ADR supersession

If TYPE is `adr` and NEXT_STATE is `superseded`:

- If **SUPERSEDES_ID** is null → abort with usage: "ADR supersession requires `--supersedes <new-adr-id>` pointing to the ADR that replaces this one."
- Resolve the superseding ADR via `project/adrs/${SUPERSEDES_ID}-*.md` glob. If no match, abort with "No ADR found with id ${SUPERSEDES_ID}."

Store the superseding ADR path as **SUPERSEDER_PATH**.

## Phase 2: Confirm

Tell the user the proposed transition and ask for confirmation via AskUserQuestion:

```
${TYPE}: ${ARTIFACT_PATH}
  ${CURRENT_STATE} → ${NEXT_STATE}
```

For ticket open → closed direct, note that in-progress is being skipped. For ADR supersession, also name the superseding ADR. If the user declines, abort without changes.

## Phase 3: Execute the transition

Run `date +%Y-%m-%d` via Bash. Store as **TODAY**.

### For plans

If NEXT_STATE is `active`, target folder is `project/plans/active/`.
If NEXT_STATE is `done`, target folder is `project/plans/done/`.

1. Edit ARTIFACT_PATH: `status: ${CURRENT_STATE}` → `status: ${NEXT_STATE}`, bump `updated: ${TODAY}`.
2. Bash `mv ARTIFACT_PATH <target-folder>/<basename>` to move the file.

Store the new path as **NEW_PATH**.

### For tickets

If NEXT_STATE is `in-progress`:

1. Edit ARTIFACT_PATH: `status: open` → `status: in-progress`, bump `updated: ${TODAY}`.
2. Folder stays `project/tickets/open/`. NEW_PATH = ARTIFACT_PATH.

If NEXT_STATE is `closed`:

1. Edit ARTIFACT_PATH: `status: ${CURRENT_STATE}` → `status: closed`, bump `updated: ${TODAY}`.
2. Bash `mv ARTIFACT_PATH project/tickets/closed/<basename>`.

Store the new path as NEW_PATH.

### For ADRs

NEXT_STATE is either `accepted` or `superseded`; the folder is flat, so only frontmatter changes.

If NEXT_STATE is `accepted`:

1. Edit ARTIFACT_PATH: `status: proposed` → `status: accepted`, bump `updated: ${TODAY}`.

If NEXT_STATE is `superseded`:

1. Edit ARTIFACT_PATH: `status: accepted` → `status: superseded`, bump `updated: ${TODAY}`, and set `superseded_by: ${SUPERSEDES_ID}`.
2. Edit SUPERSEDER_PATH: ensure a `supersedes:` field records this ADR's id. If the field is absent, add it immediately after `superseded_by:`.

NEW_PATH = ARTIFACT_PATH for ADRs.

## Phase 4: Pulse the transition

Invoke `/avanti:pulse` with a terse transition message so the journal records the lifecycle event. Message template:

```
Promoted ${TYPE} ${<basename-without-ext>}: ${CURRENT_STATE} → ${NEXT_STATE}.
```

For ADR supersession, append " (superseded by ${SUPERSEDES_ID})."

If `/avanti:pulse` is not yet wired (bootstrap), fall back to appending the entry directly to today's pulse file per the convention in `${CLAUDE_PLUGIN_ROOT}/references/sdlc-conventions.md#pulse-structure`.

## Phase 5: Report

Tell the user:

```
${TYPE} promoted: ${CURRENT_STATE} → ${NEXT_STATE}
  path: ${NEW_PATH}
  updated: ${TODAY}
  pulse: logged to project/pulse/${TODAY}.md
```

For ADR supersession, also report the cross-linked superseder path.

## Error handling

- **Artifact not found**: abort with the input name and a pointer to `/avanti:status` to list known artifacts.
- **Already terminal**: abort with the "no legal forward transition" message above — do not silently no-op.
- **Folder/frontmatter mismatch**: pause and surface explicitly. Folder wins for plans and tickets; prompt the user to confirm which state to use as the starting point.
- **ADR supersede without `--supersedes`**: abort with usage.
- **`--supersedes` target not found**: abort, name the missing id.
- **Move failure (plans, tickets)**: if frontmatter was edited but the move failed, try to revert the frontmatter. If revert also fails, leave a clear report so the user can fix manually.
