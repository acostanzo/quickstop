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
4. **PRONTO_VERSION**: `jq -r '.version' "${PLUGIN_ROOT}/.claude-plugin/plugin.json"` — pronto's running version, used for the ADR-004 §2 sibling handshake in Phase 4.

## Phase 1: Load registries

1. **Rubric**: Read `${PLUGIN_ROOT}/references/rubric.md` — used for weights, presence-check definitions, letter-grade bands.
2. **Recommendations**: Read `${PLUGIN_ROOT}/references/recommendations.json` — used to map each dimension to its recommended sibling plugin and install command.
3. **Report format**: Read `${PLUGIN_ROOT}/references/report-format.md` — used for the output shape.

## Phase 2: Discover installed siblings

Determine which sibling plugins are available. Check in this order:

1. **Repo-local plugins**: Read `${REPO_ROOT}/.claude-plugin/marketplace.json` if present — lists plugins available in the current marketplace (e.g., quickstop itself).
2. **Installed plugins**: Read `~/.claude/plugins/installed_plugins.json` if present — lists globally installed plugins.
3. **Plugin.json declarations**: For each installed plugin, read its `plugin.json`. If it carries a `pronto.audits` block, record the dimension → command mapping for native emission. Also read `pronto.compatible_pronto` (the optional ADR-004 §2 version range); treat absent as the empty string.

Store the discovery result as **INSTALLED_SIBLINGS** — a map from plugin name to `{ version, compatible_pronto, native_declarations, plugin_root }`.

## Phase 2.5: Expert context is out of scope by design

**The audit does not dispatch `/claudit:knowledge`.** Expert ecosystem context is not part of the audit path.

Pronto's audit scope is deterministic scoring — kernel presence, sibling wire-contract scores, and per-dimension rubric evaluation. `/claudit:knowledge` emits narrative research output, not structured scores; folding it into the audit contributed to non-deterministic composites. It was removed from the audit flow deliberately.

Users who want expert ecosystem context invoke `/claudit:knowledge ecosystem` directly. That skill is first-class user-facing surface, not a pronto dependency. Its absence is not a degradation — do not surface it in `sibling_integration_notes`, and do not treat it as a missing capability anywhere in the report.

Parsers receive only the dispatch brief defined in Phase 4.1. There is no EXPERT_CONTEXT payload.

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
2. **Version handshake** (per ADR-004 §2): if the recommended plugin is in INSTALLED_SIBLINGS, gate dispatch on its `compatible_pronto` declaration. Invoke:

   ```bash
   "${PLUGIN_ROOT}/skills/audit/compatible-pronto-check.sh" \
       "${PRONTO_VERSION}" \
       "${INSTALLED_SIBLINGS[<plugin>].compatible_pronto}"
   ```

   Parse the helper's JSON output and branch on `.branch`:
   - `in_range` → continue to step 3 (dispatch normally), no note.
   - `unset` → continue to step 3 (dispatch normally) AND append a soft note to `sibling_integration_notes`: `"<plugin> does not declare compatible_pronto; dispatching at sibling's risk per ADR-004 §2."`
   - `out_of_range` → **skip dispatch entirely**, fall through to step 4 (presence fallback) for this dimension, AND append a hard note to `sibling_integration_notes` of the form: `"<plugin> <version> declares compatible_pronto '<range>' but this pronto is <PRONTO_VERSION>. Sibling audit skipped; upgrade <plugin> to re-enable depth scoring."` Take `<version>` and `<range>` from `INSTALLED_SIBLINGS[<plugin>]`. The fallback's source stays `kernel-presence-cap` / `presence-fail` per the existing report-format contract; consumers correlate the skipped sibling via this entry plus the per-dimension `notes` template in step 4.

   If the recommended plugin is NOT in INSTALLED_SIBLINGS, skip the handshake (no sibling means no declaration to check) and fall through to step 4 directly.

