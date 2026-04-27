---
$schema_version: 2
updated: 2026-04-26
---

# Sibling Audit Wire Contract

The shared schema pronto uses to aggregate audits from sibling plugins. This document defines the **target state** pronto builds toward — plus the **Phase 1 parser pattern** for siblings that haven't yet adopted it upstream.

> **Schema v2.** The wire contract carries a top-level `$schema_version` field. v2 (this revision) adds `observations[]` as the rubric-scoring channel. v1 emitters that ship only `composite_score` + `categories[]` continue to work via the back-compat passthrough rule documented in [Schema version](#schema-version) below. New siblings (Phase 2 onward) emit observations.

## Why a contract exists

Pronto does not re-implement what siblings already do. `claudit` audits Claude Code config. `skillet` audits skills. `commventional` audits commit hygiene. Pronto's job is to fold each sibling's audit output into a composite readiness score.

For that to work mechanically, every participating sibling needs to emit its audit in a shared shape pronto can parse. That shape is this contract.

## Target state (native emission)

A sibling that has adopted the contract does two things:

### 1. Declare in `plugin.json`

```json
{
  "name": "claudit",
  "version": "2.6.0",
  "pronto": {
    "audits": [
      {
        "dimension": "claude-code-config",
        "command": "/claudit:audit --json",
        "weight_hint": 0.20
      }
    ]
  }
}
```

Field semantics:

- `dimension` — one of the slugs in [`rubric.md`](rubric.md). Pronto uses this to route the audit output to the right rubric row.
- `command` — the slash-command incantation that produces the JSON output. Pronto invokes this in-conversation.
- `weight_hint` — optional. A decimal 0.0–1.0 indicating what weight the sibling thinks this dimension should carry. Pronto's rubric weights are authoritative; `weight_hint` is a suggestion for future rebalancing.

A plugin may declare multiple audits — for example, a plugin that audits both commit hygiene and PR hygiene could declare two entries targeting different dimensions.

### 2. Emit JSON on `--json`

The declared command, when invoked with `--json`, writes a single JSON object to stdout:

```json
{
  "$schema_version": 2,
  "plugin": "claudit",
  "dimension": "claude-code-config",
  "categories": [
    {
      "name": "CLAUDE.md Quality",
      "weight": 0.20,
      "score": 85,
      "findings": [
        {
          "severity": "medium",
          "message": "Restated built-in instruction in CLAUDE.md:12",
          "file": "CLAUDE.md",
          "line": 12
        }
      ]
    },
    {
      "name": "MCP Configuration",
      "weight": 0.15,
      "score": 70,
      "findings": []
    }
  ],
  "observations": [
    {
      "id": "claude-md-redundancy-ratio",
      "kind": "ratio",
      "evidence": { "redundant_lines": 17, "total_lines": 142, "ratio": 0.12 },
      "summary": "12% of CLAUDE.md lines restate built-in instructions"
    },
    {
      "id": "mcp-server-count",
      "kind": "count",
      "evidence": { "configured": 3, "registered": 3 },
      "summary": "3 MCP servers configured, all registered"
    }
  ],
  "composite_score": 78,
  "letter_grade": "B",
  "recommendations": [
    {
      "priority": "high",
      "category": "over-engineering",
      "title": "Trim CLAUDE.md redundancy",
      "impact_points": 15,
      "command": "/claudit"
    }
  ]
}
```

All other output — human-readable report, logs, progress markers — goes to stderr when `--json` is set. Stdout must be exactly one JSON object.

## Field reference

### Top level

| Field | Type | Required | Notes |
|---|---|---|---|
| `$schema_version` | integer | yes (v2+) | Wire contract schema version. `2` for the current revision. v1 emitters that omit this field are accepted via the back-compat passthrough rule (see [Schema version](#schema-version)). |
| `plugin` | string | yes | Plugin name (matches `plugin.json` `name`). |
| `dimension` | string | yes | Rubric dimension slug (see [`rubric.md`](rubric.md)). |
| `categories` | array | yes (v1) / no (v2) | Sub-categories the sibling's internal rubric scores. Required in v1 because it was the only score channel; optional in v2 (a sibling that emits only `observations[]` need not duplicate them as categories). May be empty if the sibling is flat. |
| `observations` | array | yes (v2) | Rubric-scoring channel. Each entry is a structured observation pronto's scorers translate into a per-dimension score. See [`observations[]` entry](#observations-entry). v1 emitters omit this field. |
| `composite_score` | integer | yes (v1) / no (v2) | 0–100. The sibling's weighted mean across its own categories. Required in v1; optional in v2 (a sibling that emits only `observations[]` lets pronto derive the composite from the rubric). |
| `letter_grade` | string | no | `A+`/`A`/`B`/`C`/`D`/`F`. Derived from `composite_score` per the bands in [`rubric.md`](rubric.md). Pronto re-derives if omitted. |
| `recommendations` | array | no | Ranked list of improvement suggestions. |

### `categories[]` entry

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | Human-readable category name. |
| `weight` | number | yes | 0.0–1.0. The sibling's internal weight for this category. Category weights should sum to 1.0. |
| `score` | integer | yes | 0–100. |
| `findings` | array | no | Per-issue detail (severity + message + optional file/line). May be empty. |

### `findings[]` entry

| Field | Type | Required | Notes |
|---|---|---|---|
| `severity` | string | yes | `critical` / `high` / `medium` / `low` / `info`. |
| `message` | string | yes | One-line description of the issue. |
| `file` | string | no | Path relative to repo root. |
| `line` | integer | no | 1-based line number. |

`findings[]` and `observations[]` are parallel concepts with different consumers. Findings are triaged human-readable issues with a severity ladder; observations are raw signal pronto's scorers translate into a rubric score. The same underlying fact can surface as both — a high-severity finding ("3 emit sites bypass the structured envelope") and an observation (`{kind: ratio, evidence: {structured: 17, unstructured: 3}}`) — but they live in separate arrays and serve different audiences.

### `observations[]` entry

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Stable identifier for the observation, e.g. `structured-log-ratio`. The same observation `id` should refer to the same measurement across runs and across sibling versions; pronto uses it to apply rubric translation rules deterministically. Lower-kebab-case by convention. |
| `kind` | string | yes | One of `ratio` / `count` / `presence` / `score`. Names the shape of the underlying measurement; pronto's scorers branch on this to apply the right rubric rule. |
| `evidence` | object | yes | Structured payload describing the measurement. Shape is convention-driven by `kind`: `ratio` carries `numerator` / `denominator` / `ratio`; `count` carries an integer (typically `count` or a domain-named field like `configured`); `presence` carries a boolean `present`; `score` carries an integer 0–100 in `score`. Additional fields are allowed and ignored by pronto unless the rubric references them. |
| `summary` | string | yes | Human-readable one-line description of what was measured. Surfaces in audit reports under "observations" alongside the findings list. |

The four `kind` values map to the rubric translation rules pronto's scorers apply (see [`rubric.md`](rubric.md) for per-dimension rule definitions):

- **`ratio`** — a fraction in `[0, 1]`. Rubric rules typically take the form `ratio >= 0.8 → score 80`, with banded thresholds.
- **`count`** — an integer measurement. Rubric rules take the form of threshold ladders (`count >= 5 → score 100, >= 3 → 75, >= 1 → 50, else 25`).
- **`presence`** — a boolean fact. Rubric rules take the form `present → score X / absent → score Y`.
- **`score`** — a pre-scored integer 0–100. Used when the sibling's domain-specific scoring is already a meaningful 0–100 number; pronto applies a passthrough rule (typically `score → that score`, possibly with a weight). The legacy `composite_score` and per-category `score` fields use this kind via the back-compat passthrough described in [Schema version](#schema-version).

### `recommendations[]` entry

| Field | Type | Required | Notes |
|---|---|---|---|
| `priority` | string | yes | `critical` / `high` / `medium` / `low`. |
| `category` | string | no | Slug referencing which category this would improve. |
| `title` | string | yes | Short imperative description. |
| `impact_points` | integer | no | Estimated point gain if applied. |
| `command` | string | no | Slash-command invocation the consumer can run to apply the fix. |

## Scoring semantics

- All scores are integers 0–100.
- `composite_score` = round(sum(category.weight × category.score for each category)).
- Letter grade bands are inclusive on both ends: `A+` is 95–100, `A` is 90–94, `B` is 75–89, `C` is 60–74, `D` is 40–59, `F` is 0–39.
- If a sibling's internal rubric normalizes category weights to something other than 1.0, pronto renormalizes before folding in.

In v2, the score channel pronto consumes is `observations[]`. Pronto reads each observation, looks up the per-dimension rubric translation rule keyed on the observation's `id`, and applies the rule to produce a 0–100 score. The translation rules live in [`rubric.md`](rubric.md). The `composite_score` field, when present, is treated as informational under v2 — pronto can cross-check the sibling's self-computed composite against its own rubric-applied composite, but the rubric-applied result is authoritative.

## Schema version

The wire contract is versioned. v2 (this revision) introduces `$schema_version` as a top-level wire field, adds `observations[]` as the rubric-scoring channel, and relaxes the v1 requirement that `categories[]` and `composite_score` be present. v1 emitters remain valid via a back-compat passthrough rule.

### Back-compat passthrough rule

A sibling emitting under the v1 contract — `composite_score` present, no `$schema_version`, no `observations[]` — is accepted unchanged. Pronto's scorer treats the v1 `composite_score` as a single coarse observation of `kind: score` and applies the passthrough translation rule (the score becomes the dimension's score directly, subject to the rubric's per-dimension weight in the composite). Per-category `score` fields are similarly passthrough-eligible if the rubric defines a per-category translation, otherwise they're informational.

This keeps already-shipped siblings working without forcing an immediate migration. New siblings (Phase 2 onward) emit `observations[]`. Existing siblings (claudit, skillet, commventional) migrate on their own work cycle; the passthrough covers the gap.

### Negotiation

`$schema_version` exists on the wire so consumers can negotiate. A v2-aware pronto can:

- Read `observations[]` when present (`$schema_version >= 2`).
- Fall through to the v1 passthrough when `$schema_version` is absent or `< 2`.
- Reject a payload claiming `$schema_version > 2` it doesn't understand, surfacing the version mismatch rather than scoring against a contract it doesn't know.

## Phase 1 reality: the parser pattern

Sibling plugins (claudit, skillet, commventional) do not currently ship `--json` or a `plugin.json` declaration. Retrofitting them is tracked in each sibling's own work, not in pronto Phase 1.

Until siblings adopt the contract natively, pronto bridges the gap with **per-sibling parser agents**. A parser agent:

1. Is dispatched by `/pronto:audit` with the sibling's human-readable output captured from stdout/stderr.
2. Reads the output, extracts scores and findings, and emits a JSON object matching this contract.
3. Returns only the JSON object, nothing else.

Parsers live at `plugins/pronto/agents/parsers/<sibling>.md`. They are glue, not product: they vanish from the runtime code path the moment the sibling ships a `plugin.json` declaration and a `--json` flag.

### Parser invocation (inside `/pronto:audit`)

```
1. Inspect target plugin's plugin.json for a `pronto.audits` entry.
2. If present → invoke declared command with --json, parse stdout directly.
3. If absent → look up built-in parser at agents/parsers/<plugin>.md.
   Invoke sibling's default audit command, capture output,
   dispatch parser agent with the captured output, collect JSON.
4. If no parser is registered either → skip sibling,
   score dimension by kernel presence check only.
```

## Discovery

Pronto ships with a **default registry** of known siblings, their current audit commands, and their parsers. The `plugin.json` declaration is the forward path — as siblings adopt the contract, pronto's runtime discovery picks them up automatically and the parser agent becomes dead code. Pronto removes parser agents from the registry on the next minor version after a sibling ships native support.

Consumers with a sibling pronto doesn't know about can register it via the sibling's own `plugin.json` declaration — pronto's runtime discovery is registry-first, not hardcoded.

## Validation

Pronto validates parsed and native-emitted JSON against this contract schema. Validation failures:

- `plugin`/`dimension` missing → skip sibling, treat as not-configured.
- `$schema_version` claims a version pronto doesn't understand (e.g. `> 2`) → skip sibling, surface the version mismatch in `sibling_integration_notes`.
- v2 payload (`$schema_version: 2`) with neither `observations[]` nor a v1-shaped `composite_score`/`categories[]` → skip sibling, surface as missing-score-channel.
- v1 payload: `composite_score` missing or out-of-range → recompute from `categories[]` if possible, otherwise skip.
- `categories[]` weights don't sum to 1.0 (±0.05 tolerance) → renormalize.
- `observations[]` entry missing required fields (`id`, `kind`, `evidence`, `summary`) → drop that entry, record the drop in `sibling_integration_notes`, continue scoring with the remaining observations.
- `observations[]` entry has unknown `kind` → drop that entry, record the drop, continue.
- Unknown fields → ignored (forward compatibility).

Validation errors surface in the audit report's "Sibling integration notes" section, not as tracebacks.

## See also

- [`rubric.md`](rubric.md) — the dimension list and weights the contract plugs into. Per-dimension `observations[]` translation rules live here.
- [`recommendations.json`](recommendations.json) — pronto's default sibling registry, including per-sibling parser pointers.
- [`project/adrs/004-sibling-composition-contract.md`](../../../project/adrs/004-sibling-composition-contract.md) — the composition contract this wire contract serves; ADR-004's "version exists in the registry but not on the contract doc itself" follow-up is closed by the `$schema_version` field added in v2.
- [`project/adrs/005-sibling-skill-conventions.md`](../../../project/adrs/005-sibling-skill-conventions.md) §3 — the authoritative spec for `observations[]`, the four `kind` values, the relationship to `findings[]`, and the back-compat passthrough rule.
