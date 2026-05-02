---
id: 2a1
plan: phase-2-pronto
status: closed
updated: 2026-05-02
---

# 2a1 — Inkwell plugin scaffold

## Scope

PR 2a ships `inkwell`, the audit sibling for the `code-documentation`
rubric dimension. ADR-005 §1 says a participating sibling exposes its
audit through `plugins/<plugin>/skills/audit/SKILL.md`; ADR-005 §3 says
that skill emits `observations[]` per the H3 wire-contract revision;
H1 (already merged) reads `pronto.compatible_pronto` from each
sibling's `plugin.json`. 2a1 is the structural ticket — it lands the
plugin directory, the metadata file, the `:audit` skill stub, and a
transitional parser agent. The scorers (2a2) and the contract
compliance + fixtures (2a3) build on top of this scaffold.

The 2a1 PR is **emission-shaped, not score-shaped**. The `:audit`
skill emits a wire-contract envelope with `observations: []`
(empty). The translator's case-3 carve-out (empty observations[]
falls through to passthrough) keeps `recommendations.json` as the
authoritative discovery record until 2a3 wires the rubric stanza
and registers the audit_command.

## Inkwell name reuse — note

`plugins/inkwell/` previously held a different plugin: a doc-writing
automation plugin (post-commit hooks, `doc-writer` agent) that was
deprecated and removed in PR #38. The name `inkwell` was reserved
*independently* in `plugins/pronto/references/recommendations.json`
for the code-documentation audit role and pre-dates the prior plugin's
removal. The two uses share only a name; there's no carryover code,
config, or expectation. The scaffold here builds the inkwell-as-audit
plugin from scratch.

## Architecture

### File tree

```
plugins/inkwell/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── LICENSE
├── skills/
│   └── audit/
│       └── SKILL.md           # emits empty observations[] envelope (2a1)
├── agents/
│   └── parse-inkwell.md       # transitional parser agent
└── tests/                     # populated by 2a3
```

The directory shape mirrors `plugins/skillet/` — already the most
ADR-005-conformant in-tree sibling. `skills/audit/SKILL.md` uses the
same frontmatter pattern (`disable-model-invocation: true`,
`allowed-tools` scoped to read-only file inspection plus `Bash` for
the deterministic scorers 2a2 introduces). The transitional
`agents/parse-inkwell.md` exists because ADR-005 §5 step 1 lights up
on `:audit` skill discovery only after the scorers + rubric stanza
land in 2a2/2a3 — until then the discovery path resolves at step 2
via `recommendations.json`'s `parser_agent` field. Once 2a3 lands and
the audit emits a populated envelope, the parser agent retires
in-place (file kept as a no-op stub for one minor version, then
removed).

### `plugin.json` shape

```json
{
  "name": "inkwell",
  "version": "0.1.0",
  "description": "Audit code-documentation depth — README quality, docs coverage, staleness, internal link health",
  "author": {
    "name": "quickstop",
    "url": "https://github.com/acostanzo/quickstop"
  },
  "license": "MIT",
  "keywords": ["documentation", "audit", "pronto"],
  "pronto": {
    "compatible_pronto": ">=0.5.0",
    "audits": [
      {
        "dimension": "code-documentation",
        "command": "/inkwell:audit --json",
        "weight_hint": 0.15
      }
    ]
  }
}
```

`weight_hint: 0.15` matches the `code-documentation` rubric weight in
`plugins/pronto/references/rubric.md` (line 14). `compatible_pronto`'s
floor is whatever pronto version 2a3 ships — pinned at PR-merge time
when the version is known. H1's three-branch behaviour (in-range →
dispatch; out-of-range → version-mismatch finding; unset → soft
finding) is exercised by inkwell on every audit run from 2a3 onward.

### `skills/audit/SKILL.md` (2a1 stub shape)

The 2a1 SKILL.md establishes the contract slot: parse `--json` flag,
emit a wire-contract envelope to stdout, route human-readable output
to stderr. The 2a1 envelope is emission-shaped only:

```json
{
  "$schema_version": 2,
  "plugin": "inkwell",
  "dimension": "code-documentation",
  "categories": [],
  "observations": [],
  "composite_score": null,
  "recommendations": []
}
```

