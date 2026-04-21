---
name: audit
description: Run pronto's composite readiness audit — walks the rubric, delegates per-dimension to installed sibling plugins, falls back to kernel presence checks, emits a composite scorecard
disable-model-invocation: true
argument-hint: "[--json]"
allowed-tools: Task, Read, Glob, Grep, Bash, Write
---

# Pronto: Readiness Audit

You are the Pronto audit orchestrator. When the user runs `/pronto:audit` or `/pronto:audit --json`, walk the readiness rubric, delegate depth scoring to installed sibling plugins, fall back to kernel presence checks when siblings are absent, and emit a composite scorecard.

This skill is **pure orchestration**: it owns none of the depth analysis. Kernel presence is delegated to `/pronto:kernel-check`; sibling-specific scoring is delegated to each sibling's native audit or a per-sibling parser agent.

## Arguments

Parse `$ARGUMENTS`:
- Contains `--json` → **OUTPUT_MODE = "json"**.
- Otherwise → **OUTPUT_MODE = "markdown"**.

## Phase 0: Resolve environment

1. **REPO_ROOT**: `git rev-parse --show-toplevel 2>/dev/null`. If this fails, tell the user the audit must run inside a git repo and stop.
2. **TIMESTAMP**: `date -u +"%Y-%m-%dT%H:%M:%SZ"` — ISO 8601 UTC.
3. **PLUGIN_ROOT**: `${CLAUDE_PLUGIN_ROOT}` — pronto's own root, for reading references.

## Phase 1: Load registries

1. **Rubric**: Read `${PLUGIN_ROOT}/references/rubric.md` — used for weights, presence-check definitions, letter-grade bands.
2. **Recommendations**: Read `${PLUGIN_ROOT}/references/recommendations.json` — used to map each dimension to its recommended sibling plugin and install command.
3. **Report format**: Read `${PLUGIN_ROOT}/references/report-format.md` — used for the output shape.

## Phase 2: Discover installed siblings

Determine which sibling plugins are available. Check in this order:

1. **Repo-local plugins**: Read `${REPO_ROOT}/.claude-plugin/marketplace.json` if present — lists plugins available in the current marketplace (e.g., quickstop itself).
2. **Installed plugins**: Read `~/.claude/plugins/installed_plugins.json` if present — lists globally installed plugins.
3. **Plugin.json declarations**: For each installed plugin, read its `plugin.json`. If it carries a `pronto.audits` block, record the dimension → command mapping for native emission.

Store the discovery result as **INSTALLED_SIBLINGS** — a map from plugin name to `{ version, native_declarations, plugin_root }`.

## Phase 2.5: Load expert context (optional)

If `claudit` is in INSTALLED_SIBLINGS, invoke `/claudit:knowledge ecosystem` and capture its output.

- **If the skill runs successfully** (outputs `=== CLAUDIT KNOWLEDGE: ecosystem ===`): store as **EXPERT_CONTEXT**. Pass to parsers via their dispatch prompt so they can use current Anthropic best-practice knowledge when scoring edge cases.
- **If claudit is installed but the skill invocation fails**: set EXPERT_CONTEXT to empty, note in `sibling_integration_notes`. Proceed without expert context — parsers run with their deterministic fallback logic.
- **If claudit is not installed**: set EXPERT_CONTEXT to empty. No fallback research agents — pronto's parsers are deterministic by design. Note in the report: `expert context unavailable (install claudit for research-informed audit depth)`.

See `${PLUGIN_ROOT}/references/research-integration.md` for the full cache-consumption protocol and invalidation semantics.

## Phase 3: Run kernel-check

Invoke the kernel-check skill for the repo's baseline:

```
Invoke `/pronto:kernel-check --json` via Bash or skill invocation.
Capture stdout as KERNEL_JSON. Parse as JSON.
```

If parsing fails, note the failure in `sibling_integration_notes` and treat all kernel categories as fail (score 0) for this run. Do not traceback.

Extract the kernel's `categories[]` and build a map from category name to score:

```
KERNEL_CATEGORY_SCORES = {
  "AGENTS.md scaffold": <0 or 100>,
  "Project record container": <0 or 100>,
  "Tool-state (.pronto/)": <0 or 100>,
  ".claude/ presence": <0 or 100>,
  "README": <0 or 100>,
  "LICENSE": <0 or 100>,
  ".gitignore": <0 or 100>
}
```

## Phase 4: Per-dimension scoring

Walk every dimension in the rubric (8 rows in Phase 1). For each, resolve the score via the following decision tree:

### Dimension: agents-md (kernel-owned)

- Source: `kernel-owned`.
- Score: `KERNEL_CATEGORY_SCORES["AGENTS.md scaffold"]` (0 or 100, no cap — this dimension is always kernel-driven).

### Dimension: project-record (kernel-owned until avanti ships)

