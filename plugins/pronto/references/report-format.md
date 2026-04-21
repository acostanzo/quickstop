# Audit Report Format

The shape of the output `/pronto:audit` produces. Two surfaces:

1. **Markdown scorecard** — human-readable default. Skimmable in under 30s.
2. **JSON composite** — machine-parseable under `--json`. Round-trips through any JSON parser.

Both surfaces are derived from the same underlying state: per-dimension scores, the source each score came from (sibling audit, kernel presence, etc.), and a pointer back to each sibling's full sibling-audit-contract emission for drill-down.

## Markdown scorecard

Default output when `/pronto:audit` is invoked without `--json`.

```
╔══════════════════════════════════════════════════════════╗
║                  PRONTO READINESS SCORECARD              ║
╠══════════════════════════════════════════════════════════╣
║  Composite: 72/100  Grade: C  (Fair)                     ║
║  Repo: /path/to/repo                                     ║
║  Ran: 2026-04-21 19:45 UTC                               ║
╚══════════════════════════════════════════════════════════╝

Weakest first:

  event-emission         ░░░░░░░░░░░░░░░░░░░░░░░░░   0/100  F   × not configured  (weight 5)
  skills-quality         ████████████░░░░░░░░░░░░░  50/100  D   ⊘ presence-cap   (weight 10)  — recommended: skillet
  lint-posture           ████████████░░░░░░░░░░░░░  50/100  D   ⊘ presence-cap   (weight 15)  — recommended: lintguini (Phase 2+)
  project-record         ████████████░░░░░░░░░░░░░  50/100  D   ⊘ presence-cap   (weight 5)   — recommended: avanti (Phase 1b)
  code-documentation     ████████████░░░░░░░░░░░░░  50/100  D   ⊘ presence-cap   (weight 15)  — recommended: inkwell (Phase 2+)
  agents-md              ████████████░░░░░░░░░░░░░  50/100  D   ⊘ kernel presence (weight 10)
  commit-hygiene         ███████████████████░░░░░░  78/100  B   ✓ commventional   (weight 15)
  claude-code-config     ████████████████████░░░░░  82/100  B   ✓ claudit         (weight 25)

What's next:
  Run /pronto:improve to walk the weakest dimensions in order.

Kernel health:
  ✓ AGENTS.md   ✓ project-record   ✗ .pronto/state.json   ✓ .claude/   ✓ README   ✓ LICENSE   ✓ .gitignore

Sibling integration notes:
  - claudit: native --json not available; parsed via parser agent (agents/parsers/claudit).
```

### Visual conventions

- **Score bars** use `█` filled / `░` empty, scaled to 25 characters: `round(score / 100 * 25)` filled blocks.
- **Ordering** is weakest-first by actual numeric score, ties broken by weight (heavier-weight dimensions first so they surface higher in an equal-score tie).
- **Source markers:**
  - `✓` — dimension scored by an installed sibling's audit (real depth score).
  - `⊘` — dimension at the presence cap (sibling missing, kernel presence check passed, score capped at 50).
  - `×` — dimension at 0 (presence check failed, sibling missing).
- **Recommendation trailing text** — only rendered on `⊘` or `×` rows. For `⊘`, it names the recommended sibling. For `×`, no recommendation — `/pronto:improve` surfaces the fix path.

### Header

- **Composite score** is the weighted mean across all 8 dimensions, rounded to the nearest integer.
- **Grade** is derived per the bands in `references/rubric.md`.
- **Repo** is the absolute repo-root path.
- **Ran** is ISO 8601 UTC with second precision.

### Footer

- **What's next** — one line pointing to `/pronto:improve`.
- **Kernel health** — one line with a pass/fail per kernel category from the kernel-check emission. Condensed — full findings are in JSON output.
- **Sibling integration notes** — bullet list flagging siblings that required parser-agent glue (vs. native emission), validation warnings, and any audit failures that didn't traceback but produced degraded output. Omitted if empty.

## JSON composite (`--json`)

Single JSON object written to stdout. All progress or diagnostic output goes to stderr.

