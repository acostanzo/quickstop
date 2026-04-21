---
id: t9
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T9 — Recommendation registry

## Context

`plugins/pronto/references/recommendations.json` — machine-readable map from rubric dimension slug to recommended sibling plugin + install command + audit command + parser-agent pointer + roll-your-own reference path + presence-check summary. This is the data file consumed by `/pronto:init` (proposing installs per dimension), `/pronto:audit` (knowing how to invoke each sibling and where to fall back), and `/pronto:improve` (walking lowest-scoring dimensions and surfacing the recommended next step).

## Acceptance

- File parses as valid JSON, top-level `$schema_version: 1`.
- Every one of the 8 rubric dimensions has an entry (validated by script — 8/8 covered).
- Each entry includes: `dimension`, `dimension_label`, `recommended_plugin`, `plugin_status`, `install_command`, `audit_command`, `parser_agent`, `roll_your_own_ref`, `presence_check`.
- `plugin_status` uses a controlled vocabulary: `shipped`, `phase-1b`, `phase-2-plus`.
- Phase 2+ dimensions (`code-documentation`, `lint-posture`, `event-emission`) have `install_command: null` — their siblings don't exist yet, so there's nothing to install. Their `roll_your_own_ref` paths still point to the references T10 populates.
- `agents-md` has `recommended_plugin: pronto` and `install_command: null` — pronto itself is the owner, and its audit command is `/pronto:kernel-check --json`.
- `project-record` lists `avanti` with `plugin_status: phase-1b` — install_command present since avanti is a sibling-in-progress, not a distant-phase plugin.

## Decisions recorded

- The registry is a JSON **data file**, not a markdown doc. It's loaded by skills (not read by humans) so machine-parseability wins over prose.
- `parser_agent` field points to the relative path under `plugins/pronto/agents/` (no extension). Parsers that don't apply (e.g., for siblings that will emit native contract) are `null`.
- `roll_your_own_ref` is always populated, even for dimensions whose recommended sibling is `shipped` — rolling-your-own is a legitimate path for every dimension regardless of sibling availability.
- `audit_command` and `install_command` may be `null` independently: Phase 2+ plugins have both nulled; `agents-md` has install nulled (self-owned) but audit_command populated (kernel-check).