Empty `observations[]` exercises the translator's case-3 carve-out
(passthrough). `composite_score: null` is what the translator reads
when populating the dimension; combined with the empty array it
defers scoring back to the kernel presence check (README ≥10 non-blank
lines → 50/100 capped). Behaviour is end-to-end equivalent to today's
"sibling not installed" branch, so 2a1 ships without changing any
existing harness numbers.

2a2 fills in the deterministic scorers; 2a3 wires them into the
envelope and removes the empty-array short-circuit.

### `agents/parse-inkwell.md` (transitional)

ADR-005 §5 step-2 fallback. Mirrors `agents/parse-claudit.md`'s shape
(read raw audit output, re-emit as wire-contract JSON). Until 2a3
ships, inkwell is registered in `recommendations.json` with
`parser_agent: "parse-inkwell"` and the agent forwards the envelope
unchanged. Marked deprecated in its own header from day one — the
agent exists to satisfy step-2 discovery during the transition only.

### License

MIT, per `.claude/rules/license-selection.md` (Anthony's defaults
table: "Claude Code plugins (quickstop marketplace entries) — MIT").
Standard MIT text; copyright `(c) 2026 Anthony Costanzo` (matching
the in-tree convention across `plugins/{claudit,skillet,commventional,towncrier}/LICENSE`).
README cites `MIT. See [LICENSE](LICENSE).` per the rule file's
mechanics section.

## Implementation order

1. **`plugins/inkwell/.claude-plugin/plugin.json`** — file shape per
   the section above. Pronto block populated; `compatible_pronto`
   pinned at 2a3-merge-time.
2. **`plugins/inkwell/README.md`** — short. What inkwell does, the
   four signals it audits (README quality, docs coverage, staleness,
   internal link health), how to invoke `/inkwell:audit --json`
   standalone, and the MIT license pointer. Mirrors
   `plugins/skillet/README.md`'s shape, with one ADR-006 addition:
   a **"Plugin surface"** section per ADR-006 §1 enumerating what
   the plugin ships:

   ```markdown
   ## Plugin surface

   This plugin ships:
   - Skills: `audit`
   - Commands: none
   - Agents: `parse-inkwell` (transitional, deprecated — see ADR-005 §5)
   - Hooks: none
   - Opinions: none

   This plugin does not ship: cross-plugin automation, consumer
   config edits, or any flow that silently mutates artefacts the
   consumer owns. Consumers compose automation against this
   plugin's capabilities per ADR-006 §6.
   ```

   Inkwell is scaffolded post-ADR-006; landing the §1 surface
   section now avoids the migration deduction the existing in-tree
   plugins will incur until their follow-ups ship.
3. **`plugins/inkwell/LICENSE`** — standard MIT text.
4. **`plugins/inkwell/skills/audit/SKILL.md`** — frontmatter
   (`name: audit`, `description`, `disable-model-invocation: true`,
   `allowed-tools: Read, Glob, Grep, Bash`, `argument-hint: --json`).
   Body: parse `$ARGUMENTS` for `--json`, emit the empty-envelope
   wire shape to stdout, route diagnostic output to stderr. No
   scorers invoked yet — those land in 2a2.
5. **`plugins/inkwell/agents/parse-inkwell.md`** — transitional
   parser agent. Reads raw audit output, re-emits as
   wire-contract JSON. Marked deprecated in the header.
6. **No changes to `plugins/pronto/references/recommendations.json`
   in 2a1.** The slot stays at `recommended_plugin: "inkwell"` with
   the install/audit/parser fields all `null`. 2a3 wires those in
   alongside the rubric stanza so the discovery path lights up
   atomically with the rubric translation rules.

## Acceptance

- `/inkwell:audit --json` runs standalone and emits a single valid
  JSON object on stdout matching the empty-envelope shape above.
- Stdout is exactly one JSON object — no human-readable text, no
  log lines.
- `jq -e '."$schema_version" == 2 and .plugin == "inkwell" and .dimension == "code-documentation" and .observations == []' <output>` passes.
- `plugin.json` declares `pronto.compatible_pronto` (consumed by H1)
  and exactly one `pronto.audits[]` entry for the
  `code-documentation` dimension.
