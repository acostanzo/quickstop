---
id: 005
status: accepted
superseded_by: null
updated: 2026-04-24
---

# ADR 005 — Sibling skill conventions: `:audit`, `:doctor`, and the observations/scoring split

## Context

ADR-004 ratified the wire contract (audit JSON shape) and the version handshake (`compatible_pronto`). What it left implicit is **how a sibling exposes its audit logic to pronto in the first place** — the skill name pronto invokes, the shape of what gets returned, and who's responsible for translating raw observations into a numeric score.

Today's mechanism is `recommendations.json`'s per-dimension `audit_command` field. Each shipped sibling declares a different command shape (different invocation patterns, different output styles). Pronto's parser-agents bridge the difference. That works for three siblings under quickstop control. It doesn't scale to:

- **Phase 2 audit siblings** (inkwell, lintguini, etc.) where we want pronto to dispatch a predictable skill name without bespoke parser logic.
- **Third-party siblings.** A Linear-based planning plugin, a self-hosted lint engine, anything published outside quickstop. ADR-004 commits to first-class third-party participation; without a discoverable convention, that commitment is paper.
- **Doer-judges-itself plugins** like the existing `towncrier` (event-emission) where the plugin is both the canonical example of good practice AND the natural auditor of that practice in target codebases. A separate auditor-only sibling (the proposed `autopompa`) duplicates work and breaks the doer-judges-itself pattern visible everywhere in the surrounding infrastructure.

A second tension surfaced during Phase 2 architecture review: **siblings should not score themselves.** Today some siblings emit a numeric score; pronto's parser-agents translate raw sibling output into the wire-contract shape, and post-Phase 1.5 the mechanical shell scorers bypass siblings entirely for the three shipped dimensions (measuring the target repo directly). The sibling-emitted-score pattern is what's getting standardized away here. Letting each sibling pick its own scoring rubric makes the rubric itself non-portable — tuning weights or thresholds requires releases across N siblings, and a sibling has standing temptation to grade its own dimension generously.

The fix is to formalize a small set of conventions that are independent of the wire contract: **what skills siblings expose, what those skills return, and where the rubric lives.**

## Decision

### 1. `:audit` is the audit entrypoint

A sibling that participates in pronto's rubric exposes a skill named `<plugin>:audit`. Pronto's audit dispatch invokes `<plugin>:audit` (not a per-sibling command name) and expects a wire-contract-compliant audit JSON on stdout.

