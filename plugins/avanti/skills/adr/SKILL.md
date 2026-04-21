---
name: adr
description: Draft a new ADR (Architecture Decision Record) from the avanti template into project/adrs/
disable-model-invocation: true
argument-hint: <slug>
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# /avanti:adr — Draft a new ADR

You are the `/avanti:adr` orchestrator. When the user runs `/avanti:adr <slug>`, mint the next zero-padded ADR number, copy `templates/adr.md` into `project/adrs/<NNN>-<slug>.md` with `status: proposed`, and walk the user through an interactive authoring pass over context, decision, and consequences.

ADRs live in a flat folder — the status field in frontmatter is authoritative, not the folder. See `${CLAUDE_PLUGIN_ROOT}/references/sdlc-conventions.md` for the reasoning and for the supersession rules.

## Phase 0: Parse and validate

### Step 1: Parse the slug

Extract the slug from `$ARGUMENTS`.

- If empty → AskUserQuestion for slug.
- Validate against `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. Re-prompt on failure.

Store as **SLUG**.

### Step 2: Locate the repo root and the ADRs directory

Run `git rev-parse --show-toplevel 2>/dev/null`. Abort if this fails. Store as **REPO_ROOT**.

**ADRS_DIR** = `${REPO_ROOT}/project/adrs/`. If the directory does not exist, abort with a pointer to `/pronto:init`.

### Step 3: Check for slug collision

Glob for `project/adrs/*-${SLUG}.md` under REPO_ROOT. If any file matches, abort:

```
An ADR with slug "${SLUG}" already exists at <path>.
Pick a different slug. ADR numbers are shared across all slugs, so a
naming collision is a content-level conflict worth resolving explicitly.
```

## Phase 1: Mint the number

### Step 1: Scan existing ADRs

Glob for `project/adrs/*.md` under REPO_ROOT. From each filename, extract the leading numeric prefix (the part before the first `-`, parsed as an integer).

Store the max as **MAX_ID** (default `0` if no ADRs exist).

### Step 2: Mint

**NEW_NUM** = MAX_ID + 1, zero-padded to 3 digits (e.g., `MAX_ID=2` → `NEW_NUM="003"`).

### Step 3: Double-check collision

Glob for `project/adrs/${NEW_NUM}-*.md`. If any match (should never happen, but guard against races), abort — something is out of sync; the user should re-scan and retry.

## Phase 2: Render and write

### Step 1: Read the template and today's date

Read `${CLAUDE_PLUGIN_ROOT}/templates/adr.md` as **TEMPLATE**. Run `date +%Y-%m-%d` as **TODAY**.

### Step 2: Gather authoring input

Use AskUserQuestion to collect:

1. **Decision title** — short, directive. Used as the H1 after frontmatter. Example: "Folder-as-primary with frontmatter status mirror."
2. **Context** — one or two paragraphs on the forces at play, what prompted this decision, the constraints narrowing the choice.
3. **Decision statement** — the choice, stated plainly. Lead with "We will …".
4. **Key consequences** — a few bullets capturing the most material downstream effects. The author will flesh the full positive/negative/neutral breakdown later.

Store as **TITLE**, **CONTEXT**, **DECISION**, **CONSEQUENCES**.

### Step 3: Fill placeholders

Produce **RENDERED** by applying these substitutions to TEMPLATE:

- `id: TODO` → `id: ${NEW_NUM}`
- `updated: TODO` → `updated: ${TODAY}`
- `# ADR TODO — <decision title>` → `# ADR ${NEW_NUM} — ${TITLE}`
- The "TODO: one or two paragraphs..." under `## Context` → ${CONTEXT}
- The "TODO: the choice..." under `## Decision` → ${DECISION}
- Replace the first two TODO bullets under `### Positive` with the CONSEQUENCES bullets (keep the remaining subsections — Negative, Neutral — with their TODO bullets intact for the author).

Leave `status: proposed` and `superseded_by: null` as-is — that's the correct initial state.

Leave the `## Alternatives considered` section's TODO blocks intact — the author fleshes those out.

### Step 4: Write

Write RENDERED to `${ADRS_DIR}${NEW_NUM}-${SLUG}.md`.

## Phase 3: Report

Tell the user:

```
ADR drafted: project/adrs/${NEW_NUM}-${SLUG}.md
Status: proposed

Next:
  - Flesh out the remaining consequences (negative, neutral).
  - Fill in alternatives considered.
  - Promote to accepted with /avanti:promote adr:${NEW_NUM}-${SLUG}.
```

## Error handling

- **Slug collision**: abort with the existing path named.
- **Number collision after mint** (double-check fails): abort with a "rescan and retry" pointer — do not silently pick the next number; surface the drift.
- **Write failure**: report the error; if the file was partially written, delete it before re-raising.
- **ADRs directory missing**: point to `/pronto:init` and abort. Do not auto-create — that belongs to the kernel.
