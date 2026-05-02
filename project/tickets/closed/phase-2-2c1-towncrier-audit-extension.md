---
id: 2c1
plan: phase-2-pronto
status: closed
updated: 2026-05-02
---

# 2c1 — Towncrier `:audit` skill extension + autopompa references sweep

## Scope

PR 2c ships the `event-emission` audit sibling as a **towncrier
extension** rather than a separate plugin. Towncrier is already
the in-house exemplar of event-emission good practice — it captures
every Claude Code hook event into a structured stream — and ADR-005's
doer-judges-itself architecture says the plugin doing the work is the
natural auditor of that work in target codebases. Earlier drafts of
the plan proposed a separate `autopompa` sibling; ADR-005 retired
that shape, and this PR retires the references.

2c1 is the **structural ticket**. It does two things:

1. Adds an `:audit` skill to the existing `plugins/towncrier/`
   plugin per ADR-005 §1, declares it natively in `plugin.json` via
   `pronto.audits[]`, declares `pronto.compatible_pronto` (consuming
   H1), and adds the ADR-006 §1 Plugin surface section to towncrier's
   README enumerating the now-two-skill surface plus the existing
   hook handler.
2. Sweeps the autopompa references retired by ADR-005 across
   `plugins/pronto/`. Six files in total — five under `references/`
   plus the `status` skill.

The 2c1 PR is **emission-shaped, not score-shaped**, mirroring 2a1.
The `:audit` skill emits a wire-contract envelope with
`observations: []` (empty). The translator's case-3 carve-out (empty
observations[] falls through to passthrough) keeps `recommendations.json`
as the authoritative discovery record until 2c3 wires the rubric
stanza, retires the empty-array short-circuit, and lights up the
end-to-end path. The scorers (2c2) and the contract compliance +
locked fixtures (2c3) build on top of this scaffold.

This ticket is **heavier than 2a1 / 2b1**. Inkwell and lintguini
were fresh plugin scaffolds; towncrier already exists, ships a hook
handler covering 26 events, and is referenced by name across pronto's
references tree. 2c1 must (a) extend the existing plugin without
disturbing its hook-emission surface and (b) finish the autopompa→
towncrier sweep ADR-005 left dangling. Both motions are scoped here
so the dispatch path lights up atomically with the scorers and the
rubric stanza in 2c2/2c3.

## Why this is an extension, not a fresh plugin

Towncrier already exists at `plugins/towncrier/` (v0.1.0) with a
single skill-less surface: the hook handler in `hooks/hooks.json`
that dispatches every Claude Code hook event through `bin/emit.sh`.
That surface is preserved unchanged by 2c1; the audit skill is a
parallel entry point.

Three reasons the audit role lands as a towncrier extension rather
than a new sibling:

1. **ADR-005 §1's doer-judges-itself principle.** The plugin doing
   the work is the natural auditor of that work. Towncrier is the
   in-tree canonical example of event-emission practice — capturing
   structured events, dispatching through pluggable transports,
   masking nothing on the boundary. Splitting the auditor out into
   a sibling plugin would put two halves of the same competence
   under separate maintenance.
2. **ADR-005's autopompa retirement.** Earlier plan drafts named
   the auditor `autopompa`; ADR-005 retired that shape explicitly.
   Filing the work under a new plugin name now would re-introduce
   the split ADR-005 closed.
3. **No existing surface conflict.** Towncrier ships no skills today,
   so the `audit` skill slot is free. The hook handler operates at
   plugin load time; the audit skill operates on `:audit` invocation.
   The two paths share no state, no config, no transport, and no
   filesystem touchpoint beyond the plugin tree itself.

## Architecture

### File tree

The shape after 2c1 lands:

```
plugins/towncrier/
├── .claude-plugin/
│   └── plugin.json           # bumped, pronto block added
├── README.md                 # gains ADR-006 §1 Plugin surface section
├── LICENSE                   # unchanged
├── bin/
│   └── emit.sh               # unchanged
├── config/
│   └── config.example.json   # unchanged
├── hooks/
│   └── hooks.json            # unchanged
├── skills/
│   └── audit/
│       └── SKILL.md          # NEW — emits empty observations[] envelope (2c1)
└── tests/                    # populated by 2c3
```

