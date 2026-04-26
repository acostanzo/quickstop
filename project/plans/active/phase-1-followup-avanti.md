---
phase: 1
status: active
tickets: [t1]
updated: 2026-04-26
---

# Avanti Phase 1 follow-up — Sibling alignment + A3 step 3

## The role in one paragraph

Avanti Phase 1 (PR #41) shipped its plugin shell, seven skills, and a wire-contract-emitting audit. Since then the constellation has ratified ADR-004 (loose coupling + version handshake) and ADR-005 (sibling skill conventions), and pronto v0.2.0 now enforces the `compatible_pronto` handshake at audit dispatch. This follow-up brings avanti into compliance and closes the live `/pronto:audit` integration step that A3 deferred at PR-41 time. Out: anything that depends on pronto Phase 2 PR H3 (wire-contract `$schema_version: 2` + `observations[]`) — that's a separate Phase 1.5 ticket once H3 lands.

## Tickets

### T1 — Declare compatible_pronto and align audit emission to the v1 contract

Add `compatible_pronto: ">=0.2.0 <0.3.0"` under the `pronto` block in `plugins/avanti/.claude-plugin/plugin.json` (range chosen for pre-1.0 semver discipline: floor matches the version tested against, pinned-minor ceiling forces deliberate re-validation when pronto H3 ships and bumps to 0.3.x). Bump avanti to `0.1.3` across plugin.json + marketplace.json + root README. Sweep `skills/audit/SKILL.md` for wire-contract field-name divergences from `plugins/pronto/references/sibling-audit-contract.md`: rename finding `level` → `severity`, `path` → `file`; rename recommendation `action` → `title` and `rationale` → `command`/`category`/`impact_points` per the contract; promote `audit_ignore: true` overrides from a markdown-only surface to JSON `info`-severity findings so consumers detect them programmatically. Trace pronto's project-record dispatch path against avanti's declarations and run a live `/pronto:audit --json` against a fresh fixture to verify A3 step 3 end-to-end now that pronto has shipped.

**Acceptance:** `compatible-pronto-check.sh "$(jq -r .version plugins/pronto/.claude-plugin/plugin.json)" ">=0.2.0 <0.3.0"` returns `branch: "in_range"`. Avanti's `findings[]` and `recommendations[]` schemas in `skills/audit/SKILL.md` match `plugins/pronto/references/sibling-audit-contract.md` field-for-field, in **both** the JSON schema example and the markdown-rendering example. `./scripts/check-plugin-versions.sh` passes. `grep -nE '"level"\|"path":\|"action":\|"rationale":\|<action>\|<rationale>\|\[<level>\]' plugins/avanti/skills/audit/SKILL.md` returns zero matches (covers both JSON keys and markdown placeholders). Trace document records pronto's project-record path as `INSTALLED_SIBLINGS lookup → handshake in_range → native dispatch → source: sibling`. Live `/pronto:audit --json` against a fixture repo (with both plugins side-loaded) returns avanti's full envelope embedded under `dimensions[].source_audit` with `source: sibling`, `weighted_contribution: 5.0` (full weight, not 50-cap). Fixture is cleaned up after.

## Out of scope

- **Migration to `observations[]` payload (ADR-005 §3).** Blocked on pronto Phase 2 PR H3 (wire-contract `$schema_version: 2` bump), which has not landed. Will be picked up as a separate ticket once H3 ships; ADR-005's back-compat `score` passthrough means avanti's current v1 emission keeps working in the interim.
- **Pronto-side `recommendations.json` `plugin_status` update** (`phase-1b → shipped`). That's a pronto data-file change; sequenced under pronto's session, not avanti's.
- **Avanti `:doctor` skill (ADR-005 §2).** Optional convention; no current self-diagnostic logic to formalize. Worth proposing only if a real diagnostic surface emerges.
- ~~**Live end-to-end `/pronto:audit` invocation against an installed avanti.**~~ **Re-evaluated during execution and superseded.** The "needs interactive Claude Code session" framing was overcautious — `claude --print --plugin-dir <pronto> --plugin-dir <avanti>` orchestrated by Bash works as a live integration primitive from the batch agent. Live invocation ran successfully; full result captured in `project/tickets/closed/t1-handshake-and-contract-align.md` (A3 step 3 verification, "structural + live" section).

## Definition of done

- `plugins/avanti/.claude-plugin/plugin.json` carries `compatible_pronto: ">=0.2.0 <0.3.0"` and v0.1.3.
- `marketplace.json` and root `README.md` reflect v0.1.3.
- `skills/audit/SKILL.md` finding and recommendation field names match `sibling-audit-contract.md`.
- `skills/ticket/SKILL.md` ID-collision guard scopes per-id check to PLAN_SLUG (cross-plan IDs by design).
- Trace document under `project/tickets/closed/t1-handshake-and-contract-align.md` shows both the structural dispatch path arriving at `source: sibling` and the live `/pronto:audit --json` envelope embedding avanti's contract.
- All commits on the branch are atomic conventional commits, rebase-merge friendly. PR approved through the test-then-review loop before merge.
