---
id: q2
plan: quickstop-dev-tooling
status: closed
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

1. A new audit subagent — `audit-pronto`. Sibling-conditional.
2. A new audit subagent — `audit-boundary`. Plugin-wide, dispatched
   unconditionally; audits ADR-006 §1/§2/§3 conformance.
3. A new rubric category — Pronto Compliance, weight 10%,
   scope-aware (sibling-only).
4. ADR-006 deductions folded into existing Hook Quality and Security
   categories (every plugin, no new category).
5. A **share-based renormalization** that adds Pronto Compliance to
   the rubric without reducing any single existing category's stake.
   When a plugin is a sibling, the 9 categories share weight; when
   it's not, the existing 8 categories run unchanged.
6. **Sibling detection via two paths:** plugin.json `pronto` block
   (contract-native siblings, post-migration) AND
   `plugins/pronto/references/recommendations.json` registry
   (legacy/transitional siblings like claudit and commventional
   today). Either match dispatches `audit-pronto`.
7. The same in-tree authority research extension Q1 makes (shared
   agent — when Q1 lands first, this is a no-op for Q2). Now also
   reads ADR-006.

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

### New audit subagent: `.claude/agents/audit-boundary.md`

ADR-006 plugin responsibility boundary applies to every plugin —
sibling or tool, hook-shipping or not. Hone gets a dedicated
boundary-audit subagent that runs unconditionally on every
`/hone <plugin>` invocation. Mirrors `audit-design.md`'s shape.
Read-only.

```yaml
---
name: audit-boundary
description: "Audits ADR-006 plugin responsibility boundary — §1 surface enumeration, §2 silent mutation of consumer artefacts, §3 hook invariants (no payload mutation, no persistent host state, no undeclared writes). Dispatched by /hone Phase 2 against every plugin, sibling or not."
tools:
  - Read
  - Glob
  - Grep
model: inherit
---
```

Body audits four surfaces:

**1. Plugin surface declaration (§1)**

- README contains a "Plugin surface" section enumerating skills,
  commands, agents, hooks, opinions?
- If hooks are declared in `hooks/hooks.json` but absent from the
  README's surface enumeration, flag (§1 surface visibility).
- Hook role declaration present in README ("pure observability"
  per §3, or other)?

**2. Consumer-artefact mutation (§2)**

ADR-006 §2 prohibits *silent* mutation of consumer artefacts. The
test is whether the plugin code runs without explicit user
invocation — hook scripts run automatically; skills run only when
the user dispatches them. Q2 distinguishes:

- **Scope A — automatic execution paths.** Scripts under `hooks/`
  (any `.sh` / `.py` / executable in that directory tree), **plus
  any script invoked from a Scope A path.** Scope is transitive
  along the call graph: if `hooks/emit.sh` runs `bin/dispatch.sh`,
  then `bin/dispatch.sh` is Scope A even though it lives outside
  `hooks/`, because it executes within the hook's
  automatic-dispatch lifetime. Mutations in any Scope A script are
  *silent* by definition — Critical deductions apply.
