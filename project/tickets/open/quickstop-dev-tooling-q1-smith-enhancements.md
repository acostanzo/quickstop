---
id: q1
plan: quickstop-dev-tooling
status: open
updated: 2026-04-29
---

# Q1 — Smith enhancements

## Scope

Smith scaffolds new quickstop plugins. Three gaps relative to current
quickstop conventions:

1. **License is silently defaulted.** No `license` field in the
   scaffolded `plugin.json`, no `LICENSE` file, no question to the
   user. This contradicts `.claude/rules/license-selection.md`'s
   "never default-pick — surface the decision."
2. **Pronto-sibling shape isn't a first-class scaffold path.** When a
   user wants to build an audit sibling, smith produces a generic
   plugin and expects the author to bolt on the `pronto` block, the
   `:audit` skill, and the transitional parser agent by hand. ADR-005
   §1 / §3 / §5 specify that shape — smith should produce it directly.
3. **Research subagents don't read in-tree authority.** `research-plugin-spec`
   fetches Anthropic's plugin docs but never reads our own ADRs, the
   wire-contract reference, or the license rule. Smith ships expert on
   Claude Code and ignorant of quickstop's own conventions.

Q1 closes those three gaps. Smith remains a quickstop-internal dev
tool — not a marketplace plugin — used when building or updating
plugins in this repo.

## Architecture

### Phase 2 — questionnaire additions

Smith's Phase 2 (`Gather Requirements`) gains three additions. Existing
questions keep their cognitive ordering; new questions slot in at the
points where their answers gate later prompts.

**New: Question — Plugin role**
Slots **after Description, before Components.** AskUserQuestion with
options:

- **Tool plugin** — a stand-alone command/skill set (most plugins:
  claudit, towncrier, smith itself).
- **Pronto sibling** — audits a `pronto` rubric dimension. Branches
  into the dimension question.

**New: Question — Sibling dimension** (conditional on role = sibling)

AskUserQuestion. Options derived at runtime by reading
`plugins/pronto/references/recommendations.json` and presenting each
`recommended_plugin` slot's dimension as an option, plus an "other
(non-canonical)" escape hatch. Off-canonical dimensions get a warning
that pronto won't recognize them.

**New: Question — License**

Slots **immediately after the Plugin Role question** — license posture
follows from "is this for the marketplace or not." Asking it early
also matches `.claude/rules/license-selection.md`'s instruction to
"surface the decision before scaffolding" (rather than at the very
end of requirements gathering, where it risks reading as an
afterthought).

AskUserQuestion with options derived from the rule:

