---
phase: 1
status: active
tickets: [t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, a1, a2, a3]
updated: 2026-04-21
---

# Avanti Phase 1 — SDLC Work Layer

## The role in one paragraph

Avanti is the **SDLC work layer** of the quickstop constellation. It authors and maintains the records under `project/` — plans, tickets, ADRs, and the pulse journal — and drives each record through its lifecycle (draft → active → done; open → closed; proposed → accepted → superseded). Avanti is to `project/` what inkwell will be to `docs/`: the plugin that owns the contents. It's also the depth auditor pronto delegates to for the "Project record" rubric dimension, so once avanti ships, pronto's Phase 1 presence-only check becomes a real SDLC-hygiene audit.

Avanti lives at `acostanzo/quickstop/plugins/avanti/`. It is a plugin, sibling to pronto.

## Relationship to pronto

Avanti is Phase 1b in the constellation plan established by pronto Phase 1a (see `project/plans/active/phase-1-pronto.md`). The two ship as a pair:

- **Pronto owns presence.** `/pronto:init` scaffolds `project/` skeleton (empty `plans/`, `tickets/`, `adrs/`, placeholder `pulse.md`). Pronto's kernel verifies the directories exist and contain the expected subdir shape.
- **Avanti owns contents.** Skills for authoring each artifact type, lifecycle transitions between states, and a depth audit that scores SDLC hygiene for pronto to fold into the composite.

Either plugin can land first. Pronto Phase 1a is merged as of b2ee6d2; avanti Phase 1b is this plan.

## The model

### Lifecycle state machines

Avanti formalizes three lifecycles. Each has a canonical state set, a folder layout, and frontmatter mirroring.

| Artifact | States | Folder layout | Terminal |
|---|---|---|---|
| Plan | draft → active → done | `project/plans/{draft,active,done}/<slug>.md` | `done/` |
| Ticket | open → in-progress → closed | `project/tickets/{open,closed}/<id>-<slug>.md` | `closed/` |
| ADR | proposed → accepted → superseded | `project/adrs/<NNN>-<slug>.md` (flat; status in frontmatter) | N/A — ADRs stay in place |

**Folder-as-primary.** The folder a file lives in is the authoritative state; frontmatter `status:` mirrors for machine-readability. `/avanti:promote` moves files between folders and updates frontmatter atomically. For ADRs, folders are flat because the sequence matters more than the state — `status:` in frontmatter is authoritative, supersession links are explicit (`superseded_by: 007`).

**"Active" = plan of record, not "currently executing."** A plan is `active` the moment it's adopted — execution may or may not have begun. Execution granularity is tracked by ticket states (`open` / `in-progress` / `closed`), not by promoting the plan itself back and forth. A plan only leaves `active` when every ticket it owns is closed and its acceptance bars pass, at which point it moves to `done`.

**The PR is the draft surface.** Plans land in `plans/active/` at merge time; authoring is the PR review. `plans/draft/` is the escape hatch for plans that were merged but aren't ready to execute — rare, but the shelf is there.

**Tool state.** Avanti gets its own hidden directory — `.avanti/` — symmetric to pronto's `.pronto/`. Holds the repo-wide ticket-ID counter and any other tool-owned state. Git-pattern: tool-named, hidden, never user-authored.

### Skill surface

Avanti ships seven skills in Phase 1. User-invocable, slash-command shaped:

| Command | Purpose |
|---|---|
| `/avanti:plan <slug>` | Draft a new plan from template into `project/plans/active/` |
| `/avanti:ticket <slug>` | Draft a new ticket from template into `project/tickets/open/` |
| `/avanti:adr <slug>` | Draft a new ADR from template into `project/adrs/` |
| `/avanti:promote <artifact>` | Move an artifact forward through its lifecycle |
| `/avanti:pulse <message>` | Append a timestamped entry to `project/pulse.md` |
| `/avanti:status` | Summarize active plans, open tickets, recent pulse entries, proposed ADRs |
| `/avanti:audit` | SDLC hygiene audit — emits pronto wire contract JSON |

Out of Phase 1: `/avanti:close` (folded into `/avanti:promote`), `/avanti:improve` (pronto drives improvement cross-dimension), per-artifact-type status commands (one `/avanti:status` covers all).

### Templates

Avanti ships four templates in `plugins/avanti/templates/`:

- `plan.md` — frontmatter + pivot paragraph + model + tickets + acceptance bars + out-of-scope + DoD. Mirrors the shape this very plan uses, so the convention is self-dogfooding.
- `ticket.md` — frontmatter + context + acceptance criteria + links-to-plan.
- `adr.md` — frontmatter + context + decision + consequences + alternatives. MADR-flavored, not MADR-strict.
- `pulse.md` — append-only journal header + first-entry example. Consumer-authored from there.

