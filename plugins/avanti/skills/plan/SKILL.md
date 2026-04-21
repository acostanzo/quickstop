---
name: plan
description: Draft a new plan from the avanti template into project/plans/active/
disable-model-invocation: true
argument-hint: <slug>
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# /avanti:plan — Draft a new plan

You are the `/avanti:plan` orchestrator. When the user runs `/avanti:plan <slug>`, draft a new plan from `templates/plan.md` into `project/plans/active/<slug>.md`, then walk the user through an interactive authoring pass over the frontmatter and pivot paragraph. Refuse to overwrite existing files.

Read `${CLAUDE_PLUGIN_ROOT}/references/sdlc-conventions.md` before proceeding if you are uncertain about any lifecycle or frontmatter rule.

## Phase 0: Parse and validate

### Step 1: Parse the slug

Extract the slug from `$ARGUMENTS`.

- If `$ARGUMENTS` is empty or missing → use AskUserQuestion to prompt: "What slug should the plan use? (kebab-case, e.g. `phase-2-lintguini`)"
- Validate the slug against `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. If it fails, reject and re-prompt.

Store the validated slug as **SLUG**.

### Step 2: Locate the repo root and the plans directory

Run `git rev-parse --show-toplevel 2>/dev/null` via Bash. If this fails (not a git repo), abort with a clear message — avanti expects to be run inside a repo.

Store the result as **REPO_ROOT**. The plans directory is **PLANS_DIR** = `${REPO_ROOT}/project/plans/`.

### Step 3: Check for collisions

Glob for `project/plans/*/${SLUG}.md` rooted at REPO_ROOT. If any file matches (in `draft/`, `active/`, or `done/`), abort:

```
A plan with slug "${SLUG}" already exists at <matching path>.
Refusing to overwrite. Pick a different slug or remove the existing plan.
```

### Step 4: Confirm the plans directory exists

If `${PLANS_DIR}active/` does not exist, this repo has not been `/pronto:init`'d. Report this clearly and abort:

```
project/plans/active/ does not exist in this repo.
Run /pronto:init first (or create the directory manually).
```

## Phase 1: Gather authoring input

### Step 1: Get today's date

Run `date +%Y-%m-%d` via Bash. Store as **TODAY**.

### Step 2: Interactive authoring

Use AskUserQuestion to collect:

1. **Plan title** — the H1 that follows the frontmatter. Short, descriptive. Example: "Phase 2 — Lintguini linter integration."
2. **Phase number** — integer. The broad execution phase this plan belongs to. Default: `1` for first-phase work.
3. **Pivot paragraph** — one paragraph summarizing the plan's role, goal, and scope boundary. This is the paragraph a reviewer reads first; lead with the goal, close with what's out.

Store as **TITLE**, **PHASE**, **PIVOT**.

## Phase 2: Render and write

### Step 1: Read the template

Read `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`. Store as **TEMPLATE**.

### Step 2: Fill placeholders

Produce **RENDERED** by applying these substitutions to TEMPLATE:

- `phase: 0` → `phase: ${PHASE}`
- `updated: TODO` → `updated: ${TODAY}`
- `# TODO — <plan title>` → `# ${TITLE}`
- The "TODO: one paragraph that pivots into the work..." block under `## The role in one paragraph` → ${PIVOT}

Leave all other TODO/placeholder sections intact — the author will flesh them out over the course of the plan's life (model, tickets, acceptance bars, out-of-scope, DoD).

### Step 3: Write

Write RENDERED to `${PLANS_DIR}active/${SLUG}.md` using the Write tool.

## Phase 3: Report

Tell the user:

```
Plan drafted: project/plans/active/${SLUG}.md

Next:
  - Fill in the model, tickets, acceptance bars, and DoD sections.
  - Commit the plan; the PR is the draft surface.
  - Mint tickets with /avanti:ticket <slug> --plan ${SLUG}
  - Promote to done/ with /avanti:promote plan:${SLUG} once every ticket is closed and A-bars pass.
```

## Error handling

- **Slug validation fails repeatedly**: abort after two failed attempts with a pointer to the kebab-case rule.
- **Write fails**: report the underlying error; do not leave a partial file. If Write created a file before failing, delete it (`rm` via Bash) before re-raising.
- **Repo has no `project/plans/active/`**: tell the user to run `/pronto:init` and abort — do not auto-create the directory (that belongs to the kernel).