3. **Sibling dispatch** (only when handshake says `in_range` or `unset`):
   - If the plugin declares the dimension natively in its `plugin.json` `pronto.audits` block → invoke the declared command with `--json`, capture stdout, parse as JSON. Validate against the contract. Source: `sibling`. Score: `composite_score`.
   - Else if a `parser_agent` is registered for this dimension (e.g., `parsers/claudit`, `parsers/skillet`, `parsers/commventional`) → dispatch the parser as a subagent (see Phase 4.1 below). Source: `sibling` (the parser *is* the sibling's audit in Phase 1). Score: parser's `composite_score`.
   - Else → fall through to presence check.
4. **Presence fallback** (sibling not installed, handshake forced skip, OR no parser registered):
   - For `claude-code-config` and `code-documentation`, use the existing
     kernel-check category score directly: `KERNEL_CATEGORY_SCORES[".claude/ presence"]`
     and `KERNEL_CATEGORY_SCORES["README"]` respectively. No additional Bash needed.
   - For `skills-quality`, `commit-hygiene`, `lint-posture`, and
     `event-emission`, invoke the deterministic presence check via Bash:

     ```bash
     "${CLAUDE_PLUGIN_ROOT}/skills/audit/presence-check.sh" <dimension> "${REPO_ROOT}"
     ```

     Where `<dimension>` is the slug literally (e.g. `event-emission`).
     The script prints `100` on pass, `0` on fail — and nothing else.
     Do **not** compose your own grep, find, or git invocation here;
     the script exists precisely so the orchestrator never reinvents
     the check (Phase 1.5 PR 3b: composing the grep with different
     `--exclude-dir` sets across runs was the largest pre-mechanization
     variance source).
   - If presence passes (`100`) → score 50, source `kernel-presence-cap`.
   - If presence fails (`0`) → score 0, source `presence-fail`.
   - The per-dimension `notes` field must reflect *why* the fallback ran, not a generic stub:
     - Sibling not installed (and no parser): `"<plugin> not installed; presence check passed; capped at 50"` (or `"...presence check failed; score 0"`).
     - Handshake forced skip (`out_of_range`): `"<plugin> <version> installed but compatible_pronto excludes pronto <PRONTO_VERSION>; sibling audit skipped; presence-only."` Otherwise the row contradicts the hard note in `sibling_integration_notes`.

### Phase 4.1: Parser dispatch

When dispatching a parser agent, use the Task tool with these fields:

- `subagent_type`: `pronto:parsers:parse-claudit`, `pronto:parsers:parse-skillet`, or `pronto:parsers:parse-commventional`. Claude Code namespaces agents by plugin **and** subdirectory, so the `agents/parsers/` subdirectory becomes a `parsers:` segment in the registered name. The agent's `name:` frontmatter (`parse-claudit` etc.) is the final segment. Verify against the stream-json init event's `agents` array if in doubt.
- `description`: `Parse <sibling> audit`.
- `prompt`: **minimal**. The parser agents are deterministic shell-script wrappers (Phase 1.5 PR 3b mechanization) — they read `REPO_ROOT` from the prompt and execute `${CLAUDE_PLUGIN_ROOT}/agents/parsers/scorers/score-<sibling>.sh` to produce the contract JSON. Send exactly: `REPO_ROOT=<absolute path>. Run the deterministic scorer and emit its stdout verbatim.` Do not paste rubric prose, scoring guidance, or restate the contract — extra context invites the parser to interpret instead of execute, which reintroduces the variance the mechanization removed.

Parsers run foreground because their output feeds the next phase directly. Validate the parser's return: must be valid JSON, must have `plugin`, `dimension`, `composite_score`, `categories[]`. On invalid return, degrade to the presence fallback and append a note to `sibling_integration_notes`.

## Phase 5: Aggregate

For each dimension in the rubric:

- `weight` from the rubric row.
- `score` from Phase 4.
- `weighted_contribution = round(weight * score / 100, 1)`.

Compute `composite_score = round(sum(weighted_contribution))`. Clamp to 0–100.

**Compute the math via Bash + jq, not in your head.** Even simple weighted sums are an LLM determinism hazard — a half-up vs half-even rounding choice in one run vs another contributes 1pt of composite stddev for free. Write the per-dimension `{weight, score}` pairs to a temp file and aggregate with one `jq` expression, e.g.:

```bash
jq -n --argjson dims "$DIMS_JSON" '
    ($dims | map(.weight * .score / 100)) as $contribs
    | { weighted_contributions: ($contribs | map(. * 10 | round / 10)),
        composite_score:        ($contribs | add | round) }'
```

Use the returned `composite_score` directly in Phase 6's emission. Do not re-add the rounded `weighted_contributions` in your head — `round(sum(x))` and `sum(round(x))` differ.

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
- **`sibling_integration_notes` is a warnings array, not a success log.**
  - Empty `[]` is the steady state when every sibling dispatched and every parser returned valid JSON.
  - Populate for real degradations: parser returned invalid JSON, sibling timed out, kernel-check failed, `.pronto/` wasn't writable, validation warnings.
  - **Never frame intentional omissions as degradation.** `/claudit:knowledge` is out of audit scope by design (Phase 2.5); do not emit a note about it. Its absence is not a sibling integration issue.
  - When a successful sibling dispatch is worth surfacing for clarity, use direct language: `"avanti: dispatched via Skill tool, composite <N> (<grade>)"`. Never write `"invoked inline"`, `"executed scoring logic inline"`, or `"skipped to avoid nested skill invocation"` — those phrasings describe failure modes that no longer exist in this spec.
