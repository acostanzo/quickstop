---
id: q2
plan: quickstop-dev-tooling
status: open
updated: 2026-04-29
depends_on: q1
---

# Q2 — Hone enhancements

## Scope

Hone audits existing quickstop plugins against an 8-category rubric.
Pronto-sibling compliance isn't one of those categories — hone treats
a sibling plugin and a tool plugin identically. ADR-004 / ADR-005
specify a real shape: `compatible_pronto` handshake, `:audit` skill at
the canonical path, `observations[]` emission, parser agent state,
version handshake hygiene. Q2 measures that shape.

Q2 adds:

1. A new audit subagent — `audit-pronto`.
2. A new rubric category — Pronto Compliance, weight 10%, scope-aware.
3. A **share-based renormalization** that adds Pronto Compliance to
   the rubric without reducing any single existing category's stake.
   When a plugin is a sibling, the 9 categories share weight; when
   it's not, the existing 8 categories run unchanged.
4. **Sibling detection via two paths:** plugin.json `pronto` block
   (contract-native siblings, post-migration) AND
   `plugins/pronto/references/recommendations.json` registry
   (legacy/transitional siblings like claudit and commventional
   today). Either match dispatches `audit-pronto`.
5. The same in-tree authority research extension Q1 makes (shared
   agent — when Q1 lands first, this is a no-op for Q2).

## Architecture

### New audit subagent: `.claude/agents/audit-pronto.md`

Mirrors `audit-design.md`'s shape. Read-only.

```yaml
---
name: audit-pronto
description: "Audits sibling-shape compliance — pronto block, :audit skill, wire contract emission, parser agent state, version handshake. Dispatched by /hone during Phase 2 when the plugin is sibling-detected (pronto block in plugin.json OR listed as a recommended_plugin in recommendations.json)."
tools:
  - Read
  - Glob
  - Grep
model: inherit
---
```

Body audits five surfaces:

**1. Plugin manifest pronto block**

- `pronto` block present in `plugin.json`?
- `compatible_pronto` declared? (ADR-004 §2: present = on-spec; absent
  = soft finding, since unset is allowed but not preferred.)
- `audits[]` declared? Each entry needs `dimension` + `command`.
- Dimensions in canonical list? Cross-reference
  `plugins/pronto/references/recommendations.json`.

**2. `:audit` skill compliance**

- `skills/audit/SKILL.md` exists? (ADR-005 §5 step 1 — wins over
  step-2 fallback.)
- Frontmatter: `name: audit`, `disable-model-invocation: true`,
  `allowed-tools` scoped to `Read, Glob, Grep, Bash`,
  `argument-hint: --json`.
- Body parses `$ARGUMENTS` for `--json`?
- Body splits stdout (JSON) and stderr (human-readable)?

**3. Wire contract emission**

Static analysis of the `:audit` skill body — search for the literal
strings:

- `$schema_version` — present, set to `2`?
- `observations` — emission path present?
- `composite_score` — set to `null` or computed (not hardcoded)?

**4. Parser agent state**

- `agents/parse-<name>.md` exists?
- If present, deprecation header marker present?
- If `:audit` skill exists AND parser agent exists AND parser is not
  marked deprecated, flag (both step-1 and step-2 discovery active —
  ambiguity).

**5. Version handshake hygiene**

- Read `compatible_pronto` floor; compare against current pronto
  version in `plugins/pronto/.claude-plugin/plugin.json`.
- Flag if floor is more than two minor versions stale.

**Output format:**

```markdown
## Pronto Compliance Audit

### Plugin Manifest
- pronto block present: yes/no
- compatible_pronto declared: yes/no (range: "...")
- audits[] entries: N (dimensions: ...)
- canonical dimensions: yes/no (off-canonical: ...)

### :audit Skill
- skill present: yes/no (path: ...)
- frontmatter: compliant / issues: ...
- $ARGUMENTS parsing: yes/no
- stdout/stderr split: yes/no

### Wire Contract Emission
- $schema_version: 2 marker present: yes/no
- observations[] emission path: yes/no/empty-only
- composite_score handling: null / computed / hardcoded

### Parser Agent
- present: yes/no (path: ...)
- deprecated marker: yes/no
- both-paths-active ambiguity: yes/no

### Version Handshake
- compatible_pronto floor: <range>
- staleness vs current pronto: ok / N versions behind

### Estimated Impact
- Pronto Compliance score impact: [deductions and bonuses]
```

### Sibling detection

Hone treats a plugin as a sibling — and dispatches `audit-pronto` —
when **either** of the following holds:

