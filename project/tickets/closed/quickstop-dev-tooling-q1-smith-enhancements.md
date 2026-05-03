---
id: q1
plan: quickstop-dev-tooling
status: closed
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
4. **ADR-006 boundary awareness is missing.** Smith doesn't know that
   plugins ship capabilities (skills, commands, agents, opinions) and
   not automation; doesn't surface §3's pure-observability hook
   carve-out when the user mentions hooks; doesn't scaffold a "Plugin
   surface" README section per §1. The new boundary needs to be
   present from scaffold time so authors don't import non-conformance
   patterns by default.

Q1 closes those four gaps. Smith remains a quickstop-internal dev
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

#### 3.0 — Hook surface (ADR-006 boundary)

Smith does **not** scaffold a `hooks/` directory by default. ADR-006
§1 defines plugin surface as skills, commands, agents, hooks, and
opinions; §3 carves out a narrow allowance for pure-observability
hooks (no payload mutation via `hookSpecificOutput.updatedInput` /
`updatedOutput` / `decision` / `behavior` / `permissionDecision`; no
persistent host state established at hook time; no undeclared
writes); §6 defers consumer-side automation organization to a future
composer pattern. Most plugins don't ship hooks — claudit, skillet,
avanti, smith itself, hone itself.

The questionnaire does not currently ask about hooks. If a future
enhancement adds a "scaffold pure-observability hooks" branch, it
must:

- Surface ADR-006 §3 invariants in the question prose verbatim.
- Scaffold script skeletons that READ stdin, BUILD a JSON envelope,
  DISPATCH to a consumer-configured transport, and EXIT 0 with no
  stdout — never emit any of the five mutating
  `hookSpecificOutput` fields.
- Include a comment-block header on each generated hook script
  reproducing the §3 invariants (the towncrier `bin/emit.sh` header
  is the in-tree precedent: *"Always exits 0 and writes nothing to
  stdout, so Claude's hook flow is never altered by this script."*).
- Refuse to scaffold any hook whose described behaviour returns
  any of ADR-006 §3 invariant 1's five fields
  (`updatedInput`, `updatedOutput`, `decision`, `behavior`,
  `permissionDecision`). Verbs the user might use that map to
  these fields: intercepting, rewriting, mutating, blocking,
  permitting, deciding, denying. The list isn't exhaustive — the
  test is "does the described behaviour produce one of the five
  fields", not "does the description match a verb on a list."

For Q1, the explicit non-scaffolding of hooks is the load-bearing
behaviour. Authors who need a §3-conformant hook surface follow
towncrier's pattern by hand. Authors who want consumer-side
automation (cross-plugin triggers, post-merge commit cleanup, etc.)
compose it outside the plugin per §6.

**User-facing migration note.** If the user mentions hooks at any
point during the questionnaire — in the Description free-text, in
the Components answer (e.g. typing "hooks" into a sub-options
prompt), in any later free-text — smith surfaces a one-line note
**inline** with the next prompt (not as a separate AskUserQuestion):

> *Note: smith doesn't scaffold hooks. See ADR-006 §3 / towncrier
> `bin/emit.sh` for the by-hand pattern.*

The note is informational. It does not gate the questionnaire — the
user proceeds with the rest of scaffold. The hook-by-hand workflow
is a one-time author task that lives outside smith's scope until
the future enhancement under §3.0 lands.

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

When **any** plugin (sibling or tool), the scaffolded README opens
with a **"Plugin surface"** section enumerating what the plugin
ships per ADR-006 §1:

```markdown
## Plugin surface

This plugin ships:
- Skills: <list — pre-populated from Question Skills>
- Commands: <list, or "none">
- Agents: <list, or "none">
- Hooks: <list with role per ADR-006 §3, or "none">
- Opinions: <rules / reference docs, or "none">

This plugin does not ship: cross-plugin automation, consumer config
edits, or any flow that silently mutates artefacts the consumer
owns. Consumers compose automation against this plugin's
capabilities per ADR-006 §6.
```

When sibling, the scaffolded README also includes:

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
- `project/adrs/006-plugin-responsibility-boundary.md` (when present)
- `plugins/pronto/references/sibling-audit-contract.md` (when present)
- `.claude/rules/license-selection.md` (when present)

Each file is read with `Read` and surfaced into the agent's output
under a "Quickstop Conventions" section, distinct from the
Anthropic-docs section. Budget bump: +5 local file reads (inexpensive,
cached after first run via `memory: user`).

The change lives in the shared research agent, so hone benefits from
it without duplication.

## Implementation order

(Build order — not the order the questions appear to the user. The
user-facing order is: Description → Plugin Role → License → Sibling
Dimension (if sibling) → Components → Skills → Agents → ... per the
architecture section.)

1. **Remove smith's existing hook scaffolding paths.** Smith's
   Phase 2 Components question (Question 2) lists "Hooks" as an
   option, Question 6 (Hook Events) is conditional on it, and
   Phase 3.4 scaffolds `hooks/hooks.json`. Q1 invariant D forbids
   smith from emitting a `hooks/` directory, so all three must be
   removed:
   - Delete the "Hooks" option from Question 2 Components.
   - Delete Question 6 (Hook Events) entirely.
   - Delete Phase 3.4 (Hooks scaffolding) entirely.
   - Replace those code paths with a Phase 3.0 narrative paragraph
     pointing at ADR-006 §3 + the towncrier precedent for authors
     who need hooks (the Phase 3.0 architecture text from this
     ticket).
   - **Wire in the user-mention surfacing** described in §3.0's
     "User-facing migration note." Add a phase-2 helper that
     pattern-matches the literal token `hook` (case-insensitive) in
     any free-text user response and, when matched on first
     occurrence, prepends the one-line note to the next prompt's
     prose. Match-once-per-session — the note is informational,
     not nagging.
2. **Add the Plugin Role question** to Phase 2 (after Description,
   before Components). Wire role into a phase-2 `IS_SIBLING` flag.
3. **Add the Sibling Dimension question** (conditional on role =
   sibling). Read `recommendations.json` for options.
4. **Add the License question** to Phase 2 (after Plugin Role, before
   Components). Wire its answer into Phase 3.
5. **Add LICENSE / NOTICE file generation** in Phase 3 per the
   license-rule mechanics.
6. **Extend Phase 3.1** to scaffold the `pronto` block and the
   `license` field when applicable.
7. **Add Phase 3.2a** — auto-create `skills/audit/SKILL.md` with the
   wire-contract emission shape when sibling.
8. **Add Phase 3.3a** — auto-create the transitional parser agent
   when sibling.
9. **Update Phase 3.6** — "Plugin surface" README section per ADR-006
   §1 for every plugin; sibling-aware README extras when sibling.
10. **Update `research-plugin-spec`** to read in-tree authority
    (ADR-004, ADR-005, ADR-006, sibling-audit-contract, license rule).
11. **Add a smith dogfood note** to Phase 5 summary: "If you scaffolded
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
- `jq -e '."$schema_version" == 2 and .plugin == "<name>" and .observations == []' <output>` passes against the scaffolded
  skill's output. (Single-quote the jq filter at the shell so the
  `$schema_version` literal isn't expanded by the shell. This is
  the **interim** acceptance gate for invariant A — see invariant
  A's dependency note. Once H4 + 2a1 land, the full case-3
  round-trip through
  `plugins/pronto/agents/parsers/scorers/observations-to-score.sh`
  becomes available and supersedes this `jq` schema check.)