```json
{
  "schema_version": 1,
  "repo": "/path/to/repo",
  "timestamp": "2026-04-21T19:45:00Z",
  "composite_score": 72,
  "composite_grade": "C",
  "composite_label": "Fair",
  "dimensions": [
    {
      "dimension": "claude-code-config",
      "weight": 25,
      "score": 82,
      "weighted_contribution": 20.5,
      "source": "sibling",
      "source_plugin": "claudit",
      "source_audit": {
        "plugin": "claudit",
        "dimension": "claude-code-config",
        "categories": [...],
        "composite_score": 82,
        "letter_grade": "B",
        "recommendations": [...]
      },
      "notes": null
    },
    {
      "dimension": "skills-quality",
      "weight": 10,
      "score": 50,
      "weighted_contribution": 5.0,
      "source": "kernel-presence-cap",
      "source_plugin": null,
      "source_audit": null,
      "notes": "skillet not installed; kernel presence check passed; capped at 50"
    },
    {
      "dimension": "event-emission",
      "weight": 5,
      "score": 0,
      "weighted_contribution": 0.0,
      "source": "presence-fail",
      "source_plugin": null,
      "source_audit": null,
      "notes": "autopompa not installed; observability grep found no matches"
    }
  ],
  "kernel": {
    "plugin": "pronto-kernel",
    "dimension": "kernel",
    "categories": [...],
    "composite_score": 86,
    "letter_grade": "B",
    "recommendations": [...]
  },
  "sibling_integration_notes": [
    "claudit: native --json not available; parsed via agents/parsers/claudit"
  ]
}
```

### Top-level fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema_version` | integer | yes | Currently `1`. Increment on breaking shape change. |
| `repo` | string | yes | Absolute repo-root path. |
| `timestamp` | string | yes | ISO 8601 UTC with second precision (`YYYY-MM-DDTHH:MM:SSZ`). |
| `composite_score` | integer | yes | 0–100, weighted mean across all dimensions. |
| `composite_grade` | string | yes | `A+`/`A`/`B`/`C`/`D`/`F`. |
| `composite_label` | string | yes | `Exceptional`/`Excellent`/`Good`/`Fair`/`Needs Work`/`Critical`. |
| `dimensions` | array | yes | One entry per rubric dimension. Length = 8 in Phase 1. |
| `kernel` | object | yes | Full kernel-check emission, for drill-down. |
| `sibling_integration_notes` | array[string] | no | Optional — warnings about parser fallback, validation, partial failures. |

### `dimensions[]` entry

| Field | Type | Required | Notes |
|---|---|---|---|
| `dimension` | string | yes | Rubric dimension slug. |
| `weight` | integer | yes | Dimension weight from rubric.md. |
| `score` | integer | yes | 0–100 final score for this dimension. |
| `weighted_contribution` | number | yes | `weight * score / 100`, rounded to one decimal. |
| `source` | string | yes | One of: `sibling`, `kernel-presence-cap`, `presence-fail`, `kernel-owned`. |
| `source_plugin` | string\|null | yes | Plugin name if `source == sibling`, else `null`. |
| `source_audit` | object\|null | yes | Full sibling-audit-contract emission if `source == sibling`, else `null`. |
| `notes` | string\|null | yes | Human-readable explanation of the score path. |

### `source` enum semantics

| Value | When |
|---|---|
| `sibling` | A sibling plugin ran its audit and produced a contract-conformant result. `score` is the sibling's `composite_score`. |
| `kernel-presence-cap` | Sibling absent; kernel presence check passed; score capped at 50. |
| `presence-fail` | Sibling absent; presence check failed; score is 0. |
| `kernel-owned` | Dimension is owned by the pronto kernel itself (e.g., `agents-md` always uses the kernel-check category score directly, up to the cap). |

## Validation

`--json` output must:

- Parse as valid JSON.
- Contain all required top-level fields.
- Have `dimensions` length equal to the number of rubric rows (8 in Phase 1).
- Have `weighted_contribution` values whose sum equals `composite_score` (within ±1 for rounding).
- Pass schema validation: every `dimension.source` is a member of the documented enum.

Validation errors surface in the `sibling_integration_notes` array, not as tracebacks. The orchestrator is expected to produce a valid JSON envelope even when individual siblings fail — partial failure is not total failure.

## Size target

A full scorecard (8 dimensions, 3 installed siblings, kernel output included) should fit in under 12 KB of JSON and render in under 30 screen rows of markdown. Drill-down detail lives inside `dimensions[].source_audit` and is readable only in the JSON path — the markdown report summarizes.