- **MIT** — marketplace plugins (per the rule's defaults table)
- **Apache-2.0** — projects with patent concerns or core developer
  tooling
- **No LICENSE** — internal/private; appropriate when the plugin
  isn't going to ship to the marketplace
- **Other** — paste path/text (rare; covers BSD, AGPL, etc.)

**Pre-highlighted option (still requires user confirmation):** MIT
when scaffolding under `plugins/` (the marketplace path) and role =
tool or sibling; No LICENSE when role indicates internal use. The
rule's "never default-pick" directive is satisfied because the user
must affirm the answer — pre-highlighting is a UX hint, not a silent
default. The decision tree from the rule file is shown inline so the
user can override without reading the rule separately.

### Phase 3 — scaffolding additions

#### 3.1 plugin.json — sibling block

When role = sibling, the scaffolded `plugin.json` includes:

```json
{
  "name": "<name>",
  "version": "0.1.0",
  "description": "<user description>",
  "author": { "name": "Anthony Costanzo", "url": "https://github.com/acostanzo" },
  "license": "<license-spdx>",
  "keywords": [...],
  "pronto": {
    "compatible_pronto": ">=<current-pronto-version>",
    "audits": [
      {
        "dimension": "<chosen-dimension>",
        "command": "/<name>:audit --json",
        "weight_hint": <from rubric.md>
      }
    ]
  }
}
```

Mechanics:

- `compatible_pronto` floor: smith reads `plugins/pronto/.claude-plugin/plugin.json`
  at scaffold time and uses `>=<that-version>`. The author can tighten
  the range later.
- `weight_hint`: smith reads `plugins/pronto/references/rubric.md` for
  the chosen dimension and reproduces the weight as a decimal
  (`0.15` for a 15% weight). Falls back to omitting the field if
  parsing fails.
- `license` SPDX identifier: `MIT`, `Apache-2.0`, etc., matching
  Question 8's selection. Omitted entirely when role/license = "no
  LICENSE".

When role = tool, no `pronto` block. Same `license` handling.

#### 3.2a — auto-create skills/audit/SKILL.md when sibling

In addition to skills the user listed, smith creates
`plugins/<name>/skills/audit/SKILL.md` with this frontmatter:

```yaml
---
name: audit
description: Audit a target codebase for <dimension> depth
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---
```

Body emits the empty-envelope wire-contract shape (matching the 2a1
inkwell pattern):

```json
{
  "$schema_version": 2,
  "plugin": "<name>",
  "dimension": "<chosen-dimension>",
  "categories": [],
  "observations": [],
  "composite_score": null,
  "recommendations": []
}
```

A TODO marker explains: "Fill in `observations[]` entries when scorers
are wired up. Until then, the empty array exercises the translator's
case-3 passthrough — the dimension scores by presence-only fallback."

If the user listed `audit` as a skill in Question Skills, smith uses
the wire-contract template instead of the generic TODO scaffold (the
sibling shape supersedes the generic skill stub for that name).

#### 3.3a — auto-create transitional parser agent when sibling

Smith scaffolds `plugins/<name>/agents/parse-<name>.md` mirroring
`parse-inkwell.md`'s shape. The agent's body forwards the wire envelope
unchanged. The frontmatter and a header comment mark it deprecated from
day one with the note: "Transitional. Satisfies ADR-005 §5 step-2
discovery while the audit ramps up; remove after step-1 discovery
verifies in production."

#### 3.6 — README sibling-aware sections

When sibling, the scaffolded README includes:

- "What dimension does this sibling audit"
- "How to invoke `/<name>:audit --json` standalone"
- A short note on the `compatible_pronto` handshake

When `license != none`, README ends with `<License>. See
[LICENSE](LICENSE).` per the rule file's mechanics section.

#### LICENSE / NOTICE files

Per `.claude/rules/license-selection.md` mechanics:

- **MIT:** scaffold `LICENSE` with standard MIT text and `Copyright (c)
  <current-year> Anthony Costanzo` (matches in-tree convention across
  shipped plugins). No `NOTICE`.
- **Apache-2.0:** scaffold both `LICENSE` (canonical Apache 2.0 text)
  and `NOTICE` (project name + copyright + standard boilerplate).
- **No LICENSE:** skip both.

### Phase 1 — research targets extended

Modify `.claude/agents/research-plugin-spec.md` to add a "Step 2.5: Read
in-tree quickstop authority" before the Anthropic doc fetches. Reads:

- `project/adrs/004-sibling-composition-contract.md` (when present)
- `project/adrs/005-sibling-skill-conventions.md` (when present)
- `plugins/pronto/references/sibling-audit-contract.md` (when present)
- `.claude/rules/license-selection.md` (when present)

Each file is read with `Read` and surfaced into the agent's output
under a "Quickstop Conventions" section, distinct from the
Anthropic-docs section. Budget bump: +4 local file reads (inexpensive,
cached after first run via `memory: user`).

The change lives in the shared research agent, so hone benefits from
it without duplication.

## Implementation order

(Build order — not the order the questions appear to the user. The
user-facing order is: Description → Plugin Role → License → Sibling
Dimension (if sibling) → Components → Skills → Agents → ... per the
architecture section.)

1. **Add the Plugin Role question** to Phase 2 (after Description,
   before Components). Wire role into a phase-2 `IS_SIBLING` flag.
2. **Add the Sibling Dimension question** (conditional on role =
   sibling). Read `recommendations.json` for options.
3. **Add the License question** to Phase 2 (after Plugin Role, before
   Components). Wire its answer into Phase 3.
4. **Add LICENSE / NOTICE file generation** in Phase 3 per the
   license-rule mechanics.
5. **Extend Phase 3.1** to scaffold the `pronto` block and the
   `license` field when applicable.
6. **Add Phase 3.2a** — auto-create `skills/audit/SKILL.md` with the
   wire-contract emission shape when sibling.
7. **Add Phase 3.3a** — auto-create the transitional parser agent
   when sibling.
8. **Update Phase 3.6** — sibling-aware README sections.
9. **Update `research-plugin-spec`** to read in-tree authority.
10. **Add a smith dogfood note** to Phase 5 summary: "If you scaffolded
    a sibling, run `/hone <name>` to verify Pronto Compliance ≥85."

## Acceptance

- `/smith` end-to-end with role = sibling produces a plugin directory
  whose `plugin.json` contains a `pronto.compatible_pronto` field set
  to `>=<current-pronto-version>` and a `pronto.audits[]` entry
  pointing at `/<name>:audit --json`.
- The scaffolded `skills/audit/SKILL.md` exists and emits a JSON
  object satisfying the wire contract: `$schema_version: 2`, correct
  `plugin`, correct `dimension`, empty `observations[]`,
  `composite_score: null`.
- `jq -e '."$schema_version" == 2 and .plugin == "<name>" and .observations == []' <output>` passes against the scaffolded skill's
  output.
- `/smith` end-to-end with role = tool produces a plugin without a
  `pronto` block, no `:audit` auto-creation, no parser agent.
- License selection produces the right artifact: MIT → standard MIT
  `LICENSE` with current year, Apache-2.0 → `LICENSE`+`NOTICE`, none
  → no LICENSE file. `plugin.json`'s `license` field is set
  consistently (or omitted when "no LICENSE").
- `research-plugin-spec` reads ADR-004 and ADR-005 when they exist
  (verified by inspecting the agent's output for a "Quickstop
  Conventions" section).
- A smith-scaffolded sibling plugin passes `/hone <name>` at
  ≥80/100 overall. (Drops to a Q2 dependency: the Pronto Compliance
  score must be ≥85 — that part of the acceptance is verified after
  Q2 ships.)

## Three load-bearing invariants

A. **Sibling scaffolding produces a wire-contract-valid empty
   envelope.** Verified by piping the scaffolded skill's stdout
   through `plugins/pronto/agents/parsers/scorers/observations-to-score.sh`
   (case-3 passthrough). No translator errors, dimension scores via
   the presence fallback.

   *Dependency note:* the case-3 passthrough path lands with PR H4
   (observations-aware scorer) and is exercised first by 2a1's
   inkwell scaffold. Until both ship, Q1's invariant A is verifiable
   by `jq` schema inspection only — `jq -e '."$schema_version" == 2
   and .observations == []'` against the scaffolded skill's stdout.
   The full case-3 verification becomes available once H4 + 2a1 land,
   and Q1's acceptance gains that bar at that point.

B. **License choice is explicit, not silent.** No code path in smith
   writes a `LICENSE` file or a `license` field in `plugin.json`
   without the user having answered the License question.

C. **Tool-plugin path stays simple.** When role = tool, no `pronto`
   block, no auto-created `:audit` skill, no parser agent — smith's
   tool-plugin scaffolding is unchanged from today, just with the
   License question added.

## Out of scope

- **`:doctor` skill scaffolding.** ADR-005 §2 reserves the name; no
  pattern to scaffold yet.
- **`:fix` skill scaffolding.** ADR-005 §4 reserves the name; no
  contract.
- **Audit-pronto subagent.** That's hone work — Q2.
- **Migrating shipped plugins to use the new scaffolds.** Per-plugin
  work, not smith work.
- **Multi-dimension siblings.** `pronto.audits[]` is plural in the
  spec but no in-tree sibling claims more than one dimension. Q1
  scaffolds a single entry; multi can come when there's a real use
  case.
- **Shared research infrastructure** between smith and hone. Plan-level
  scope decision; both consume `research-plugin-spec` independently.

## References

- `.claude/rules/license-selection.md` — license decision tree, defaults
- `.claude/skills/smith/SKILL.md` — current smith body
- `.claude/skills/smith/references/plugin-spec.md` — local baseline
- `.claude/agents/research-plugin-spec.md` — research agent extended here
- `project/adrs/004-sibling-composition-contract.md` — handshake smith scaffolds
- `project/adrs/005-sibling-skill-conventions.md` — `:audit` slot smith scaffolds
- `plugins/pronto/references/sibling-audit-contract.md` — wire contract
- `plugins/pronto/references/recommendations.json` — canonical dimensions
- `plugins/pronto/references/rubric.md` — weight hints per dimension
- `project/tickets/open/phase-2-2a1-inkwell-scaffold.md` — the sibling
  scaffold pattern smith dogfoods
- `plugins/inkwell/agents/parse-inkwell.md` (post-2a1) — parser agent
  pattern smith reproduces