- If `avanti` is in INSTALLED_SIBLINGS and declares `project-record` natively → invoke declared command, use composite_score. Source: `sibling`.
- Else → use `KERNEL_CATEGORY_SCORES["Project record container"]`; cap at 50 if 100 (present), 0 if 0 (absent). Source: `kernel-presence-cap` or `presence-fail`.

### Other dimensions (sibling-owned with optional parser)

For each of `claude-code-config`, `skills-quality`, `commit-hygiene`, `code-documentation`, `lint-posture`, `event-emission`:

1. **Look up recommendation**: from `recommendations.json`, get `recommended_plugin`, `audit_command`, `parser_agent`.
2. **Check sibling installed**:
   - If the recommended plugin is in INSTALLED_SIBLINGS AND declares the dimension natively in its `plugin.json` `pronto.audits` block → invoke the declared command with `--json`, capture stdout, parse as JSON. Validate against the contract. Source: `sibling`. Score: `composite_score`.
   - Else if a `parser_agent` is registered for this dimension (e.g., `parsers/claudit`, `parsers/skillet`, `parsers/commventional`) → dispatch the parser as a subagent (see Phase 4.1 below). Source: `sibling` (the parser *is* the sibling's audit in Phase 1). Score: parser's `composite_score`.
   - Else → fall through to presence check.
3. **Presence fallback** (sibling not installed AND no parser):
   - Run the presence check defined in `rubric.md` for this dimension. Presence checks by dimension:
     - `claude-code-config`: `KERNEL_CATEGORY_SCORES[".claude/ presence"]`
     - `code-documentation`: `KERNEL_CATEGORY_SCORES["README"]`
     - `skills-quality`: Glob `${REPO_ROOT}/.claude/skills/*/SKILL.md`, `${REPO_ROOT}/plugins/*/skills/*/SKILL.md` — if any matches → 100, else 0.
     - `commit-hygiene`: `git log -20 --pretty=format:%s`; count lines matching `^(feat|fix|chore|docs|refactor|test|perf|build|ci|style)(\([a-z0-9-]+\))?!?: .+`; ratio ≥ 0.80 → 100, else 0.
     - `lint-posture`: check for any of the files listed in rubric.md's lint-posture row. Any exists → 100, else 0.
     - `event-emission`: Grep `${REPO_ROOT}` (excluding `.git/`, `node_modules/`, `.venv/`, `dist/`, `build/`) for `opentelemetry|OTEL_|tracer|metric|event_bus|eventbus|emit\(|structlog|pino|winston|logrus`. Any match → 100, else 0.
   - If presence passes → score 50, source `kernel-presence-cap`.
   - If presence fails → score 0, source `presence-fail`.

### Phase 4.1: Parser dispatch

When dispatching a parser agent, use the Task tool with these fields:

- `subagent_type`: `pronto:parse-claudit`, `pronto:parse-skillet`, or `pronto:parse-commventional` (the parser agent names after their files in `agents/parsers/`).
- `description`: `Parse <sibling> audit`.
- `prompt`: A compact brief telling the parser which repo to audit (absolute path), the dimension slug it's scoring, and the contract shape it must emit. Instruct the parser to return **only** the JSON object — no prose wrapping.

Parsers run foreground because their output feeds the next phase directly. Validate the parser's return: must be valid JSON, must have `plugin`, `dimension`, `composite_score`, `categories[]`. On invalid return, degrade to the presence fallback and append a note to `sibling_integration_notes`.

## Phase 5: Aggregate

For each dimension in the rubric:

- `weight` from the rubric row.
- `score` from Phase 4.
- `weighted_contribution = round(weight * score / 100, 1)`.

Compute `composite_score = round(sum(weighted_contribution))`. Clamp to 0–100.

Derive `composite_grade` and `composite_label` per the bands in `rubric.md`:

| Grade | Range | Label |
|---|---|---|
| A+ | 95-100 | Exceptional |
| A | 90-94 | Excellent |
| B | 75-89 | Good |
| C | 60-74 | Fair |
| D | 40-59 | Needs Work |
| F | 0-39 | Critical |

## Phase 6: Emit

### If OUTPUT_MODE == "json"

**Emit ONLY the JSON object to stdout. Nothing else.**

Hard rules (violating any of these breaks `jq` piping and is a test failure, not a style nit):

- No markdown code fences. Do not wrap the output in ` ```json ` / ` ``` `. The first byte on stdout must be `{` and the last must be `}`.
- No prose preamble ("Emitting the JSON composite…", "Here is the output:").
- No trailing narrative ("State persisted to .pronto/state.json", "Composite 57/100…", summary lines, next-step banners).
- No blank line before or after the JSON object.
- All progress, state-persistence confirmations, and diagnostics go to **stderr** (`echo "..." >&2`) or are suppressed entirely. Never to stdout.

If you are tempted to explain what you did, either send it to stderr via `echo >&2` or omit it. Machine consumers pipe stdout through `jq` — any prose, any fence, any extra line contaminates the pipe and is a bug.

The object shape is defined in `references/report-format.md`. Top-level required fields:

- `schema_version`: `1`
- `repo`: absolute REPO_ROOT path
- `timestamp`: TIMESTAMP (ISO 8601 UTC)
- `composite_score`: integer 0–100
- `composite_grade`: letter per the bands above
- `composite_label`: label per the bands above
- `dimensions`: array, one entry per rubric dimension (shape in `references/report-format.md`)
- `kernel`: the full KERNEL_JSON object captured in Phase 3
- `sibling_integration_notes`: array of strings (empty array `[]` if no notes)

### If OUTPUT_MODE == "markdown"

Present the scorecard per the template in `references/report-format.md`:

```
╔══════════════════════════════════════════════════════════╗
║                  PRONTO READINESS SCORECARD              ║
╠══════════════════════════════════════════════════════════╣
║  Composite: XX/100  Grade: X  (Label)                    ║
║  Repo: <REPO_ROOT>                                       ║
║  Ran: <TIMESTAMP>                                        ║
╚══════════════════════════════════════════════════════════╝

Weakest first:

  <dimension rows ordered ascending by score, ties broken by descending weight>

What's next:
  Run /pronto:improve to walk the weakest dimensions in order.

Kernel health:
  <✓/✗ per kernel category>

Sibling integration notes:
  <bullets or omitted if empty>
```

Rendering rules for dimension rows:

- Score bar: 25 characters, `█` for filled, `░` for empty; filled = `round(score * 25 / 100)`.
- Source marker: `✓` sibling-scored, `⊘` presence-cap, `×` presence-fail, `◉` kernel-owned.
- Trailing annotation:
  - `✓` rows: ` ✓ <sibling-plugin> (weight W)`
  - `⊘` rows: ` ⊘ presence-cap (weight W)  — recommended: <sibling-plugin>[ (Phase N)]`
  - `×` rows: ` × not configured (weight W)  — recommended: <sibling-plugin>`
  - `◉` rows: ` ◉ kernel-owned (weight W)`

Annotations showing `(Phase N)` surface for siblings whose `plugin_status` is `phase-1b` or `phase-2-plus` in `recommendations.json`.

## Phase 7: Persist state

Write the JSON composite to `${REPO_ROOT}/.pronto/state.json`. Create `.pronto/` if missing. Overwrite any prior state.

In **JSON mode**, any confirmation or diagnostic about state persistence (e.g., "State persisted to .pronto/state.json") goes to **stderr** only — never to stdout. Stdout already received its sole payload in Phase 6 (the JSON composite), and adding trailing prose breaks machine consumers piping through `jq`. In markdown mode, the state-persistence confirmation is optional and may appear after the scorecard.

Schema:

```json
{
  "schema_version": 1,
  "last_audit": "<TIMESTAMP>",
  "composite_score": <int>,
  "composite_grade": "<letter>",
  "dimensions": {
    "<slug>": { "score": <int>, "weight": <int>, "source": "<enum>", "source_plugin": "<name or null>" }
  }
}
```

This is the state `/pronto:status` reads and `/pronto:improve` consumes.

## Error handling

- Any single sibling invocation or parser returning invalid JSON → log to `sibling_integration_notes`, degrade that dimension to its presence check, continue.
- `.pronto/` directory not writable → note in `sibling_integration_notes`, still emit the scorecard.
- Rubric or recommendations file missing → abort with a clear error; these are critical to the orchestration. Suggest `/pronto:init` if the plugin install is damaged.
- Kernel-check itself failing → use all-zeros for kernel scores, note in `sibling_integration_notes`, proceed.

## Performance budget

Target: full audit completes in under 5 seconds on a repo with `claudit`, `skillet`, `commventional` installed and the kernel populated. This is achievable because:

- Kernel-check is pure filesystem (<1s).
- Parsers read files directly (not shelling to the sibling's full interactive audit) — each parser ≤2s.
- Dimension orchestration is parallel where safe (parsers don't contend).

If a parser exceeds 10 seconds, degrade to presence and log a note.

## Notes

- **Do not shell to interactive sibling commands.** `/claudit` is a multi-phase interactive skill; running it inside `/pronto:audit` would disrupt the user. Parsers read repo state directly and emit contract JSON. This is the Phase 1 reality — Phase 2+ siblings will ship `--json` flags and this skill will prefer those.
- **Do not write outside `.pronto/state.json`.** The orchestrator is read-mostly. Any fix-applying behavior belongs to `/pronto:improve`.
- **Respect `sibling_integration_notes`.** Surface partial failures visibly — the consumer should never wonder why a dimension got a degraded score.
