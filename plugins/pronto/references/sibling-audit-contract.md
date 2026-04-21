# Sibling Audit Wire Contract

The shared schema pronto uses to aggregate audits from sibling plugins. This document defines the **target state** pronto builds toward — plus the **Phase 1 parser pattern** for siblings that haven't yet adopted it upstream.

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
| `plugin` | string | yes | Plugin name (matches `plugin.json` `name`). |
| `dimension` | string | yes | Rubric dimension slug (see [`rubric.md`](rubric.md)). |
| `categories` | array | yes | Sub-categories the sibling's internal rubric scores. May be empty if the sibling is flat. |
| `composite_score` | integer | yes | 0–100. The sibling's weighted mean across its own categories. |
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
- `composite_score` missing or out-of-range → recompute from `categories[]` if possible, otherwise skip.
- `categories[]` weights don't sum to 1.0 (±0.05 tolerance) → renormalize.
- Unknown fields → ignored (forward compatibility).

Validation errors surface in the audit report's "Sibling integration notes" section, not as tracebacks.

## See also

- [`rubric.md`](rubric.md) — the dimension list and weights the contract plugs into.
- [`recommendations.json`](recommendations.json) — pronto's default sibling registry, including per-sibling parser pointers.