The directory shape mirrors `plugins/inkwell/` (post-2a1) for the
audit-skill slot: `skills/audit/SKILL.md` with the same frontmatter
pattern (`disable-model-invocation: true`, `allowed-tools` scoped to
read-only file inspection plus `Bash` for the deterministic scorers
2c2 introduces).

**No transitional parser agent is shipped.** Inkwell and lintguini
shipped `agents/parse-<plugin>.md` stubs in their scaffold tickets
to satisfy ADR-005 §5 step 2 during the transition. 2a3 / 2b3 then
documented the new-pattern-sibling Discovery posture (`parser_agent:
null` from the outset of step-1 dispatch). 2c1 short-circuits that:
since 2c1 is built post-2a3/2b3, there is no period during which a
step-2 fallback is useful, and the parser-agent path is structurally
unreachable for new-pattern siblings (see 2c3's Discovery posture
section). Skipping the transitional file means 2c3 doesn't have a
follow-up to remove it.

### `plugin.json` shape

Existing file (v0.1.0, no `pronto` block). 2c1 adds the `pronto`
block and bumps the version to `0.2.0`:

```json
{
  "name": "towncrier",
  "version": "0.2.0",
  "description": "Emit a structured JSON event for every Claude Code hook to a configurable transport (file, fifo, or HTTP).",
  "author": {
    "name": "Anthony Costanzo",
    "url": "https://github.com/acostanzo"
  },
  "license": "MIT",
  "keywords": ["hooks", "observability", "telemetry", "events", "logging", "eventbus"],
  "homepage": "https://github.com/acostanzo/quickstop/tree/main/plugins/towncrier",
  "pronto": {
    "compatible_pronto": ">=0.4.0",
    "audits": [
      {
        "dimension": "event-emission",
        "command": "/towncrier:audit --json",
        "weight_hint": 0.05
      }
    ]
  }
}
```

`weight_hint: 0.05` matches the `event-emission` rubric weight in
`plugins/pronto/references/rubric.md` (line 16, weight 5). The
`compatible_pronto` floor is set against pronto's currently-shipping
version (v0.4.0); 2c3 may bump the floor when the rubric stanza
lands, mirroring how 2a3 / 2b3 set their compatible_pronto floors
against the pronto version they shipped alongside.

