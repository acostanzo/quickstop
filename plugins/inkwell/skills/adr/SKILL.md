---
name: adr
description: Create architecture decision records from conversation context
disable-model-invocation: true
argument-hint: "<title>"
allowed-tools: Read, Bash, Glob, Write, Edit
---

# ADR

Create a numbered Architecture Decision Record in the configured decisions directory. ADRs capture the context, decision, and consequences of significant architectural choices.

## `/inkwell:adr $ARGUMENTS`

### Phase 1: Validate Input

`$ARGUMENTS` is the ADR title. If empty, stop and ask: "Provide a title for the ADR (e.g., `/inkwell:adr Use PostgreSQL for session storage`)."

### Phase 2: Read Configuration

If `.inkwell.json` exists in the project root, read it to determine paths. Otherwise use defaults.

The ADR output directory is derived from the `docs.architecture.file` config — ADRs are always stored in a `decisions/` subdirectory under the docs root. For example, if `docs.architecture.file` is `docs/ARCHITECTURE.md`, the decisions directory is `docs/decisions/`. Default: `docs/decisions/`.

The index file path comes from `docs.index.file`. Default: `docs/INDEX.md`.

### Phase 3: Detect Next Number

Glob `<decisions-dir>/*.md` to find existing ADRs. ADR files follow the naming convention `NNNN-kebab-title.md` (e.g., `0001-use-postgresql.md`).

If the decisions directory doesn't exist, create it and start at `0001`.

Otherwise, extract the highest number from existing filenames and increment by 1. Zero-pad to 4 digits.

### Phase 4: Create the ADR

Convert the title to kebab-case for the filename: `<decisions-dir>/<NNNN>-<kebab-title>.md`.

Write the ADR using this template:

```markdown
# <NUMBER>. <Title>

**Date:** <YYYY-MM-DD>

**Status:** Proposed

## Context

[Describe the issue motivating this decision. What is the problem? What constraints exist?]

## Decision

[Describe the change being proposed or decided. Be specific about what will be done.]

## Consequences

### Positive

- [Expected benefits]

### Negative

- [Expected drawbacks or risks]

### Neutral

- [Other effects that are neither clearly positive nor negative]
```

Fill in the Date field with today's date. Leave the bracketed placeholder text in Context, Decision, and Consequences — the user will fill these in.

### Phase 5: Update Index

Read the index file path from config (`docs.index.file`, default `docs/INDEX.md`).

If the index file exists, read it and add the new ADR under a "Decisions" section. If the section doesn't exist, create it.

If the index file doesn't exist, create it with the new ADR as the first entry under "Decisions."

### Phase 6: Confirm

Output the created file path and its number:

```
Created ADR #<NNNN>: <Title>
  → <decisions-dir>/<NNNN>-<kebab-title>.md

Fill in the Context, Decision, and Consequences sections, then update the Status field.
```
