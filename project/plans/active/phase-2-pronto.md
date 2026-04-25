---
phase: 2
status: active
tickets: [h1, h2a, h2b, h3, h4, 2a1, 2a2, 2a3, 2b1, 2b2, 2b3, 2c1, 2c2, 2c3]
updated: 2026-04-25
---

# Pronto Phase 2 — Breadth: new siblings on a hardened foundation

## Why this phase exists

Phase 1.5 closed with pronto producing reproducible scores. The constellation today has four of eight rubric dimensions running at full depth via shipped siblings (`claude-code-config` via claudit, `skills-quality` via skillet, `commit-hygiene` via commventional, `agents-md` via pronto's kernel check). Three dimensions are `phase-2-plus` stubs in `recommendations.json` (`code-documentation`, `lint-posture`, `event-emission`). The `project-record` dimension unlocks when avanti Phase 1b ships — tracked in the avanti plan, not here.

Phase 2 ships those three missing siblings — and ships them against the convention ratified in ADR-005: `:audit` skills emitting `observations[]` for pronto's scorers to translate into rubric scores. The architectural commitments from ADR-005 land in the Hardening group (H3 expands the wire contract, H4 adds the observations-aware scoring path); the new siblings consume that foundation from day one.

The third audit sibling — `event-emission` — is shipped as a **towncrier extension** rather than a separate plugin. Towncrier is already the in-house exemplar of good event-emission practice; ADR-005's doer-judges-itself architecture says the plugin doing the work is the natural auditor of that work. Earlier drafts of this plan proposed a separate `autopompa` sibling; ADR-005 retired that shape.

Before adding siblings, foundation items need hardening. Phase 1.5's own plan flagged the principle: *"Phase 2 should not build on top of an orchestrator whose output is non-reproducible."* That lesson applies again — Phase 2 should not build on top of a composition model that's paper, a wire contract spec missing its own version, an orchestrator whose failure mode is still unmeasured at the point Phase 2 siblings would start dispatching through it, or a scoring path that can't yet consume what ADR-005 says siblings emit.

## Scope

Fourteen tickets organized into seven PRs across two groups.

| Group | PR | Rubric dimension | Lands when |
|---|---|---|---|
| Hardening | PR H1 — compatible_pronto enforcement | — | First |
| Hardening | PR H2 — orchestrator JSON-emission reliability | — | After H1 |
| Hardening | PR H3 — wire contract `$schema_version: 2` + `observations[]` | — | Parallel with H2 |
| Hardening | PR H4 — observations-aware scorer in pronto | — | After H3 |
| Sibling | PR 2a — inkwell | code-documentation | After all Hardening |
| Sibling | PR 2b — lintguini | lint-posture | After 2a, parallel with 2c |
| Sibling | PR 2c — towncrier `:audit` extension | event-emission | After 2a, parallel with 2b |

Each sibling PR follows the Phase 1.5 PR 3b precedent: mechanical scorers wherever possible, rubric doc updated with mechanical/judgment split, harness-verified variance ≤ 1.0 and grade-flip rate ≤ 5% on a dedicated fixture. Each sibling ships an `:audit` skill at `plugins/<plugin>/skills/audit/SKILL.md` per ADR-005 §1, emitting `observations[]` per ADR-005 §3.

**Field-shape note.** Sibling `plugin.json` declarations use the existing `pronto.audits[]` shape from `sibling-audit-contract.md`, with one entry per participating sibling whose `command` is `/<plugin>:audit --json` per ADR-005 §1. ADR-005 specifies the skill name and the observations payload but does not change the `plugin.json` declaration shape; a future ADR may simplify `pronto.audits[]` to a singular `pronto.dimension` if multi-audit-per-plugin is genuinely retired, but that's out of scope for Phase 2.

## Out of scope

- **Avanti Phase 1b** — tracked in `project/plans/active/phase-1-avanti.md`. Unlocks `project-record` depth scoring independently of this phase.
- **Release-notes authoring sibling.** Earlier drafts of Phase 1 inherited a stale "towncrier → release notes" framing; the actual `plugins/towncrier/` is a hook-event observability plugin (and Phase 2 extends *that* plugin with its `:audit` skill, per ADR-005). A release-notes authoring sibling — under whatever name — is its own scoped decision and isn't part of Phase 2's rubric coverage.
- **Shipped-sibling migrations to `:audit` + `observations[]`** (claudit, commventional). ADR-005 §5's discovery fallback keeps both shipped siblings working at step 2 (`recommendations.json` carries their legacy `audit_command`) until they migrate. Skillet already matches the convention. Migration is per-sibling work parked as a Phase 2.5 thread; the legacy `audit_command` field can be removed from `recommendations.json` once all three in-tree siblings have migrated.
- **Native `--json` adoption for shipped siblings.** Parser-agent glue works today. Native emission retires the glue but is per-sibling work, sequenced with the migration above.
- **Third-party sibling SDK / developer documentation.** ADR-004 and ADR-005 together specify the on-ramp; a publishable SDK with tests and a reference implementation is follow-up once Phase 2 siblings exercise the contract for real.
- **Rubric rebalancing (B1-B5 from the Phase 1 dogfood).** Tuning exercise, not a build-out.
- **UX polish.** C-series items remain deferred.
- **`pronto:health` constellation walker.** ADR-005 §2 reserves `:doctor` as the optional self-health entrypoint; a meta command that walks the constellation calling each sibling's `:doctor` is future scope, not Phase 2.
- **`:fix` skill convention.** ADR-005 §4 reserves the name; the contract is deferred to a future ADR.

---

## PR H1 — compatible_pronto enforcement

### Why

ADR-004 introduced an optional `compatible_pronto` version range under the `pronto` block in each sibling's `plugin.json`. No sibling declares it today and pronto does not read it. Shipping Phase 2 siblings without the handshake in place means every version-skew scenario ADR-004 documented (out-of-range → version-mismatch finding; unset → soft finding; in-range → dispatch normally) is silently wrong in practice.

### Ticket H1 — wire compatible_pronto into dispatch path

**Change:** Extend pronto's sibling-discovery path to (a) parse `pronto.compatible_pronto` from each installed sibling's `plugin.json`, (b) compare against pronto's own version (read from its own `plugin.json`), (c) emit a finding per the three branches in ADR-004 §2. Uses `semver`-style range parsing; implementation can lean on a small shell/jq helper rather than pulling in a runtime dependency.

**Acceptance:** fixture that installs a sibling with `compatible_pronto: ">=99.0.0"` triggers a version-mismatch finding and skips the sibling's audit; composite falls back to presence-only for that dimension. Fixture with `compatible_pronto: ">=0.1.0"` dispatches normally. Fixture with the field absent dispatches normally but emits the soft finding.

---

## PR H2 — orchestrator JSON-emission reliability

### Why

The Phase 1.5 PR 3b eval harness recorded **1/10 non-JSON stdout failures at baseline and 3/10 post-T5** (per `project/tickets/closed/phase-1-5-a2-harness-proof.md`). A post-refactor N=3 smoke showed 3/3 clean, suggesting the failure rate is sensitive to spec density and invocation conditions. The ticket explicitly *defers* a full N=10 re-measurement on the grounds that PR 3b's acceptance bar concerns scoring variance, not sub-Claude reliability — fair scope-discipline call there. Phase 2 picks the re-measurement up: dispatching three more siblings through the same orchestrator code path makes sub-Claude reliability a first-class concern. The harness reports `FAIL (non-JSON stdout)` for failing runs and drops them from the stddev calculation, which is why PR 3b's "stddev=0" is technically correct but narrow: the 0 applies to runs that *produced valid JSON*.

Even at the ticket's lower bound (1/10), a ~10% failure rate on audit invocations means consumers running `/pronto:audit` see intermittent non-emission. Before adding three more siblings that dispatch through the same orchestrator code path, the failure mode needs diagnosis and a fix.

### Ticket H2a — diagnose the failure mode

**Change:** instrument the orchestrator's sub-Claude dispatch to capture full stdout+stderr+exit for failing invocations. Categorize: (1) prose contamination (audit emits the JSON plus surrounding human-readable text), (2) timeout / partial-emission, (3) prompt-contract violation (audit returns a refusal or an apology), (4) other. Sample size ≥ 20 failing invocations.

**Acceptance:** ticket-closed record names the dominant failure mode with supporting evidence.

### Ticket H2b — remediate the dominant failure mode

**Change:** depends on H2a. Likely candidates: tighten the audit SKILL's output contract with an explicit refusal clause, run sub-Claude with `--json-only` output mode if one exists, or post-process to extract the JSON block robustly. Prefer contract-level fixes over post-process hacks.

**Acceptance:** the eval harness re-run on the same `mid` fixture shows JSON-emission success rate ≥ 95% over N=20. The 95% bar is deliberate: 99% fails the gate on a single genuine rare failure (network blip, runtime hiccup) and becomes noise; 90% would let a 3x regression from the measurement point (70% success, per the 3/10 ticket figure) pass silently. 95% over N=20 allows at most one failure and rejects any regression from a fixed H2b fix.

---

## PR H3 — wire contract `$schema_version: 2` + `observations[]`

### Why

ADR-004 (Consequences > Neutral) flagged the follow-up explicitly: *"versioning the wire contract itself — adding a schema-version header to `sibling-audit-contract.md` — is a follow-up."* ADR-005 §3 then specified the field that the version bump carries: a top-level `observations: []` array, deliberately distinct from the existing `categories[].findings[]` array. The two changes belong in the same wire-contract revision — versioning without a payload change is busywork, and the payload change without a version bump leaves consumers unable to negotiate.

### Ticket H3 — bump wire contract to schema 2 with observations[]

**Change:** in `plugins/pronto/references/sibling-audit-contract.md`, add a parseable `$schema_version: 2` marker (frontmatter or a versioned section header). Add the top-level `observations: []` array specification per ADR-005 §3 — `id`, `kind` (`ratio | count | presence | score`), `evidence` (object), `summary`. Document that `observations[]` is the rubric-scoring channel and is distinct from `categories[].findings[]` (which carries triaged human-readable issues with severity `critical|high|medium|low|info`). Preserve the optional legacy `score` field for back-compat per ADR-005's passthrough rule.

**Acceptance:** the doc carries the `$schema_version: 2` marker and a fully-specified `observations[]` schema; ADR-005 §3 cross-reference resolves cleanly; ADR-004's earlier "version exists in the registry but not on the contract doc itself" gap closes.

---

## PR H4 — observations-aware scorer in pronto

### Why

ADR-005 §3 names the architectural split: *"Siblings are the domain authority on what's there; pronto is the authority on what it's worth."* H3 specifies the field; H4 adds the consumer. Without H4, siblings can emit `observations[]` per the new contract and pronto's scorers don't know what to do with them — the architecture exists on paper but doesn't run. New Phase 2 siblings (2a/2b/2c) all ship emitting `observations[]` from day one, so H4 is on the critical path before any sibling PR.

### Ticket H4 — add the observations-aware scoring path

**Change:** extend pronto's scoring path in `plugins/pronto/agents/parsers/scorers/` (or a new shared helper) to (a) read `observations[]` from a sibling's audit JSON, (b) apply rubric-defined translation rules per dimension (e.g. `ratio >= 0.8 → 80/100`, threshold ladders, count-based scoring), (c) fall back to the legacy `score` field via the passthrough rule from ADR-005 §3 when `observations[]` is absent (treats `score` as a single coarse observation of `kind: score`). Rubric translation rules live in `plugins/pronto/references/rubric.md` alongside the existing mechanical/judgment split documentation.

**Acceptance:** fixture with a sibling emitting `observations[]` produces a deterministic dimension score via the new path; fixture with a sibling emitting only the legacy `score` field produces the same score it does today via the passthrough; fixture with both present prefers `observations[]`. Eval harness on the existing `mid` fixture set shows composite stddev still ≤ 1.0 — this verifies the passthrough rule preserves shipped-sibling scores (today's siblings emit `score` only); observations-path variance is exercised by the per-dimension fixtures shipped in 2a/2b/2c.

---

## PR 2a — inkwell (code-documentation)

### Scope

Audits the `code-documentation` rubric dimension. Presence check from `recommendations.json` today is *"README.md at repo root with >=10 non-blank lines"*. Inkwell deepens that to cover: docs folder presence, ratio of public APIs to documentation, staleness (last-modified vs last-code-change in the same tree), broken internal links.

### Rubric alignment

Current cap: presence-only 50/100 on a clean README, 0 on missing README. Full depth with inkwell: composite across (a) README quality, (b) docs coverage, (c) staleness, (d) link health. Target weight within the dimension TBD in the ticket — start with equal quarters, rebalance after fixtures are calibrated.

### Tickets

- **2a1 — Plugin scaffold.** `plugins/inkwell/` with `plugin.json`, README, LICENSE (MIT per repo convention), `skills/audit/SKILL.md` per ADR-005 §1, stub parser agent (transitional — retired once mechanical scoring covers the dimension). `plugin.json` declares `pronto.compatible_pronto` (consuming H1) and a single `pronto.audits[]` entry: `{dimension: "code-documentation", command: "/inkwell:audit --json"}`.
- **2a2 — Shell scorers.** Four deterministic scorers (one per category above), same mechanical pattern as Phase 1.5 PR 3b. Each emits a single `observations[]` entry consumed by H4's scoring path.
- **2a3 — Contract compliance + fixture.** `:audit` skill emits pronto-compatible `--json` with `observations[]` per the H3 schema, ships a `low/mid/high` fixture set in `plugins/inkwell/tests/fixtures/`. Acceptance: eval harness shows per-dimension stddev ≤ 1.0 and grade-flip rate ≤ 5% over N=10 on each fixture.

---

## PR 2b — lintguini (lint-posture)

### Scope

Audits the `lint-posture` rubric dimension. Presence check today: *"Language-appropriate lint config file exists"*. Lintguini deepens that to cover: config strictness vs defaults, presence of format tool (prettier/black/gofmt equivalent), CI wiring for lint, count of silenced rules.

### Rubric alignment

Full depth: composite across (a) linter present + configured, (b) formatter present + configured, (c) CI runs lint, (d) suppression count (fewer = better). Detects the common bait-and-switch where a repo has an eslint config but no CI gate and 200 `eslint-disable` comments.

### Tickets

- **2b1 — Plugin scaffold.** Same shape as 2a1: `plugin.json`, README, LICENSE, `skills/audit/SKILL.md`, `pronto.compatible_pronto`, single `pronto.audits[]` entry: `{dimension: "lint-posture", command: "/lintguini:audit --json"}`.
- **2b2 — Language detection + shell scorers.** Dispatch by repo-language detection (check for `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.); run the matching scorer. Deterministic. Each scorer emits an `observations[]` entry.
- **2b3 — Contract compliance + fixtures.** `:audit` skill emits `observations[]` per the H3 schema; multi-language fixture set (at minimum: JS, Python, Go) to exercise the language dispatch. Acceptance: eval harness shows per-dimension stddev ≤ 1.0 and grade-flip rate ≤ 5% over N=10 on each fixture language.

---

## PR 2c — towncrier `:audit` extension (event-emission)

### Scope

Audits the `event-emission` rubric dimension. Presence check today: *"Observability instrumentation grep matches"*. The towncrier `:audit` extension deepens that to cover: structured-logging use (JSON envelopes vs freeform `console.log`/`print`), metrics instrumentation presence (OTel, statsd, prometheus client), trace propagation in request handlers, consistency of event schemas across emission sites.

This sibling extends the existing `plugins/towncrier/` plugin rather than introducing a new plugin. Towncrier is already the in-house canonical example of event-emission good practice (it captures Claude Code hook events into a structured stream); ADR-005's doer-judges-itself architecture says the plugin doing the work is the natural auditor of that work in target codebases. Earlier drafts of this plan proposed a separate `autopompa` sibling; that shape was retired by ADR-005.

### Rubric alignment

Full depth: composite across (a) structured logging ratio, (b) metrics presence, (c) trace propagation, (d) event schema consistency. The hardest of the three audit siblings because event-emission spans more code surface — expect a larger parser or more scorer scripts.

### Tickets

- **2c1 — Add `:audit` skill to towncrier.** New `plugins/towncrier/skills/audit/SKILL.md` per ADR-005 §1. Updates `plugin.json`: bump version, declare `pronto.compatible_pronto` (consuming H1), and add a single `pronto.audits[]` entry: `{dimension: "event-emission", command: "/towncrier:audit --json"}`. The existing hook-event observability surface is preserved unchanged; the audit skill is a parallel entry point.

  Sweeps the autopompa references retired by ADR-005:
  - `plugins/pronto/references/recommendations.json` event-emission row: `recommended_plugin: autopompa → towncrier`, set `install_command: /plugin install towncrier@quickstop` and `audit_command: /towncrier:audit --json`, populate `parser_agent` once 2c2/2c3 land.
  - `plugins/pronto/references/rubric.md` (lines 16, 46, 95): autopompa → towncrier in the rubric table, the Phase 2+ list, and the mechanical-check column.
  - `plugins/pronto/references/roll-your-own/event-emission.md`: rewrite the document's framing to reference towncrier instead of autopompa as the recommended depth auditor.
  - `plugins/pronto/references/report-format.md` (line 115): autopompa → towncrier in the example notes string.
  - `plugins/pronto/skills/status/SKILL.md` (line 101): autopompa → towncrier in the recommended-sibling output.

  Acceptance: `/towncrier:audit` runs standalone against a target codebase and emits valid wire-contract JSON; `grep -ri autopompa plugins/pronto/` returns zero matches.
- **2c2 — Shell scorers for event-emission.** Four deterministic scorers (one per rubric category above); grep-heavy, may need per-language variants. Each emits an `observations[]` entry. Lives under `plugins/towncrier/scorers/` or analogous; same mechanical pattern as Phase 1.5 PR 3b.
- **2c3 — Contract compliance + fixtures.** `:audit` skill emits `observations[]` per the H3 schema; fixture set includes at least one case where structured-logging grep matches pass but the structured-logging ratio scorer returns < 0.5, so surface-level presence checks don't silently inflate the composite. Acceptance: eval harness shows per-dimension stddev ≤ 1.0 and grade-flip rate ≤ 5% over N=10 on the fixture set, including the structured-logging-bait case.

---

## Acceptance bar for Phase 2 completion

- All four Hardening PRs merged (H1, H2, H3, H4).
- All three audit-sibling PRs merged (2a + 2b + 2c).
- Pronto version bumped per sibling PR following the established convention.
- Every new sibling declares `compatible_pronto` against shipping pronto version.
- Every new sibling exposes `:audit` per ADR-005 §1 and emits `observations[]` per ADR-005 §3.
- Eval harness re-run on the existing `mid` fixture shows composite stddev still ≤ 1.0 and grade-flip rate ≤ 5% with all new siblings installed.
- `/pronto:audit --json` JSON-emission success rate ≥ 95% over N=20 (the H2 acceptance carries forward as a phase gate).

---

## Links

- Pronto meta: `project/plans/active/phase-1-pronto.md`, `project/plans/active/phase-1-5-pronto.md`
- Avanti meta: `project/plans/active/phase-1-avanti.md`
- Sibling composition contract: `project/adrs/004-sibling-composition-contract.md`
- Sibling skill conventions: `project/adrs/005-sibling-skill-conventions.md`
- Wire contract spec: `plugins/pronto/references/sibling-audit-contract.md`
- Sibling registry: `plugins/pronto/references/recommendations.json`
- Rubric: `plugins/pronto/references/rubric.md`
