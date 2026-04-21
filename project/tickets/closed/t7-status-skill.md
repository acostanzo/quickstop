---
id: t7
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T7 — /pronto:status skill

## Context

`plugins/pronto/skills/status/SKILL.md` — read-only snapshot of the repo's pronto state. Reports last audit score, installed siblings, dimensions below threshold, dimensions not configured. Two-line summary by default; full dump under `--verbose`.

## Acceptance

- Frontmatter: `name: status`, `description`, `disable-model-invocation: true`, `argument-hint: "[--verbose]"`, `allowed-tools: Read, Glob, Bash`.
- Reads `${REPO_ROOT}/.pronto/state.json` — handles three cases: missing (no-audit-yet snapshot), malformed (degraded snapshot with re-audit hint), valid (renders summary).
- Discovery mirrors `/pronto:audit` Phase 2 (marketplace.json + installed_plugins.json) to know which siblings are available.
- Two-line default: composite/grade + relative timestamp, plus counts of below-threshold / not-configured / installed-siblings; appended with a next-step hint.
- `--verbose`: full dump — per-dimension table with source markers, per-sibling install status, configuration-state check.

## Decisions recorded

- **Read-only always.** Status never writes. If state is stale or malformed, status reports that state — it doesn't auto-repair. Auto-repair would hide drift from the user.
- **Relative time computed at render.** So `last audit 4 hours ago` always reflects "now minus state's last_audit" — avoids staleness confusion when a cached state is read by a different session than the one that wrote it.
- **Next-step hint is decision-rule-driven.** If below-threshold > 0 → propose `/pronto:improve`. Else if fresh-installed siblings > 0 → propose `/pronto:audit` to pick them up. Else → "up to date." Three-way branch, no hallucinated suggestions.
- **"Fresh-installed" concept.** A sibling installed AFTER the last audit produces a stale state — the dimension is still `kernel-presence-cap` in the state but the sibling is present. Status flags this explicitly so the user knows to re-audit.
- **Performance: under 1 second.** Pure file reads, no agent dispatch, no depth analysis. Status is the quick-glance command; if it ever slows down, it's doing too much.
