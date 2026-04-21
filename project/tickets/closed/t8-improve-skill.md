---
id: t8
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T8 — /pronto:improve skill

## Context

`plugins/pronto/skills/improve/SKILL.md` — the user-facing remediation walker. Reads `.pronto/state.json`, ranks dimensions by score ascending, walks the top 5 weakest interactively via AskUserQuestion, and appends a pulse journal entry recording what was decided.

## Acceptance

- Frontmatter: `name: improve`, `description`, `disable-model-invocation: true`, `allowed-tools: Read, Glob, Bash, Write, Edit, AskUserQuestion`.
- Six phases: env → load state → load registries → rank dimensions → walk interactively (per-dim AskUserQuestion with install / walk-roll-your-own / skip / stop options) → append pulse → final summary.
- Ranking: score ascending, ties by descending weight, filtered to `score < 75` (B threshold), capped at top 5 weakest per session.
- Per-dimension presentation shows current score + source + weight + recommended sibling + roll-your-own ref, with the source description adapted per `source` enum value.
- Install option only offered when `plugin_status` is `shipped` or `phase-1b` AND the sibling isn't already installed.
- Pulse entry appended to `project/pulse/${TODAY}.md` (creating the file if absent) with a `## HH:MM — /pronto:improve walk` header and a bulleted per-dimension action log.

## Decisions recorded

- **Cap at 5 weakest per session.** Long walks exhaust attention. Pulse entry records what remains; the user can `/pronto:improve` again next session.
- **B-threshold filter (<75).** Dimensions at B or better don't need the interactive walk — the plan says "walks lowest-scoring dimensions first," which implicitly means the weak ones. Hard-coded at 75 in Phase 1; tuning knob candidate.
- **Improve is advisory, not state-mutating.** The only artifact it writes is the pulse entry. State updates come from the next `/pronto:audit` run. This keeps improve's read-only contract consistent with status's — only audit writes state.
- **Never install programmatically.** Consistent with `/pronto:init`'s Phase 5 — pronto proposes, Claude Code's install flow runs with the user in the loop.
- **"Walk through roll-your-own" reads the existing ref doc, doesn't auto-apply.** The docs are written with "Concrete first step" sections precisely because improve surfaces them; the user acts, improve doesn't.
- **Empty-below-threshold path emits a positive pulse entry.** If every dimension is ≥75, the walk exits early but still records a pulse entry noting "no improvements queued" — so the journal accurately reflects that an improve session happened.