The name `:audit` matches the pattern skillet already uses (`skillet:audit`, with a `skills/audit/SKILL.md` file). claudit and commventional today expose their audit logic through different skill names (`claudit` for the bare plugin-name skill; `commventional:audit` declared in `recommendations.json` rather than as a `skills/audit/` directory). They will migrate to the `:audit` skill convention as part of their observations-migration. Ratifying `:audit` formalizes the most-conformant existing pattern (skillet's) and asks the other two to converge.

Concretely, a participating sibling ships:

```
plugins/<plugin>/skills/audit/SKILL.md
```

The skill's job is to read the target codebase and emit observations (and optionally a back-compat score) in the contract shape. Standalone use stays first-class: a user can run `<plugin>:audit` directly without pronto present and get useful output.

This convention applies to siblings that **claim a rubric dimension** in their `plugin.json` `pronto` block, or that pronto's `recommendations.json` recommends for a dimension. Plugins that don't participate in the rubric (a fancy git-aliases plugin, say) don't owe pronto an `:audit` skill.

### 2. `:doctor` is the optional self-health entrypoint

A sibling MAY expose `<plugin>:doctor` — a self-diagnostic skill that checks whether the plugin is configured correctly on the user's machine. Returns human-readable status plus a structured exit code (`0` healthy, non-zero degraded). Pronto MAY call `:doctor` to gate dispatch; the user MAY invoke it standalone for troubleshooting.

`:doctor` is not required for rubric participation. It's a convention so that *if* a sibling has self-diagnostic logic, the skill name is predictable. A separate `pronto:health` command (future scope) walks the constellation calling each sibling's `:doctor`.

### 3. Observations, not scores

Siblings emit **observations**, not scores. The wire contract grows a top-level `observations: []` array — deliberately distinct from the existing `categories[].findings[]` array (the existing array carries triaged issues with severity `critical|high|medium|low|info`; observations are raw signal that pronto's scorers translate into a rubric score). Each observation has a stable shape:

```json
{
  "id": "structured-log-ratio",
  "kind": "ratio" | "count" | "presence" | "score",
  "evidence": { "structured": 17, "unstructured": 3, "ratio": 0.85 },
  "summary": "85% of emit sites use the structured envelope"
}
```

Pronto's scorers consume `observations[]` and apply the rubric — `ratio >= 0.8 → 80/100`, etc. The rubric lives in pronto. Siblings are the domain authority on *what's there*; pronto is the authority on *what it's worth*. The existing `categories[].findings[]` array stays as-is for triaged-issue reporting; observations are a parallel concept with a different consumer (rubric scoring vs human readout).

**Wire contract update timing.** The `observations[]` field is a wire-contract addition tracked in **Phase 2 PR H3** (the wire-contract schema-version PR). H3 bumps `$schema_version` to 2 and adds the field. ADR-005 ratifies the convention; PR H3 lands the schema change. Until H3 ships, siblings continue emitting under the v1 contract.

**Back-compat:** the existing `score` field is preserved as optional. Siblings that haven't migrated to observations can keep emitting a score; pronto's scorer treats it as a single coarse observation and applies a passthrough rule. New siblings (Phase 2 onward) emit observations.

### 4. `:fix` is reserved

Reserve the skill name `<plugin>:fix` for a future convention where a sibling can offer remediation suggestions or apply them. Don't use the name yet; don't paint ourselves out of it.

### 5. Discovery order

Pronto's audit dispatch resolves a sibling's audit command in this order:

1. If `plugins/<plugin>/skills/audit/SKILL.md` exists, invoke `<plugin>:audit`.
2. Else if `recommendations.json` has an `audit_command` for the sibling's claimed dimension, invoke that.
3. Else, fall back to presence-only scoring per ADR-004's degradation ladder.

The ordering means existing siblings keep working unchanged. Today: skillet resolves at step 1 (`plugins/skillet/skills/audit/SKILL.md` exists); claudit and commventional resolve at step 2 (`recommendations.json` carries their legacy `audit_command` entries — `/claudit --json` and `/commventional:audit --json` respectively). The migration adds `skills/audit/SKILL.md` to each lagging sibling, after which all three resolve at step 1; the `audit_command` field can be removed from `recommendations.json` once every in-tree sibling has migrated. Third-party siblings that haven't adopted the convention continue to be discoverable via step 2 indefinitely.

## Consequences

### Positive

- **Predictable surface for third-party authors.** A Linear-planner author knows exactly what to build: a `linear-planner:audit` skill emitting observations in the contract shape, a `pronto.dimension` declaration in `plugin.json`. Pronto picks them up via the standard discovery path. ADR-004's "third-party first-class" commitment now has a concrete on-ramp.
- **Doer-judges-itself becomes possible.** A plugin that already does the work (e.g. `towncrier` for event emission) can ship its own `:audit` skill that audits target codebases for the same dimension it implements. Removes the need for parallel auditor-only plugins.
- **Rubric mobility.** Tuning weights or thresholds is a pronto-only change. No coordinated releases across siblings.
- **Trust.** Siblings stop scoring themselves. Easier to read pronto's composite as an impartial measurement.
- **Self-diagnostics get a home.** `:doctor` gives users a predictable command for "is this plugin set up right" without each plugin reinventing the surface.

### Negative

- **Migration cost on shipped siblings.** Skillet matches the convention today (`skills/audit/SKILL.md` present). claudit and commventional must add a `:audit` skill to satisfy step 1 of discovery, plus all three migrate their output to `observations[]` shape. The discovery fallback makes both migrations non-blocking — they keep working at step 2 until they migrate to step 1 — but the per-sibling work is real.
- **Two contract shapes for a window.** During the migration, some siblings emit `score`, others emit `observations[]`. Pronto's scorer must handle both via the passthrough rule in §3. Eventually the legacy path retires.
- **Standalone output ergonomics.** A `:audit` skill emitting JSON on stdout for pronto consumption is unfriendly for direct human invocation. Pretty-printing or `--human`-style flags are implementer's choice and not ratified here; the only thing this ADR specifies is the default JSON-on-stdout contract.

### Neutral

- **The convention is quickstop-flavored, not a published standard.** Quickstop is the reference implementation. A future ADR could open this up as a documented spec for the broader Claude Code plugin ecosystem; that's deferred until the convention has shipped through enough siblings to prove its shape.
- **`:fix` is reserved but not specified.** The reservation is a name, not a contract. A future ADR can ratify what `:fix` returns and how pronto integrates remediation.

## Alternatives considered

### Each sibling declares its own skill name in `plugin.json`

Rejected. Predictability is the whole point — a third-party author shouldn't need to invent a skill-name field, and pronto shouldn't need a discovery path that interrogates each sibling's plugin manifest before dispatch. A single convention (`:audit`) is simpler and more discoverable.

### Use a new name like `:eval` instead of `:audit`

Rejected. Skillet already exposes `:audit` (and matches the proposed file layout); claudit and commventional expose audit logic under other names today. Picking `:audit` ratifies the most-conformant existing pattern and gives the other two a single target to migrate toward. Picking a new name like `:eval` would force migration on all three siblings without preserving any of the existing surface. `:audit` is also the more accurate verb — siblings inspect a target codebase and report observations, which is what an audit is.

### Mandate `:audit`, `:doctor`, AND `:fix` from day one

Rejected. Over-specification. We don't yet know what `:fix` should return or how pronto would compose remediation across siblings. Reserving the name preserves the option without committing to a half-baked contract.

### Keep scoring in siblings, just standardize the skill name

Rejected. Standardizing the skill name without addressing the observations/scoring split leaves the rubric non-portable and leaves siblings with standing temptation to self-grade. The two changes belong together.

### Centralize the audit logic in pronto entirely

Rejected. Centralizing audit logic forces pronto to understand every domain it scores, which closes the rubric to extension. A Linear-based planning plugin can't be added without modifying pronto. Federated audit + central rubric is the architectural sweet spot — siblings own domain knowledge, pronto owns rubric knowledge.

## Links

- Wire contract: `plugins/pronto/references/sibling-audit-contract.md`
- Sibling registry: `plugins/pronto/references/recommendations.json`
- Composition contract: `project/adrs/004-sibling-composition-contract.md`
- Phase 2 plan (will be restructured against this ADR): `project/plans/draft/phase-2-pronto.md`