- `/smith` end-to-end with role = tool produces a plugin without a
  `pronto` block, no `:audit` auto-creation, no parser agent.
- License selection produces the right artifact: MIT → standard MIT
  `LICENSE` with current year, Apache-2.0 → `LICENSE`+`NOTICE`, none
  → no LICENSE file. `plugin.json`'s `license` field is set
  consistently (or omitted when "no LICENSE").
- `research-plugin-spec` reads ADR-004, ADR-005, and ADR-006 when
  they exist (verified by inspecting the agent's output for a
  "Quickstop Conventions" section).
- Scaffolded README contains a "Plugin surface" section per ADR-006
  §1, enumerating skills/commands/agents/hooks/opinions and an
  explicit non-mutation declaration. Verified for both role = sibling
  and role = tool.
- Smith does not create a `hooks/` directory regardless of
  questionnaire answers (ADR-006 §3 carve-out is opt-in by hand,
  not by scaffold).
- A smith-scaffolded sibling plugin passes `/hone <name>` at
  ≥80/100 overall. (Drops to a Q2 dependency: the Pronto Compliance
  score must be ≥85 — that part of the acceptance is verified after
  Q2 ships. Q2 also introduces the audit-boundary subagent which
  smith-scaffolded plugins satisfy by construction.)

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
   License question added and the ADR-006 "Plugin surface" README
   section.

D. **Smith never scaffolds hooks.** No questionnaire path produces a
   `hooks/` directory or `hooks/hooks.json` in the scaffolded plugin,
   irrespective of role or other answers. Authors who need hooks
   follow towncrier's pattern by hand per ADR-006 §3. Verified by
   `find <scaffolded-plugin> \( -name 'hooks.json' -o -path '*/hooks/*.sh' \)`
   returning empty (parens are load-bearing — without them
   `find`'s default `-print` action only binds to the last clause
   when `-o` is used, so a top-level `hooks.json` would be silently
   missed).

## Out of scope

- **`:doctor` skill scaffolding.** ADR-005 §2 reserves the name; no
  pattern to scaffold yet.
- **`:fix` skill scaffolding.** ADR-005 §4 reserves the name; no
  contract.
- **Hook scaffolding.** Even pure-observability §3-conformant hooks
  are not scaffolded by Q1. Adding a `hooks/` branch to smith's
  questionnaire is a future enhancement, gated by the prerequisites
  in §3.0 (refusal to scaffold any hook described as intercepting,
  rewriting, blocking, or mutating).
- **Audit-pronto subagent.** That's hone work — Q2.
- **Audit-boundary subagent.** Also hone work — Q2.
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
- `project/adrs/006-plugin-responsibility-boundary.md` — capability/automation boundary smith respects (no hook scaffolding, "Plugin surface" README section)
- `plugins/pronto/references/sibling-audit-contract.md` — wire contract
- `plugins/pronto/references/recommendations.json` — canonical dimensions
- `plugins/pronto/references/rubric.md` — weight hints per dimension
- `project/tickets/open/phase-2-2a1-inkwell-scaffold.md` — the sibling
  scaffold pattern smith dogfoods
- `plugins/inkwell/agents/parse-inkwell.md` (post-2a1) — parser agent
  pattern smith reproduces