Templates are portable — no author-specific strings — and land in consumer repos via `/avanti:plan`, `/avanti:ticket`, `/avanti:adr` (which copy-and-fill) rather than a separate `/avanti:init` (that surface belongs to pronto's kernel).

### Frontmatter conventions

Every artifact file carries a frontmatter envelope. Minimum fields per type:

**Plan:**
```yaml
---
phase: 1              # integer
status: draft|active|done
tickets: [t1, t2, ...] # optional; plan-scoped ticket IDs
updated: YYYY-MM-DD
---
```

**Ticket:**
```yaml
---
id: t1                # plan-scoped OR repo-wide; author decides
plan: phase-1-avanti  # slug of containing plan, or null for standalone
status: open|in-progress|closed
updated: YYYY-MM-DD
---
```

**ADR:**
```yaml
---
id: 002               # zero-padded, repo-wide sequence
status: proposed|accepted|superseded
superseded_by: null   # or another ADR id
updated: YYYY-MM-DD
---
```

**Pulse entries** have no per-entry frontmatter — the file has one top-level header and dated entries append below.

### Pronto audit integration (wire contract)

Avanti declares the pronto audit contract in its `plugin.json`:

```json
{
  "name": "avanti",
  "version": "0.1.0",
  "pronto": {
    "audits": [
      {
        "dimension": "project-record",
        "command": "/avanti:audit --json",
        "weight_hint": 0.05
      }
    ]
  }
}
```

`/avanti:audit --json` emits stdout JSON per `plugins/pronto/references/sibling-audit-contract.md`:

```json
{
  "plugin": "avanti",
  "dimension": "project-record",
  "categories": [
    { "name": "Plan freshness", "weight": 0.30, "score": 80, "findings": [...] },
    { "name": "Ticket hygiene", "weight": 0.30, "score": 70, "findings": [...] },
    { "name": "ADR completeness", "weight": 0.20, "score": 90, "findings": [...] },
    { "name": "Pulse cadence", "weight": 0.20, "score": 60, "findings": [...] }
  ],
  "composite_score": 75,
  "letter_grade": "B",
  "recommendations": [...]
}
```

Avanti is structured to ship the contract natively from day one — `plugin.json` declaration + `--json` output — setting the pattern other siblings will follow when they retrofit. If claudit/skillet/commventional retrofit first, avanti joins the native-emitter set without drama; either way, pronto drops the avanti parser from its registry once avanti ships.

### Audit categories

What avanti's depth audit actually measures:

- **Plan freshness** — Are active plans being worked? Last-commit-touched date per active plan, flagged stale after N days. Stale-plan count + ages.
- **Ticket hygiene** — Open tickets with plans that have since moved to `done/`. Tickets older than N days with no `status: in-progress` touch. Tickets with no linked plan (orphans).
- **ADR completeness** — ADRs in `proposed` state with no decision recorded beyond context. ADRs referencing superseded ADRs that don't themselves link via `superseded_by`.
- **Pulse cadence** — Days since last pulse entry. Empty pulse files (scaffolded but never appended to).

Thresholds are tuning knobs — Phase 1 ships sensible defaults (stale = 30 days, cadence warning = 14 days) and surfaces them in `plugins/avanti/references/audit-thresholds.md` for consumers to adjust.

## Tickets

### T1 — Scaffold plugins/avanti/ via smith

Run `smith` in quickstop to generate `plugins/avanti/` with correct structure: `.claude-plugin/plugin.json`, `skills/`, `agents/`, `references/`, `templates/`, `README.md`. Version 0.1.0. Plugin.json declares the `pronto` extension block with the project-record audit (empty command for now — wired in T10).

**Acceptance:** `plugins/avanti/` exists; loads cleanly under `claude --plugin-dir plugins/avanti`; `/reload-plugins` surfaces no errors; `plugin.json` parses as valid JSON.

### T2 — SDLC conventions reference

Write `plugins/avanti/references/sdlc-conventions.md` — the canonical doc consumers read to understand the lifecycle model. Covers: state machines per artifact type, folder-as-primary rule, frontmatter schemas, where each artifact type lives, how `/avanti:promote` handles transitions, how pulse.md is structured.

**Acceptance:** doc exists, linked from README, portable (no author-specific strings), under ~400 lines.

### T3 — Templates

`plugins/avanti/templates/{plan,ticket,adr,pulse}.md` — the shapes authoring skills copy from. Templates are minimal but complete: all required frontmatter fields present with placeholders, body skeleton that prompts the author toward the right shape.

**Acceptance:** all templates parse as valid YAML frontmatter; body placeholders are obvious (`<fill in>` or `TODO:`-style) not confusable with real content; grep for author-specific strings returns zero matches.

### T4 — `/avanti:plan` skill

Skill: `plugins/avanti/skills/plan/`. Takes a slug argument, copies `templates/plan.md` to `project/plans/active/<slug>.md`, opens an interactive authoring flow that fills in frontmatter and the pivot paragraph. Refuses to overwrite existing files.

**Acceptance:** `/avanti:plan foo-feature` produces `project/plans/active/foo-feature.md` with valid frontmatter and a non-empty pivot paragraph; re-running without different slug errors clearly; file loads cleanly in an editor.

### T5 — `/avanti:ticket` skill

Skill: `plugins/avanti/skills/ticket/`. Takes a slug argument + optional `--plan <slug>` to link, copies `templates/ticket.md` to `project/tickets/open/<id>-<slug>.md`. Mints an ID: if linked to a plan, scoped `t1`/`t2`/... per that plan (plan's frontmatter `tickets:` array is the authoritative source of used IDs); if standalone, repo-wide sequence `T001`/`T002`/... tracked in `.avanti/next-ticket-id` (tool state, gitignored).

**Acceptance:** linked ticket lands with correct plan reference in frontmatter; standalone ticket lands with monotonic repo-wide ID; IDs never collide; counter persists across invocations.

### T6 — `/avanti:adr` skill

Skill: `plugins/avanti/skills/adr/`. Takes a slug argument, mints next ADR number (zero-padded, repo-wide), copies `templates/adr.md` to `project/adrs/<NNN>-<slug>.md`. Initial status: `proposed`. Interactive authoring fills in context + decision + consequences.

**Acceptance:** `/avanti:adr my-decision` produces `project/adrs/003-my-decision.md` (or next unused number); frontmatter defaults to `status: proposed`; doesn't collide with existing ADR numbers.

### T7 — `/avanti:promote` skill

Skill: `plugins/avanti/skills/promote/`. Takes an artifact path (or a shortcut like `plan:foo-feature`), resolves its current state from folder + frontmatter, proposes the next legal transition, and on confirmation: (a) moves the file to the new folder, (b) updates frontmatter `status:`, (c) bumps `updated:`, (d) appends a pulse entry noting the transition. For ADRs, updates frontmatter only (flat folder). Supports `--supersedes <id>` for ADR transitions that retire prior decisions.

**Acceptance:** round-trip a plan through draft → active → done produces the file at each expected location with correct frontmatter at each step; ADR promotion to `superseded` requires a `--supersedes` target and cross-links correctly; illegal transitions (e.g., done → draft) error clearly.

### T8 — `/avanti:pulse` skill

Skill: `plugins/avanti/skills/pulse/`. Appends a timestamped entry to `project/pulse.md`. Entry shape:

```markdown
## 2026-04-21 14:32

<message body>
```

Supports piped stdin (`echo "note" | /avanti:pulse`) and positional args. Never edits prior entries — append-only.

**Acceptance:** entries land in chronological order; timestamps are ISO-8601 dates + HH:MM; prior entries are never modified; empty pulse.md is initialized with a one-line header on first invocation.

### T9 — `/avanti:status` skill

Skill: `plugins/avanti/skills/status/`. Reports: active plans (count + names + last-touched), open tickets (count + IDs + age), proposed ADRs (count + IDs), last pulse entry timestamp + age. Two-line summary + optional `--verbose` full dump.

**Acceptance:** runs against a populated `project/` produces a one-screen report; runs against an empty `project/` reports "no work in flight" without error.

### T10 — `/avanti:audit` skill + wire contract emission

Skill: `plugins/avanti/skills/audit/`. Reads `project/` contents, runs the four category measurements (plan freshness, ticket hygiene, ADR completeness, pulse cadence) against thresholds from `references/audit-thresholds.md`, emits markdown scorecard + JSON per `plugins/pronto/references/sibling-audit-contract.md` when `--json` is passed.

**Acceptance:** run on a well-maintained `project/` produces a high score; run on a `project/` with stale plans / orphan tickets / missing ADR decisions produces a low score with specific findings; JSON output validates against pronto's contract schema.

### T11 — README + audit thresholds reference

`plugins/avanti/README.md` — under 200 words, explains the role + skill surface + links to sdlc-conventions.md. `plugins/avanti/references/audit-thresholds.md` — the tunable knobs (stale-plan days, pulse-cadence warning days, ticket-age warning days).

**Acceptance:** README under 200 words; thresholds doc lists each knob with default + rationale + how to override (per-repo `.avanti/config.json` or frontmatter override).

### T12 — Dogfood: Phase 1 execution records

As the plan executes, avanti's own conventions are applied reflexively:

- Each T-ticket lands a commit that touches `plugins/avanti/` AND an entry in `project/tickets/open/<id>-<slug>.md` on creation, then moves to `closed/` on ticket completion.
- Two ADRs land — one recording avanti's scope + model, one recording the lifecycle state-machine model (folder-as-primary with frontmatter mirror). Numbers are next-sequential at authoring time; if pronto's 001-meta-orchestrator-model.md has already landed by then, avanti's are 002 and 003.
- Pulse entries append at each major milestone (T1 landing, each subsequent ticket landing, each A-bar passing).
- `phase-1-pronto.md` frontmatter is normalized from `status: planning` to one of the canonical states (`active` while pronto's T-tickets are in flight; `done` once its A-bars pass). Part of applying avanti's conventions reflexively to the records already in `project/`.

**Acceptance:** by the time A-bars run, `project/` contains 12 closed tickets, 2 accepted ADRs, an active plan (this one), and a populated pulse.md.

## Acceptance bars

Every A-bar passes on a fresh machine with only quickstop installed and `/pronto:init` run in the target repo.

### A1 — Authoring round-trip

1. In a pronto-init'd test repo: `/avanti:plan feature-x`
2. `/avanti:ticket first-step --plan feature-x`
3. `/avanti:adr choose-foo`
4. `/avanti:pulse "started feature-x"`

Verify: plan at `project/plans/active/feature-x.md` with valid frontmatter; ticket at `project/tickets/open/t1-first-step.md` linked to the plan; ADR at `project/adrs/<NNN>-choose-foo.md` with `status: proposed`; pulse entry appended under today's date.

**Pass:** every file produced validates against its template's frontmatter schema; no file overwrites occur; interactive prompts are coherent.

### A2 — Lifecycle round-trip

Same repo as A1:
1. `/avanti:promote plan:feature-x` → moves to `active/` (already there; no-op or clear message)
2. `/avanti:promote ticket:t1-first-step` → moves to `tickets/closed/`; pulse entry appended
3. `/avanti:promote plan:feature-x` → moves to `plans/done/`; pulse entry appended
4. `/avanti:promote adr:<NNN>-choose-foo` → interactively prompts for `accepted`; frontmatter updated

Verify: at each step, file lives at the folder the new state specifies, frontmatter `status:` matches the folder, `updated:` bumps to today, a pulse entry records the transition.

**Pass:** folder-as-primary rule holds, frontmatter mirrors correctly, transitions emit pulse entries.

### A3 — Audit emits pronto wire contract

Same repo as A2:
1. `/avanti:audit --json` → stdout JSON
2. Validate JSON against `plugins/pronto/references/sibling-audit-contract.md` schema
3. `/pronto:audit` with both pronto + avanti installed → composite scorecard folds avanti's project-record score in at weight 0.05

**Pass:** avanti's JSON round-trips through a parser without loss; pronto picks up avanti's depth score (not presence-only); composite letter grade reflects avanti's contribution.

## Out of scope

- Authoring skills for non-SDLC artifacts (meeting notes, release notes — towncrier owns release notes; meeting notes don't belong here)
- Cross-repo aggregation (consumer-orchestrator concern)
- Automatic ticket/plan generation from chat transcripts
- Metrics beyond the four audit categories (velocity, burndown, etc.)
- Integration with external issue trackers (GitHub Issues, Linear) — consumer's problem, not avanti's
- `/avanti:close` (folded into `/avanti:promote`)
- `/avanti:improve` (pronto drives cross-dimension improvement; avanti's audit surfaces findings, pronto sequences the fixes)
- Template customization per-consumer beyond frontmatter override (deferred until real demand surfaces)
- Retroactive migration tooling (for consumers with existing plan/ticket/ADR files in other shapes)

## Definition of done

- All T-tickets land with their own atomic conventional commits (plugin code under `plugins/avanti/`; project records under `project/`).
- All A-bars pass on a fresh machine with only quickstop installed.
- `plugins/avanti/README.md` explains the role in under 200 words and links to `sdlc-conventions.md`.
- Comprehensive grep for author-specific strings (`anthony`, `batcomputer`, `batdev`, `batvault`, `alfred`, `grapple-gun`, `batctl`, `mind-palace`) returns zero matches in `plugins/avanti/`.
- Plugin loads cleanly under `claude --plugin-dir plugins/avanti` with no errors on `/reload-plugins`.
- Two ADRs land — one recording avanti's scope + model, one recording the lifecycle state-machine (folder-as-primary with frontmatter mirror). Numbers allocated next-sequential at authoring time.
- Pronto's "Project record" rubric dimension, previously presence-only, now picks up avanti's depth audit on any repo with both plugins installed. Verified by running `/pronto:audit` in the A3 fixture.