1. The plugin's `plugin.json` contains a `pronto` block
   (contract-native sibling — the post-migration shape).
2. `plugins/pronto/references/recommendations.json` lists this plugin
   as a `recommended_plugin` for any rubric dimension (legacy /
   transitional sibling — what claudit and commventional are today).

This dual detection means hone can audit shipped siblings before
they've migrated to the contract-native shape — and the resulting
findings are exactly the M-series migration work in
`phase-2-pronto.md`.

When neither path matches, the plugin is non-sibling: skip
`audit-pronto`, score over the existing 8 categories at their
original weights (today's behaviour, byte-equivalent).

### Rubric category: Pronto Compliance (10%)

Add to `.claude/skills/hone/references/scoring-rubric.md`:

#### Category: Pronto Compliance (10%)

**What:** Sibling-shape compliance with ADR-004 / ADR-005 — wire
contract, `:audit` skill, parser agent state, version handshake.

**When applicable:** Plugin is detected as a sibling per the dual
path above. Non-sibling plugins skip this category entirely (it does
not score 100 neutral; it is excluded from the rubric for those
plugins).

##### Deductions

| Issue | Points | Description |
|---|---|---|
| Missing `compatible_pronto` | -20 | ADR-004 §2 soft finding |
| Missing `audits[]` | -30 | No rubric participation declaration |
| Off-canonical dimension | -15 each | Dimension not in `recommendations.json` |
| Missing `skills/audit/SKILL.md` | -25 | Step-1 discovery broken |
| `:audit` frontmatter incomplete | -5 each (max -15) | Missing required field |
| `$ARGUMENTS` not parsed | -10 | Skill ignores invocation flags |
| stdout contains human-readable text | -15 | Wire contract violation |
| No `$schema_version: 2` marker | -10 | Pre-H3 emission |
| No `observations[]` emission | -15 | Legacy `score`-only — flag for migration |
| Hardcoded `composite_score` | -10 | Should be null or computed |
| Parser agent not deprecated when step-1 active | -5 | Discovery ambiguity |
| `compatible_pronto` floor >2 minor versions stale | -10 | Skew risk |

##### Bonuses

| Optimization | Points | Description |
|---|---|---|
| Clean wire-contract emission | +10 | All schema-2 fields emitted correctly |
| `:doctor` skill present | +5 | Optional self-health surface |
| All audit dimensions in canonical list | +5 | Plays well with the registry |

The deduction values are starting points calibrated against shipped
siblings. Implementation tunes against fixtures.

**Presence-gated deductions.** Several deductions check the body of
`skills/audit/SKILL.md` (`$ARGUMENTS` parsing, `$schema_version: 2`
marker, `observations[]` emission). When the audit skill itself is
absent (the -25 deduction has fired), those further deductions are
**not stacked** — the missing-skill finding subsumes them. This
avoids deduction inflation that would floor every registry-only
sibling at 0 and obscure the migration distance from
contract-native. The audit-pronto agent skips those checks when the
audit skill file is missing.

Calibration target: skillet (contract-native, post-migration in-tree)
scores ≥85. Claudit and commventional (registry-only, pre-migration)
score in the 25-45 range — well below 85 to make the migration value
visible, but not floored at 0 so the relative remediation effort is
legible.

#### Weighting — share-based renormalization

The existing 8 categories keep their relative standing. Pronto
Compliance enters with the same nominal share (10) as Metadata, Hook,
Documentation, Over-Engineering, and Security. When a plugin is
detected as a sibling, the rubric is **all 9 categories sharing 110
nominal weight**, then renormalized: each category's effective weight
is `share / 110`.

| Category | Share | Effective weight (sibling) | Effective weight (non-sibling) |
|---|---|---|---|
| Skill Quality | 20 | 18.2% | 20% |
| Structure Compliance | 15 | 13.6% | 15% |
| Agent Quality | 15 | 13.6% | 15% |
| Metadata Quality | 10 | 9.1% | 10% |
| Hook Quality | 10 | 9.1% | 10% |
| Documentation | 10 | 9.1% | 10% |
| Over-Engineering | 10 | 9.1% | 10% |
| Security | 10 | 9.1% | 10% |
| **Pronto Compliance** | **10** | **9.1%** | — (excluded) |
| **Total** | **110 / 100** | **100%** | **100%** |

Properties:

- **Non-sibling plugins are byte-equivalent to today.** No category
  weight changes; Pronto Compliance is excluded; overall scores are
  unchanged.
- **Sibling plugins see every existing category's weight reduced
  proportionally** by ~9% (the dilution from adding a 9th 10-share
  category). No category is privileged or punished; the relative
  ordering of category importance is preserved exactly.
- **Hone's stated values stay intact.** Over-Engineering and Security
  keep their full nominal share — they aren't carved into to make
  room.

The `share` field is what gets stored in the rubric file; the
`effective_weight` is computed at scoring time per the formula above.
Storing shares and computing weights at scoring time keeps the rubric
file readable as "9 ten-point categories with two 20-point and two
15-point categories" rather than as fractional percentages.

### Hone Phase 2 update

Add `audit-pronto` to the Phase 2 dispatch list, **conditional** on
sibling detection. Mechanics:

1. Before dispatching agents, run sibling detection:
   a. Read `plugins/<name>/.claude-plugin/plugin.json`; check for a
      `pronto` key.
   b. Read `plugins/pronto/references/recommendations.json`; check
      whether `<name>` appears as a `recommended_plugin` for any
      dimension.
2. If either path matches: dispatch 5 agents in parallel (existing 4
   + `audit-pronto`). The dispatch prompt for `audit-pronto`
   includes which detection path matched (so the agent can flag
   "registry-only — should migrate to contract-native shape").
3. If neither matches: dispatch 4 agents (today's behaviour);
   `audit-pronto` is skipped; Pronto Compliance is excluded from
   scoring; the rubric runs over the 8 existing categories at their
   original weights (byte-equivalent to today).

### Hone Phase 1 — research targets extended

Same change as Q1: `research-plugin-spec` reads in-tree ADRs +
sibling-audit-contract + license-selection. Already a shared agent —
landing in Q1 makes it available to Q2 with no extra work in this
ticket. If Q2 lands first (unlikely given dependency), Q2 carries the
research-agent change.

### Hone Phase 3 — scoring rubric update

Update the Categories table in `.claude/skills/hone/SKILL.md` to use
shares (not weights) and add the share-based renormalization to the
"Compute Overall Score" section:

```
total_share = sum(share_i for all applicable categories)
effective_weight_i = share_i / total_share
overall = sum(category_score_i * effective_weight_i for all applicable categories)

where applicable categories are:
  - all 9 (including Pronto Compliance) when sibling detected
  - the original 8 (excluding Pronto Compliance) when non-sibling

For non-sibling plugins total_share = 100, so effective_weight_i = share_i / 100,
which is identical to today's weights. Non-sibling scoring is byte-equivalent.

For sibling plugins total_share = 110, so each effective_weight is share_i / 110 —
~9% less than its original percentage, with Pronto Compliance taking up the slack.
```

### Hone Phase 4 — recommendation surfacing

Pronto Compliance findings flow through the existing recommendation
ranking (Critical / High / Medium / Low). The Phase 4 selector lets
the user pick which to apply, same as today.

**Note on auto-fix:** Most pronto-compliance fixes are scaffolding
shaped (add a missing field, add a missing skill, add a deprecation
marker) and overlap with smith's territory. Q2 surfaces the findings;
implementation can recommend `/smith --upgrade <plugin>` (a future
enhancement) rather than auto-applying. For now, hone applies the
straightforward edits (add a missing field) and recommends smith for
larger scaffolding work (add a missing `:audit` skill).

## Implementation order

1. **Create `.claude/agents/audit-pronto.md`** mirroring
   `audit-design.md`'s shape.
2. **Add the Pronto Compliance section** to
   `.claude/skills/hone/references/scoring-rubric.md`.
3. **Add scope-aware weight handling** to the same rubric file's
   "Scoring Algorithm" section.
4. **Update `.claude/skills/hone/SKILL.md` Phase 2** — read plugin.json
   for `pronto` key before dispatch; dispatch 4 or 5 agents
   accordingly.
5. **Update `.claude/skills/hone/SKILL.md` Phase 3** — Categories
   table reflects rebalance; "Compute Overall Score" reflects
   scope-aware weights.
6. **Update Phase 4** — Pronto Compliance findings flow through
   existing recommendation ranking; note the smith-overlap caveat.
7. **Update `research-plugin-spec`** — same change as Q1, already
   landed if Q1 ships first; otherwise carry it here.

## Acceptance

- `/hone skillet` produces a Pronto Compliance score in the report
  (skillet is sibling-detected via the `pronto` block in its
  `plugin.json`). Skillet scores ≥85/100 in that category — the most
  ADR-005-conformant in-tree sibling.
- `/hone claudit` and `/hone commventional` are sibling-detected via
  the `recommendations.json` registry path (today they have no
  `pronto` block in `plugin.json`). `audit-pronto` runs and produces
  multiple Critical findings reflecting their pre-migration state:
  missing `pronto` block entirely, missing `skills/audit/SKILL.md`
  at canonical path, no `observations[]` emission. The findings list
  matches the M1/M3 ticket scope in `phase-2-pronto.md`. The
  registry-only detection path itself surfaces a recommendation:
  "registry-only sibling — migrate to contract-native shape." Exact
  Pronto Compliance scores are calibration-dependent; the bar is
  that hone surfaces *what* needs to migrate, not *how far below
  85* the score lands.
- `/hone towncrier` (today, pre-2c) does **not** dispatch
  `audit-pronto`. Pronto Compliance is excluded from the scorecard.
  The 8 categories run unchanged. The overall score is
  byte-equivalent to today's `/hone towncrier` output.
- The visual scorecard shows 8 bars for non-sibling plugins, 9 bars
  for sibling plugins (Pronto Compliance appended at the bottom).
- `audit-pronto` produces structured output matching the agent's
  specified format (5 sections with the listed fields).
- A sibling plugin missing `compatible_pronto` (and only
  `compatible_pronto` — i.e. has a `pronto` block, has `audits[]`,
  has the `:audit` skill) produces a Critical/High finding with the
  documented point impact (-20). Use skillet edited to drop
  `compatible_pronto` as the test fixture; for registry-only
  siblings like claudit, the -20 stacks with the missing-block and
  missing-skill deductions and isn't separately verifiable.
- The dispatch prompt for `audit-pronto` includes which detection
  path matched; the agent's "Plugin Manifest" output reflects this
  ("registry-only — recommend contract-native migration" when only
  path 2 matched).

## Three load-bearing invariants

A. **Non-sibling plugins are byte-equivalent to today.** A plugin
   that fails both detection paths skips `audit-pronto` entirely,
   runs over the 8 existing categories at their original weights,
   and produces the same per-category scores AND the same overall
   score it does today. Verified by `/hone <some-non-sibling>` with
   the rubric file pinned at the pre-Q2 commit producing identical
   output to `/hone <same-plugin>` post-Q2. (No tool plugin in-tree
   is mid-migration; pick towncrier today, pre-2c, as the test
   case.)

B. **`audit-pronto` is read-only.** No `Edit` / `Write` / `Bash` in
   the agent's `tools:` list. Verified by frontmatter inspection.

C. **Effective weights sum to 100% in both branches.** When sibling,
   `sum(share_i / 110) = 1.0` over 9 categories. When non-sibling,
   `sum(share_i / 100) = 1.0` over 8 categories. Verified by `awk`
   on the categories table.

## Out of scope

- **Auto-fixing pronto compliance findings beyond simple field
  additions.** Most fixes are scaffolding-shaped (smith's territory).
  Hone surfaces; smith fixes. A future "/smith --upgrade <plugin>"
  pattern is the right home for the larger scaffolding work — not
  Q2's scope.
- **Migrating existing siblings to the new shape.** That's the
  M-series in `phase-2-pronto.md`. Q2 measures compliance — it's the
  diagnostic for the migration, not the migration itself.
- **`pronto:health` constellation walker.** ADR-005 §2 reserves
  `:doctor`; a meta-walker is future scope.
- **Auto-detection of off-canonical dimensions across multiple
  siblings.** Hone audits one plugin at a time.
- **Calibration of exact deduction values** beyond starting points.
  Implementation tunes against shipped siblings; the ticket fixes
  starting values, not final ones.

## References

- `project/adrs/004-sibling-composition-contract.md` — `compatible_pronto`,
  audits[], wire contract gates
- `project/adrs/005-sibling-skill-conventions.md` — `:audit`,
  `:doctor`, `:fix`, observations vs scores, discovery order
- `plugins/pronto/references/sibling-audit-contract.md` — wire
  contract specifics
- `plugins/pronto/references/recommendations.json` — canonical
  dimension list
- `plugins/pronto/references/rubric.md` — weight hints
- `.claude/agents/audit-design.md` — shape precedent for `audit-pronto`
- `.claude/skills/hone/SKILL.md` — current hone body
- `.claude/skills/hone/references/scoring-rubric.md` — rubric file Q2
  extends
- `project/tickets/open/quickstop-dev-tooling-q1-smith-enhancements.md`
  — research-agent change Q2 inherits
- `project/plans/active/phase-2-pronto.md` — M-series migrations Q2
  diagnoses