The version bump from 0.1.0 → 0.2.0 is a minor bump (new public
surface — the `:audit` skill — and a new declaration block consumed
by pronto's discovery). The hook-emission surface is unchanged.

### `skills/audit/SKILL.md` (2c1 stub shape)

The 2c1 SKILL.md establishes the contract slot: parse `--json` flag,
emit a wire-contract envelope to stdout, route human-readable output
to stderr. The 2c1 envelope is emission-shaped only:

```json
{
  "$schema_version": 2,
  "plugin": "towncrier",
  "dimension": "event-emission",
  "categories": [],
  "observations": [],
  "composite_score": null,
  "recommendations": []
}
```

Empty `observations[]` exercises the translator's case-3 carve-out
(passthrough). `composite_score: null` is what the translator reads
when populating the dimension; combined with the empty array it
defers scoring back to the kernel presence check
(`event-emission` instrumentation grep → 50 capped). Behaviour is
end-to-end equivalent to today's "sibling not installed" branch, so
2c1 ships without changing any existing harness numbers.

2c2 fills in the deterministic scorers; 2c3 wires them into the
envelope and removes the empty-array short-circuit.

Frontmatter mirrors inkwell's 2a1 SKILL.md:

```yaml
---
name: audit
description: Audit a target codebase's event-emission posture and emit a wire-contract envelope on stdout.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---
```

`disable-model-invocation: true` is the ADR-005 §1 convention for
deterministic audit skills. `Bash` is in the allowed-tools set so
2c2's scorer dispatch and 2c3's orchestrator have a path forward.

### ADR-006 §1 Plugin surface section (added to README)

Towncrier's README is the most consumer-facing in the marketplace
(it ships a hook handler, so installation drops the consumer into
event capture immediately). The ADR-006 §1 surface section makes
the now-two-entry-point shape explicit and acknowledges the
opinionated transport / fallback behaviour:

```markdown
## Plugin surface

This plugin ships:
- Skills: `audit`
- Commands: none
- Agents: none
- Hooks: 26 — one per documented Claude Code hook event,
  each dispatching through `bin/emit.sh` to the configured
  transport (`file:` / `fifo:` / `http(s):`)
- Opinions: writes the event envelope to the configured
  transport (default: `~/.towncrier/events.jsonl`); falls
  back to the same default file if the configured transport
  fails. The `bin/emit.sh` script always exits 0 and emits
  nothing on stdout — the hook flow is pass-through.

The hook handlers respect the ADR-006 §3 invariants: no
`hookSpecificOutput` payload-shaping, no persistent host state
mutation at hook time (writes are confined to the configured
event sink the consumer opted into), no undeclared writes
outside the declared transport target.

The audit skill operates strictly read-only on `<REPO_ROOT>` —
no consumer-config edits, no auto-installation of dependencies,
no cross-plugin automation. Consumers compose automation against
this plugin's capabilities per ADR-006 §6.
```

The ADR-006 §1 wording "writes the event envelope to the configured
transport" is deliberately specific. Towncrier's whole point is to
write to a sink the consumer configured; that's not silent mutation
under §2 — it's the contracted opinion the consumer signed up for
when installing the plugin. The wording above makes the contract
visible without overclaiming non-mutation.

### ADR-006 §3 invariants (existing — preserved)

`bin/emit.sh` is already ADR-006 §3-conformant:

- **No `hookSpecificOutput` payload mutation.** The script writes
  nothing to stdout (line 9 of the script: "writes nothing to stdout
  and exits 0"). Claude's hook flow runs unchanged regardless of the
  audit-skill addition.
- **No persistent host state mutation outside the declared event
  sink.** The script's only writes are the event envelope to the
  configured transport (file / fifo / HTTP) plus the
  `~/.towncrier/events.jsonl` fallback. Both sinks are the
  consumer's contracted opt-in (set via `~/.towncrier/config.json`
  or the `TOWNCRIER_TRANSPORT` env var).
- **No undeclared writes.** No state under `~/.claude/`, no edits
  to the consumer's `.claude/settings.json`, no edits to any file
  outside the declared transport target.

The `:audit` skill must not regress this posture. The audit skill
operates strictly read-only on `<REPO_ROOT>` — no writes outside
its own scratch tempfiles (which live under `mktemp -t` and clean
themselves via `trap`), no reads outside `<REPO_ROOT>` except for
the scorer scripts themselves under the plugin tree.

### Autopompa references sweep

ADR-005 retired the `autopompa` plugin name. Five files in total
under `plugins/pronto/` carry references — four under `references/`
plus the `status` skill; this ticket sweeps them.

| File | Line(s) | Change |
|---|---|---|
| `plugins/pronto/references/recommendations.json` | line 63 | `recommended_plugin: autopompa → towncrier`. **`plugin_status` stays `phase-2-plus`** in 2c1 (flips to `shipped` in 2c3). `install_command` and `audit_command` stay `null` in 2c1 (populated in 2c3). `parser_agent` stays `null` (see Discovery posture below — it stays `null` permanently for new-pattern siblings). |
| `plugins/pronto/references/rubric.md` | line 16 | `recommended sibling` column: `autopompa → towncrier`. Description column unchanged in 2c1 (rewritten in 2c3 to depth-signal summary). Status column unchanged (`Phase 2+` → `Shipped` flips in 2c3). |
| `plugins/pronto/references/rubric.md` | line 46 | Phase-2+ list paragraph: `autopompa is Phase 2+` → `towncrier's :audit extension is Phase 2+`. Stays in the Phase-2+ list until 2c3 ships. |
| `plugins/pronto/references/rubric.md` | line 95 | Mechanical-vs-judgment table row: `sibling autopompa not yet shipped` → `sibling towncrier's :audit extension not yet shipped`. Row rewritten in 2c3 to point at the new translation rules section. |
| `plugins/pronto/references/roll-your-own/event-emission.md` | lines 3, 5, 97 | Reframe: "Autopompa (Phase 2+) is the recommended depth auditor for observability posture" → "Towncrier's `:audit` extension (Phase 2+) is the recommended depth auditor for observability posture." Also flip line 97's "until autopompa ships" → "until towncrier's `:audit` extension ships." Body content (the depth signals enumeration) stays unchanged — towncrier audits the same depth signals autopompa would have. |
| `plugins/pronto/references/report-format.md` | line 115 | Example notes string: `"autopompa not installed; observability grep found no matches"` → `"towncrier not installed; observability grep found no matches"`. |
| `plugins/pronto/skills/status/SKILL.md` | line 101 | Verbose-snapshot example output line: `recommended: autopompa (Phase 2+)` → `recommended: towncrier (Phase 2+)`. |

**Acceptance:** `grep -ri autopompa plugins/pronto/` returns zero
matches after this sweep. Note: this verifies pronto-side cleanup;
the canonical plan doc (`project/plans/active/phase-2-pronto.md`)
retains a single historical reference at line 18 ("Earlier drafts
of this plan proposed a separate autopompa sibling; ADR-005 retired
that shape") which is intentional history-of-decision context, not
a stale recommendation. The grep scope is intentionally `plugins/pronto/`,
not the full repo.

**No populated `parser_agent` value.** A clean replacement would
have set `parser_agent: parsers/towncrier` here and retired it later.
2c1 skips that step: per the Discovery posture rationale documented
in 2a3 (`f90cc5e` precedent) and 2b3, `parser_agent` is permanently
`null` for new-pattern siblings that declare `pronto.audits[]`
natively. Populating it now just to retire it later would be
churn — the cleaner shape is to start at `null` and keep it.

**`install_command` and `audit_command` stay `null` in 2c1.**
Plan-doc line 171 enumerates these fields as part of the 2c1 sweep
(`set install_command: /plugin install towncrier@quickstop and
audit_command: /towncrier:audit --json`). 2c1 deviates: both fields
are deferred to 2c3 alongside the rubric stanza. The deviation
matches the established 2a / 2b precedent — lintguini's install /
audit fields were populated in 2b3 commit `acb834e`
("feat(pronto): ship lint-posture as fully-translated dimension"),
and inkwell's in 2a3 commit `bd9c6e4` (same shape) — not in either
plugin's scaffold ticket.

The semantic reason: until the rubric stanza is in place (2c3),
populating `audit_command` would direct pronto's discovery to
dispatch through `/towncrier:audit --json` for a dimension that
has no translation rubric yet. The dimension would still resolve
correctly via case-3 passthrough (empty `observations[]` →
presence-cap), but keeping discovery flat-presence-shaped until
the contract layer is ready avoids a transient half-wired state
where dispatch happens but scoring degrades silently. The fields
light up atomically with the rubric stanza in 2c3, mirroring 2a3
/ 2b3. The plan-doc enumeration on line 171 reflects an earlier
draft authored before the 2a / 2b sequencing precedent solidified;
treat the precedent as authoritative.

The recommendations.json row after the sweep:

```json
{
  "dimension": "event-emission",
  "dimension_label": "Event emission",
  "recommended_plugin": "towncrier",
  "plugin_status": "phase-2-plus",
  "install_command": null,
  "audit_command": null,
  "parser_agent": null,
  "roll_your_own_ref": "roll-your-own/event-emission.md",
  "presence_check": "Observability instrumentation grep matches"
}
```

### License

Unchanged — towncrier already ships MIT under
`plugins/towncrier/LICENSE`. The 2c1 PR doesn't touch it.

## Implementation order

1. **`plugins/towncrier/skills/audit/SKILL.md`** — new file.
   Frontmatter (`name: audit`, `description`,
   `disable-model-invocation: true`,
   `allowed-tools: Read, Glob, Grep, Bash`,
   `argument-hint: --json`). Body: parse `$ARGUMENTS` for `--json`,
   emit the empty-envelope wire shape to stdout, route diagnostic
   output to stderr. No scorers invoked yet — those land in 2c2.
2. **`plugins/towncrier/.claude-plugin/plugin.json`** — bump
   `version` to `0.2.0`; add `pronto` block (`compatible_pronto`,
   `audits[]` entry).
3. **`plugins/towncrier/README.md`** — add the ADR-006 §1
   Plugin surface section per the wording above. Keep the rest of
   the README unchanged.
4. **`.claude-plugin/marketplace.json`** — match the version bump
   per CLAUDE.md's marketplace-management rule.
5. **Root README.md** — update the displayed towncrier version per
   CLAUDE.md's marketplace-management rule.
6. **`plugins/pronto/references/recommendations.json`** —
   autopompa → towncrier on line 63. `plugin_status` stays
   `phase-2-plus`; all command fields stay `null` (lit up in 2c3).
7. **`plugins/pronto/references/rubric.md`** — autopompa → towncrier
   at lines 16, 46, 95. Description, status, mechanical-vs-judgment
   row text otherwise unchanged in 2c1.
8. **`plugins/pronto/references/roll-your-own/event-emission.md`** —
   reframe lines 3, 5, 97 from autopompa to towncrier. Body content
   (depth signals, anti-patterns, presence check) unchanged.
9. **`plugins/pronto/references/report-format.md`** — autopompa →
   towncrier on line 115.
10. **`plugins/pronto/skills/status/SKILL.md`** — autopompa →
    towncrier on line 101.
11. **`plugins/pronto/.claude-plugin/plugin.json`** — patch bump
    `version` to `0.4.1` for the references sweep above. Per the
    PR #80 review resolution, the patch bump keeps the version-check
    script exit 0 without claiming the rubric-stanza surface change
    that drives the minor bump in 2c3.
12. **`.claude-plugin/marketplace.json`** — match the pronto patch
    bump per CLAUDE.md's marketplace-management rule.
13. **Root README.md** — update the displayed pronto version to
    v0.4.1 per CLAUDE.md's marketplace-management rule.
14. **`./scripts/check-plugin-versions.sh`** — run, must exit 0.

## Acceptance

- `/towncrier:audit --json` runs standalone and emits a single valid
  JSON object on stdout matching the empty-envelope shape above.
- Stdout is exactly one JSON object — no human-readable text, no
  log lines.
- `jq -e '."$schema_version" == 2 and .plugin == "towncrier" and .dimension == "event-emission" and .observations == []' <output>` passes.
- `plugin.json` declares `pronto.compatible_pronto` (consumed by H1)
  and exactly one `pronto.audits[]` entry for the
  `event-emission` dimension.
- Towncrier version bumped to `0.2.0` consistently across
  `plugins/towncrier/.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, and root `README.md`.
- Pronto patch-bumped to `0.4.1` consistently across
  `plugins/pronto/.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, and root `README.md` (covers
  the references sweep — see Out of scope's Pronto version bump
  bullet for the minor-vs-patch rationale).
- `./scripts/check-plugin-versions.sh` exits 0.
- README contains a "Plugin surface" section per ADR-006 §1
  enumerating skills, commands, agents, hooks (26 — listed in the
  existing "What it covers" section, referenced by count here),
  and opinions (the configurable transport + fallback behaviour).
  The non-mutation declaration acknowledges the contracted
  transport-write opinion explicitly.
- `bin/emit.sh` and `hooks/hooks.json` are unchanged — 2c1 does
  not modify the existing hook surface.
- `grep -ri autopompa plugins/pronto/` returns zero matches.
- `recommendations.json`'s `event-emission` row reads
  `recommended_plugin: towncrier` with `plugin_status:
  phase-2-plus`. `install_command`, `audit_command`, `parser_agent`
  all `null`.
- `rubric.md`'s `event-emission` row (line 16), Phase-2+ paragraph
  (line 46), and mechanical-vs-judgment row (line 95) all reference
  towncrier rather than autopompa. Description / status / row text
  bodies otherwise unchanged in 2c1 (rewritten in 2c3).
- `roll-your-own/event-emission.md` references towncrier in the
  framing lines (3, 5, 97); body unchanged.
- `report-format.md` example notes string references towncrier.
- `status/SKILL.md` verbose-snapshot example references towncrier.
- No regression on existing dimensions — eval harness on the pinned
  `mid` worktree fixture: composite stddev still ≤ 1.0 with the
  towncrier 2c1 scaffold installed but emitting empty
  observations[] (case-3 passthrough → kernel presence check
  unchanged). Snapshot tests for claudit, skillet, commventional,
  inkwell, lintguini all still pass byte-equivalent.
- No changes to `plugins/claudit/`, `plugins/skillet/`,
  `plugins/commventional/`, `plugins/inkwell/`, `plugins/lintguini/`,
  or `plugins/avanti/` (verified via
  `git diff main..2c1-towncrier-audit-extension -- 'plugins/'`
  showing only `plugins/towncrier/`, `plugins/pronto/references/`,
  `plugins/pronto/skills/status/SKILL.md`, and
  `plugins/pronto/.claude-plugin/plugin.json` paths — the last for
  the patch bump only).

## Three load-bearing invariants

A. **Empty-envelope is wire-contract-valid.** The translator must
accept the 2c1 envelope without raising. Verified by feeding the
literal envelope to `observations-to-score.sh` in
`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`
under a new "case-3 passthrough on towncrier scaffold" test.

B. **Hook surface unchanged.** Adding the audit skill must not
perturb towncrier's existing hook-emission behaviour. Verified by
(a) `bin/emit.sh` and `hooks/hooks.json` byte-identical to pre-PR
state, and (b) a manual smoke that towncrier's hook still fires and
writes to the configured transport when invoked under a fresh
`claude --plugin-dir` session.

C. **Discovery resolves at step 2 in 2c1, step 1 in 2c3.** With 2c1
alone, `recommendations.json` still carries `audit_command: null`
for event-emission, so pronto's discovery falls through to the
kernel presence check (50 capped). With 2c3 merged, `audit_command`
is populated and the SKILL.md exists at the canonical path, so
step 1 (`plugins/towncrier/skills/audit/SKILL.md`) wins. The
progression is intentional — 2c1 stages the directory shape and
sweeps the references, 2c3 lights up the audit path.

## Out of scope

- **The four shell scorers** (structured logging ratio, metrics
  presence, trace propagation, event schema consistency). Filed as
  2c2. The exact count is non-binding; the plan-doc suggests four
  but 2c2 may surface fewer or more during implementation. The
  rubric stanza in 2c3 is anchored against whatever shape 2c2
  ships.
- **Rubric stanza for `event-emission`** in `rubric.md`. Filed as
  2c3 — calibrated against fixtures.
- **Updating `recommendations.json`** to populate `install_command`
  and `audit_command` and flip `plugin_status` to `shipped`. Filed
  as 2c3 — happens alongside the rubric stanza so the discovery
  path lights up atomically with the rubric translation rules.
- **Pronto *minor* version bump.** Filed as 2c3 — the minor bump
  driven by the `event-emission` rubric stanza addition lands in
  2c3, mirroring 2a3 / 2b3 (lintguini's PR bumped pronto to v0.3.0;
  inkwell's PR bumped pronto to v0.4.0). Don't pin the value here —
  2c3 reads the version-check convention to determine it.

  A *patch* bump for the pronto-side autopompa references sweep
  **does** land in 2c1 (`v0.4.0 → v0.4.1`) to keep
  `./scripts/check-plugin-versions.sh` exit 0 — earlier drafts of
  this ticket framed the pronto bump as wholly out of scope, which
  conflicted with the script's mechanics (it flags any change under
  `plugins/pronto/` other than `README.md`). Resolution per PR #80
  review: a patch bump signals "we touched the references" without
  claiming new translation-rules surface; the minor bump still
  lands in 2c3 with the rubric stanza. Future siblings touching
  pronto-side references in their scaffold/extension ticket follow
  the same posture — patch bump in the references-touching PR,
  minor bump deferred to the rubric-stanza PR.
- **Transitional parser agent** under `plugins/towncrier/agents/`.
  Skipped per the rationale in the File tree section — new-pattern
  siblings built post-2a3/2b3 don't need a step-2 fallback file
  because the parser-agent path is structurally unreachable for
  natively-declared `pronto.audits[]` siblings (see 2c3's
  Discovery posture).
- **`:doctor` skill.** ADR-005 §2 reserves the name; towncrier's
  diagnostic logic (transport reachability, fallback file health)
  is plain enough that a `:doctor` slot isn't earning its keep yet.
  Add later if there's a self-health check that needs a structured
  exit code.
- **`:fix` skill.** ADR-005 §4 reserves the name; remediation is
  a future ADR.
- **Towncrier's hook surface.** `bin/emit.sh` and `hooks/hooks.json`
  are not modified by this ticket. The audit skill is a parallel
  entry point.
- **Native `--json` adoption sweep across legacy siblings.** Tracked
  separately under M1/M2/M3 follow-ups; not 2c1's concern.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2c ticket roster
  and the autopompa references enumeration this ticket
  operationalises.
- `project/adrs/004-sibling-composition-contract.md` —
  `compatible_pronto` and `audits[]` shape towncrier declares.
- `project/adrs/005-sibling-skill-conventions.md` — §1 (`:audit`
  skill convention), §3 (observations vs. score), §5 (discovery
  order). Also the autopompa retirement that this PR sweeps.
- `project/adrs/006-plugin-responsibility-boundary.md` — §1
  Plugin surface README section, §2 non-mutation declaration,
  §3 hook invariants towncrier already conforms to.
- `project/tickets/closed/phase-2-2a1-inkwell-scaffold.md` — the
  primary ticket-shape precedent. 2c1 mirrors structure; main
  deviations: existing-plugin extension (not fresh scaffold), no
  transitional parser agent, autopompa references sweep folded in.
- `project/tickets/closed/phase-2-2a3-inkwell-contract-fixtures.md` —
  the precedent for the Discovery posture (`parser_agent: null`)
  that 2c1 adopts from the outset, and that 2c3 will document
  inline. Commit `f90cc5e` (in lintguini 2b3) carries the
  cross-precedent rationale.
- `project/tickets/closed/phase-2-2b2-lintguini-scorers.md` —
  secondary ticket-shape precedent for the existing-plugin /
  scorers split.
- `plugins/pronto/references/sibling-audit-contract.md` — the v2
  wire contract this scaffold emits.
- `plugins/pronto/references/recommendations.json` — file edited
  by this ticket (line 63 row).
- `plugins/pronto/references/rubric.md` — file edited by this
  ticket (lines 16, 46, 95).
- `plugins/pronto/references/roll-your-own/event-emission.md` —
  file edited by this ticket (lines 3, 5, 97).
- `plugins/pronto/references/report-format.md` — file edited by
  this ticket (line 115).
- `plugins/pronto/skills/status/SKILL.md` — file edited by this
  ticket (line 101).
- `plugins/towncrier/bin/emit.sh` — the existing hook handler
  this ticket does **not** modify; the ADR-006 §3 conformance is
  documented above.
- `plugins/towncrier/hooks/hooks.json` — the 26-event hook
  registration this ticket does **not** modify.
- `plugins/inkwell/.claude-plugin/plugin.json` — the post-shipping
  shape towncrier's `plugin.json` mirrors for the `pronto` block.