- **Scope B — user-invoked capabilities.** Skill bodies under
  `skills/<name>/SKILL.md` and any helper scripts they invoke
  that aren't reachable from a Scope A path. Mutations here are
  opt-in (the user explicitly invoked the skill), so they are NOT
  §2 violations per the "silent" qualifier. Audit-boundary still
  surfaces them as informational findings ("opt-in capability —
  verify the skill's prose tells the user what it will mutate
  before doing so") but applies no automatic deduction.

**Call-graph resolution.** Audit-boundary builds the Scope A
call-graph by `Grep`-ing every script under `hooks/` for invocations
of files inside the plugin (`bin/`, `scripts/`, `lib/`, etc.) —
literal filename or `${CLAUDE_PLUGIN_ROOT}/<path>` references
suffice; full shell expansion is not required. Each transitively
reachable script is added to Scope A. The walk is one pass deep —
deeper transitive chains are listed in the output as "Scope A
(transitive)" with the discovery path so a human can verify. This
is bounded: in-tree plugins have at most a handful of helper
scripts, and the agent only needs to classify, not execute.

Search via `Grep` for invocations matching:

- `gh pr edit --body-file` / `gh pr edit -F` / `gh pr edit -B`
  (PR-body mutation)
- `git config --global` (consumer config mutation)
- `gh repo edit` (consumer repo settings mutation)
- `gh release create` / `gh release edit` (release mutation)

Each match in **Scope A** flags as a Critical §2 violation. Each
match in **Scope B** flags as an informational note (no
deduction). Output includes file path + line number + matched
command + scope label.

**Fenced-code-block guard.** Within any scanned file, matches that
appear inside a triple-backtick fenced code block are treated as
*documented examples*, not invocations. The agent reads each
matching file in full (cheap — these files are short) and tracks
fence state line-by-line. Fenced matches are listed under
"documented examples" in the output and never deducted, even in
Scope A. This guard primarily matters for skill bodies that
demonstrate the command in prose (e.g. commventional's planned
`:install-trailer-stripper` skill shows the user what hook it will
install).

**3. Hook §3 invariants** (skip if no `hooks/` directory)

Static analysis of every script in `hooks/`.

- §3 invariant 1 (payload mutation, Critical): search for any
  literal occurrence of `updatedInput`, `updatedOutput`,
  `"decision":`, `"behavior":`, `"permissionDecision":` in script
  bodies. Each match flags as Critical.
- §3 invariant 2 (persistent host state, High): search for
  installation patterns — `npm install`, `brew install`,
  `pip install`, `cargo install`, `go install`, `chmod +x` against
  consumer paths, `sudo`, `systemctl enable`, `launchctl load`.
  Each match flags as High.
- §3 invariant 3 (undeclared writes): two tiers, depending on what
  static analysis can decide.
  - **Tier 1 (statically decidable, automatic deduction):** an
    enumerated list of literal write paths whose presence is
    unambiguous — no variable substitution, no command
    interpolation. Match exactly:
    - `> /etc/<anything>` / `>> /etc/<anything>` /
      `tee /etc/<anything>`
    - `> /usr/local/<anything>` / `>> /usr/local/<anything>` /
      `tee /usr/local/<anything>`
    - `> ~/.bashrc` / `>> ~/.bashrc` / `tee ~/.bashrc`
    - `> ~/.zshrc` / `>> ~/.zshrc` / `tee ~/.zshrc`
    - `> ~/.gitconfig` / `>> ~/.gitconfig` / `tee ~/.gitconfig`
    - `> ~/.profile` / `>> ~/.profile` / `tee ~/.profile`

    Each match flags High, deduct -15. The list is exhaustive on
    purpose — anything not listed falls to Tier 2.
  - **Tier 2 (variable-target writes, no automatic deduction):**
    `>`, `>>`, `tee`, `cp`, `mv`, `mkdir` whose target is a shell
    variable, command substitution, or any literal path not in the
    Tier 1 list. Static analysis cannot resolve
    `${TOWNCRIER_TRANSPORT}` without running the script, and a
    literal path outside `~/.<plugin>/` may still be perfectly
    legitimate (consumer-supplied output, scratch under
    `${CLAUDE_PLUGIN_ROOT}`, etc.). The agent flags the call site
    as "human-review required" and lists it in the output without
    applying a deduction. The rationale: most hook-script writes
    use consumer-configured transports (towncrier's pattern) and
    are fully ADR-006 §3 invariant 3 conformant; auto-deducting on
    every variable-target write would penalize the canonical
    pattern. Tightening Tier 1 to an enumerated list keeps the
    agent honest — automatic deductions only fire on bytes the
    agent can prove are violations.

**4. Manifest/script drift**

- If `hooks/hooks.json` declares hooks for events the plugin
  doesn't have a script for, flag (manifest/script drift). The
  README/manifest cross-reference for §1 surface visibility lives
  in surface 1 above; this surface is just script presence.

**Output format:**

```markdown
## ADR-006 Boundary Audit

### Plugin Surface (§1)
- README plugin-surface section: present / missing
- Hook role declaration: present / missing / N/A (no hooks)
- Hooks declared but not enumerated: <list>

### Consumer-Artefact Mutation (§2)
- Violations: <count>
  - <file:line> — <matched command>
  - ...

### Hook §3 Invariants (skipped if no hooks/)
- §3.1 (payload mutation, Critical): <count>
  - <file:line> — <field>
- §3.2 (persistent host state, High): <count>
  - <file:line> — <pattern>
- §3.3 (undeclared writes, High): <count>
  - <file:line> — <path>

### Manifest/Script Drift
- hooks.json declares events with no script: <list>

### Estimated Impact
- Hook Quality deductions: <total>
- Security deductions: <total>
- Documentation deductions: <total>
```

ADR-006 deductions are folded into existing categories rather than
introducing a 10th category — the boundary is plugin-wide and
already overlaps Hook Quality (§3 issues), Security (§2 issues), and
Documentation (§1 issues). A separate "ADR-006 Compliance" category
would create double-counting.

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

### Rubric: ADR-006 boundary deductions (folded into existing categories)

ADR-006 conformance applies to every plugin. Findings from
`audit-boundary` flow into existing categories rather than a new
one. Add to `.claude/skills/hone/references/scoring-rubric.md` as
sub-tables under Hook Quality, Security, and Documentation:

#### Hook Quality — ADR-006 §3 deductions

| Issue | Points | Severity | Description |
|---|---|---|---|
| Hook returns any of the five `hookSpecificOutput` fields (`updatedInput`, `updatedOutput`, `decision`, `behavior`, `permissionDecision`) | -25 each (max -50) | Critical | ADR-006 §3 invariant 1 — payload/flow mutation |
| Hook installs persistent host state (npm/brew/pip install, systemctl, launchctl, sudo) | -15 each (max -30) | High | ADR-006 §3 invariant 2 |
| Hook writes outside consumer-configured channels | -15 each (max -30) | High | ADR-006 §3 invariant 3 |
| `hooks/hooks.json` declares an event with no script | -5 each | Low | Manifest drift |

These deductions stack with existing Hook Quality deductions. The
existing rubric algorithm floors each category score at 0 (no
separate per-category cap exists today); the same floor applies to
the post-stack sum.

#### Security — ADR-006 §2 deductions

| Issue | Points | Severity | Description |
|---|---|---|---|
| Plugin code calls `gh pr edit --body-file/-F/-B` | -25 each | Critical | ADR-006 §2 — silent mutation of consumer artefact |
| Plugin code calls `git config --global` | -25 each | Critical | ADR-006 §2 — consumer config mutation |
| Plugin code calls `gh repo edit` or `gh release create/edit` | -25 each | Critical | ADR-006 §2 — consumer repo/release mutation |

False-positive guard: matches inside README example code blocks
(fenced) are noted but not deducted. The audit-boundary agent's
Output format separates "violations" from "documented examples".

#### Documentation — ADR-006 §1 deductions

| Issue | Points | Severity | Description |
|---|---|---|---|
| README missing "Plugin surface" section | -5 | Low | ADR-006 §1 |
| Hooks declared in `hooks/hooks.json` but absent from README's surface enumeration | -5 each (max -15) | Low | ADR-006 §1 visibility |

**Calibration target.** A conformant plugin scores zero ADR-006
§2 / §3 deductions. Pre-Q1-scaffolded plugins (claudit, skillet,
avanti, towncrier) take a -5 §1 Documentation deduction for the
missing "Plugin surface" README section until each is migrated
under a small follow-up — the §1 README shape is a Q1 scaffold
addition that the existing in-tree plugins don't yet emit. §2 and
§3 invariant detections are zero on those plugins.

Commventional today (per
`project/tickets/open/phase-2-commventional-adr-006-conformance.md`)
scores Critical findings of -25 each on `enforce-ownership.sh` (§3
invariant 1) and `pr-ownership-check.sh` (§2). The exact total
depends on how many `updatedInput` returns and `gh pr edit` calls
the static analysis surfaces; the bar is that hone *flags both
violations clearly*, not that the score lands at a specific number.

**Note on grep against jq-constructed JSON.** Commventional's
`enforce-ownership.sh` builds its return payload via `jq -n`, with
the literal string `"updatedInput":` appearing inside the jq
template. Grep operates on file bytes — it finds the literal
regardless of whether the field is later emitted via `printf`,
`echo`, or `jq`. The agent's static analysis works on whatever
script construction style commventional or any future plugin uses.

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

Add `audit-boundary` unconditionally and `audit-pronto`
**conditionally** on sibling detection. Mechanics:

1. Before dispatching agents, run sibling detection:
   a. Read `plugins/<name>/.claude-plugin/plugin.json`; check for a
      `pronto` key.
   b. Read `plugins/pronto/references/recommendations.json`; check
      whether `<name>` appears as a `recommended_plugin` for any
      dimension.
2. **Always** dispatch `audit-boundary` alongside the existing 4
   agents. Boundary audit applies to every plugin per ADR-006.
3. If either sibling-detection path matches: also dispatch
   `audit-pronto` (6 agents total). The dispatch prompt for
   `audit-pronto` includes which detection path matched (so the
   agent can flag "registry-only — should migrate to contract-native
   shape").
4. If neither sibling-detection path matches: dispatch 5 agents
   (existing 4 + `audit-boundary`); `audit-pronto` is skipped;
   Pronto Compliance is excluded from scoring; the rubric runs over
   the 8 existing categories at their original weights
   (byte-equivalent to today on score, but with new ADR-006-shaped
   deductions inside Hook Quality / Security / Documentation when
   findings warrant).

**Note on byte-equivalence.** A non-sibling, ADR-006-conformant
plugin (e.g. claudit, skillet, avanti today, modulo the -5 §1
README-surface deduction noted in the calibration target above)
produces an overall score essentially byte-equivalent to today's
`/hone <plugin>` — the rubric weights are unchanged and
`audit-boundary` finds zero §2 / §3 violations to deduct. A
non-sibling plugin **with** ADR-006 violations (e.g. commventional,
until M3 ships) sees its score drop relative to today, reflecting
the newly-detected non-conformance. This is intended.

**Note on token cost.** The score-side byte-equivalence does not
extend to token usage — `audit-boundary` adds one subagent's
dispatch on every `/hone` invocation, sibling or not. That is the
deliberate cost of moving the boundary check from "Anthony reads
the diff" to "hone surfaces it automatically." The cost stays
bounded because `audit-boundary` is read-only and short-running
(static greps over a single plugin tree).

### Hone Phase 1 — research targets extended

Same change as Q1: `research-plugin-spec` reads in-tree ADRs
(ADR-004, ADR-005, **ADR-006**) + sibling-audit-contract +
license-selection. Already a shared agent — landing in Q1 makes it
available to Q2 with no extra work in this ticket. If Q2 lands
first (unlikely given dependency), Q2 carries the research-agent
change.

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

1. **Create `.claude/agents/audit-boundary.md`** mirroring
   `audit-design.md`'s shape — read-only, ADR-006 §1/§2/§3 audit.
2. **Create `.claude/agents/audit-pronto.md`** mirroring
   `audit-design.md`'s shape — read-only, sibling-shape audit.
3. **Add the ADR-006 deduction sub-tables** to
   `.claude/skills/hone/references/scoring-rubric.md` under existing
   Hook Quality, Security, and Documentation categories.
4. **Add the Pronto Compliance category** to the same rubric file
   (sibling-conditional, share-based renormalization).
5. **Add scope-aware weight handling** to the rubric file's
   "Scoring Algorithm" section.
6. **Update `.claude/skills/hone/SKILL.md` Phase 2** — sibling
   detection up front; dispatch 5 agents always (existing 4 +
   `audit-boundary`), 6 agents when sibling detected (+
   `audit-pronto`).
7. **Update `.claude/skills/hone/SKILL.md` Phase 3** — Categories
   table reflects rebalance; "Compute Overall Score" reflects
   scope-aware weights.
8. **Update Phase 4** — boundary and pronto findings flow through
   existing recommendation ranking; note the smith-overlap caveat
   for scaffolding-shaped fixes.
9. **Update `research-plugin-spec`** — same change as Q1, already
   landed if Q1 ships first; otherwise carry it here (ADR-004,
   ADR-005, ADR-006, sibling-audit-contract, license rule).

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
  `audit-pronto` — Pronto Compliance is excluded from the
  scorecard. `audit-boundary` runs and produces the calibration
  target's expected pattern: zero §2 / §3 violations (towncrier's
  `bin/emit.sh` is the canonical §3-conformant precedent), and a
  -5 §1 Documentation deduction for the missing "Plugin surface"
  README section. Score is essentially byte-equivalent to today's
  `/hone towncrier` modulo that single -5 nudge.
- `/hone commventional` produces explicit `audit-boundary` Critical
  findings — at minimum: §3 invariant 1 violation in
  `hooks/enforce-ownership.sh` (the jq template constructs
  `"updatedInput":` literal in the returned payload) and §2
  violation in `hooks/pr-ownership-check.sh` (calls
  `gh pr edit --body-file` from a hook script — Scope A, not
  user-invoked). Findings are line-anchored to the source files and
  match the migration scope in
  `project/tickets/open/phase-2-commventional-adr-006-conformance.md`.
  Both files live under `hooks/` and are explicitly in §2 / §3
  detection scope (Scope A — automatic execution paths).
- `/hone <conformant non-sibling>` (claudit, skillet, avanti)
  produces zero §2 / §3 violations and a -5 §1 Documentation
  finding for the missing surface section (until each is migrated).
- The visual scorecard shows 8 bars for non-sibling plugins, 9 bars
  for sibling plugins (Pronto Compliance appended at the bottom).
- `audit-pronto` produces structured output matching the agent's
  specified format (5 sections with the listed fields).
- A sibling plugin missing `compatible_pronto` (and only
  `compatible_pronto` — i.e. has a `pronto` block, has `audits[]`,
  has the `:audit` skill) produces a finding with the documented
  -20 deduction. Use skillet edited to drop `compatible_pronto` as
  the test fixture; for registry-only siblings like claudit, the
  -20 stacks with the missing-block and missing-skill deductions
  and isn't separately verifiable. (Missing `compatible_pronto` is
  a manifest-level deduction, not a body-of-skill check, so it
  stacks despite the presence-gated rule on the body-of-skill
  deductions.)
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

B. **`audit-pronto` and `audit-boundary` are read-only.** No
   `Edit` / `Write` / `Bash` in either agent's `tools:` list.
   Verified by frontmatter inspection of both
   `.claude/agents/audit-pronto.md` and
   `.claude/agents/audit-boundary.md`.

C. **Effective weights sum to 100% in both branches.** When sibling,
   `sum(share_i / 110) = 1.0` over 9 categories. When non-sibling,
   `sum(share_i / 100) = 1.0` over 8 categories. Verified by `awk`
   on the categories table.

## Out of scope

- **Auto-fixing pronto compliance or ADR-006 findings beyond simple
  field additions.** Most fixes are scaffolding-shaped (smith's
  territory) or migration-shaped (commventional's per-plugin
  ticket). Hone surfaces; smith fixes new plugins; per-plugin
  remediation tickets fix shipped ones. A future "/smith --upgrade
  <plugin>" pattern is the right home for the larger scaffolding
  work — not Q2's scope.
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
- `project/adrs/006-plugin-responsibility-boundary.md` — capability/automation
  boundary `audit-boundary` enforces
- `plugins/pronto/references/sibling-audit-contract.md` — wire
  contract specifics
- `plugins/pronto/references/recommendations.json` — canonical
  dimension list
- `plugins/pronto/references/rubric.md` — weight hints
- `.claude/agents/audit-design.md` — shape precedent for both
  `audit-pronto` and `audit-boundary`
- `.claude/skills/hone/SKILL.md` — current hone body
- `.claude/skills/hone/references/scoring-rubric.md` — rubric file Q2
  extends
- `plugins/towncrier/bin/emit.sh` — canonical §3-conformant
  pure-observability hook (the calibration target for "zero
  audit-boundary violations" on a hook-shipping plugin)
- `project/tickets/open/quickstop-dev-tooling-q1-smith-enhancements.md`
  — research-agent change Q2 inherits
- `project/tickets/open/phase-2-commventional-adr-006-conformance.md`
  — concrete ADR-006 violations `audit-boundary` should detect on
  commventional today
- `project/plans/active/phase-2-pronto.md` — M-series migrations Q2
  diagnoses