- `LICENSE` is standard MIT text with `Copyright (c) 2026 Anthony Costanzo`.
- README line count ≥10 non-blank lines (the kernel's own presence
  check — inkwell satisfies its own dimension's floor on day one).
- README contains a "Plugin surface" section per ADR-006 §1
  enumerating skills, commands, agents, hooks, and opinions plus the
  non-mutation declaration. Inkwell ships this from day one rather
  than via a migration follow-up.
- No changes to `plugins/pronto/`, `plugins/claudit/`,
  `plugins/skillet/`, `plugins/commventional/`, or
  `plugins/towncrier/` in this commit (verified via
  `git diff main..docs/2a-inkwell-tickets -- plugins/`
  showing only `plugins/inkwell/` paths).
- Eval harness on the existing `mid` fixture: composite stddev still
  ≤ 1.0 with inkwell installed but emitting empty observations[]
  (case-3 passthrough → kernel presence check unchanged).

## Three load-bearing invariants

A. **Empty-envelope is wire-contract-valid.** The translator must
accept the 2a1 envelope without raising. Verified by feeding the
literal envelope to `observations-to-score.sh` in
`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`
under a new "case-3 passthrough on inkwell scaffold" test.

B. **No regression on existing dimensions.** Installing the inkwell
scaffold must not perturb the `claude-code-config`, `skills-quality`,
or `commit-hygiene` scoring paths. Verified by re-running the
existing fixture snapshot tests (`snapshots.test.sh` in claudit,
skillet, commventional) with inkwell present in `plugins/`.

C. **Discovery resolves at step 2 in 2a1, step 1 in 2a3.** With 2a1
alone, `recommendations.json` still carries `audit_command: null` for
code-documentation, so pronto's discovery falls through to the
kernel presence check. With 2a3 merged, `audit_command` is populated
and the SKILL.md exists at the canonical path, so step 1
(`plugins/inkwell/skills/audit/SKILL.md`) wins. The progression is
intentional — 2a1 stages the directory shape, 2a3 lights up the
audit path.

## Out of scope

- **The four shell scorers** (README quality, docs coverage,
  staleness, broken links). Filed as 2a2.
- **Rubric stanza for `code-documentation`** in `rubric.md`. Filed
  as 2a3 — calibrated against fixtures.
- **Updating `recommendations.json`** to populate `install_command`,
  `audit_command`, and `parser_agent`. Filed as 2a3 — happens
  alongside the rubric stanza so the discovery path lights up
  atomically with the rubric translation rules.
- **The transitional parser agent's removal.** A follow-up after
  2a3 ships and step-1 discovery is verified in production. The
  agent is marked deprecated in 2a1 but stays callable for one
  minor version per the standard deprecation cycle.
- **`:doctor` skill.** ADR-005 §2 reserves the name; inkwell's
  diagnostic logic is plain enough that a `:doctor` slot isn't
  earning its keep yet. Add later if there's a self-health check
  that needs a structured exit code.
- **`:fix` skill.** ADR-005 §4 reserves the name; remediation is
  a future ADR.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2a ticket roster
- `project/adrs/004-sibling-composition-contract.md` — `compatible_pronto`,
  `audits[]` shape inkwell declares
- `project/adrs/005-sibling-skill-conventions.md` — `:audit` skill
  conventions, observations vs scores, discovery order
- `project/adrs/006-plugin-responsibility-boundary.md` — §1
  Plugin surface README section inkwell ships from day one
  (2a1/2a2/2a3) and the position of 2a in the post-Hardening
  sequence.
- `project/adrs/004-sibling-composition-contract.md` —
  `compatible_pronto` handshake H1 wires up.
- `project/adrs/005-sibling-skill-conventions.md` §1 (`:audit`),
  §3 (observations vs. score), §5 (discovery order).
- `plugins/pronto/references/sibling-audit-contract.md` — the v2
  wire contract this scaffold emits.
- `plugins/pronto/references/recommendations.json` — the
  `code-documentation` slot 2a3 populates; `recommended_plugin`
  already reads `inkwell`.
- `plugins/pronto/references/rubric.md` — code-documentation row
  (line 14, weight 15) and the `roll-your-own/code-documentation.md`
  pointer.
- `plugins/pronto/references/roll-your-own/code-documentation.md` —
  describes the depth signals 2a2's scorers operationalize.
- `plugins/skillet/` — most ADR-005-conformant in-tree sibling;
  the 2a1 file tree mirrors it.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  translator the empty envelope flows through (case-3 passthrough).
- PR #38 — the prior `plugins/inkwell/` removal. Confirms the name
  is free for the audit role described here.
