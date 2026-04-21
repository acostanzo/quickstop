---
name: kernel-check
description: Run pronto's kernel presence checks — non-delegable filesystem checks (AGENTS.md, project/, .pronto/, README, LICENSE, .gitignore, .claude/)
disable-model-invocation: true
argument-hint: "[--json]"
allowed-tools: Read, Glob, Bash
---

# Pronto: Kernel Presence Check

You are the pronto kernel auditor. Your job is **purely filesystem existence checks** — no depth analysis, no semantic reasoning. For every kernel concern, answer a single binary question: does the artifact exist at the expected path with non-empty content?

The output follows the sibling-audit wire contract (see `${CLAUDE_PLUGIN_ROOT}/references/sibling-audit-contract.md`) with `plugin: "pronto-kernel"`. The audit orchestrator (`/pronto:audit`) consumes this output and maps individual categories onto rubric dimensions when no sibling is installed.

## Arguments

Parse `$ARGUMENTS`:
- If `$ARGUMENTS` contains `--json` → set **OUTPUT_MODE = "json"**.
- Otherwise → set **OUTPUT_MODE = "markdown"**.

## Phase 0: Resolve repo root

Run via Bash: `git rev-parse --show-toplevel 2>/dev/null`

- If this succeeds → store as **REPO_ROOT**.
- If this fails → the kernel-check must still run. Set **REPO_ROOT** to the current working directory and note "not a git repo" in the findings. A non-git directory scores all checks as fail (presence implies a committable repo).

## Phase 1: Scan

Perform these checks in a single batch. Use parallel Bash calls where possible.

| Check | Pass condition | How to measure |
|---|---|---|
| `AGENTS.md scaffold` | `${REPO_ROOT}/AGENTS.md` exists AND >=5 non-blank lines | `wc -l` via Bash; Read to confirm non-blank |
| `Project record container` | `${REPO_ROOT}/project/` exists AND contains `plans/`, `tickets/`, `adrs/`, `pulse/` subdirs | `test -d` per subdir via Bash |
| `Tool-state (.pronto/)` | `${REPO_ROOT}/.pronto/` exists AND contains a `state.json` file | `test -f` via Bash |
| `.claude/ presence` | `${REPO_ROOT}/.claude/` exists AND is a directory | `test -d` via Bash |
| `README` | `${REPO_ROOT}/README.md` OR `${REPO_ROOT}/README` OR `${REPO_ROOT}/README.rst` exists AND >=10 non-blank lines | `wc -l` via Bash |
| `LICENSE` | `${REPO_ROOT}/LICENSE` OR `${REPO_ROOT}/LICENSE.md` OR `${REPO_ROOT}/LICENSE.txt` OR `${REPO_ROOT}/COPYING` exists AND >=1 non-blank line | `wc -l` via Bash |
| `.gitignore` | `${REPO_ROOT}/.gitignore` exists AND >=1 non-blank line | `wc -l` via Bash |

Each check produces a boolean `passed` plus a one-line human-readable finding.

**Batch strategy:** issue one combined Bash command that exits 0 and prints the structured result for each check. Example shape:

```bash
# Use test exit codes, print structured lines.
# Loop variable must NOT be `path`, `manpath`, `cdpath`, or `fpath` — zsh ties
# those names to PATH/MANPATH/CDPATH/FPATH, and assigning to them inside a loop
# clobbers PATH and breaks external commands like `wc`. Use `f` / `d` instead.
for f in AGENTS.md README.md README README.rst LICENSE LICENSE.md LICENSE.txt COPYING .gitignore; do
  if [ -e "${REPO_ROOT}/${f}" ]; then
    echo "EXISTS:${f}:$(wc -l < "${REPO_ROOT}/${f}" 2>/dev/null || echo 0)"
  else
    echo "MISSING:${f}"
  fi
done
for d in .claude .pronto project project/plans project/tickets project/adrs project/pulse; do
  if [ -d "${REPO_ROOT}/${d}" ]; then
    echo "DIR_EXISTS:${d}"
  else
    echo "DIR_MISSING:${d}"
  fi
done
if [ -f "${REPO_ROOT}/.pronto/state.json" ]; then echo "STATE_JSON:present"; else echo "STATE_JSON:missing"; fi
```

Parse the output, one line per check, to populate the check table.

## Phase 2: Score

Each category gets a binary 0 or 100 score based on the pass condition.

| Category name (contract `name`) | Weight |
|---|---|
| `AGENTS.md scaffold` | 0.20 |
| `Project record container` | 0.20 |
| `Tool-state (.pronto/)` | 0.05 |
| `.claude/ presence` | 0.15 |
| `README` | 0.15 |
| `LICENSE` | 0.10 |
| `.gitignore` | 0.15 |

Weights sum to 1.00. These are **internal kernel weights** for the kernel's composite — the orchestrator (`/pronto:audit`) discards this composite in favor of extracting per-category scores and applying rubric-level weights from `references/rubric.md`.

Compute `composite_score = round(sum(weight * score for each category))`.

Derive `letter_grade` per the bands in `${CLAUDE_PLUGIN_ROOT}/references/rubric.md`:

| Grade | Score range |
|---|---|
| A+ | 95-100 |
| A | 90-94 |
| B | 75-89 |
| C | 60-74 |
| D | 40-59 |
| F | 0-39 |

## Phase 3: Build findings + recommendations

For every **failed** check, emit one finding:

```json
{
  "severity": "medium",
  "message": "AGENTS.md missing at repo root",
  "file": "AGENTS.md"
}
```

Severity mapping for failed kernel checks:

| Category | Severity when failed |
|---|---|
| `AGENTS.md scaffold` | medium — kernel scaffolds on `/pronto:init` |
| `Project record container` | medium — kernel scaffolds on `/pronto:init` |
| `Tool-state (.pronto/)` | low — created lazily on first audit |
| `.claude/ presence` | high — no Claude Code config at all |
| `README` | high — no project entry point |
| `LICENSE` | medium — legal/distribution hygiene |
| `.gitignore` | low — housekeeping |

For every failed check, emit one recommendation:

```json
{
  "priority": "high|medium|low",
  "category": "<slug>",
  "title": "Scaffold <artifact>",
  "impact_points": null,
  "command": "/pronto:init"
}
```

All kernel failures share the `/pronto:init` recommendation — it's the single entry point for kernel scaffolding.

## Phase 4: Emit

### If OUTPUT_MODE == "json"

Write **exactly one JSON object** to stdout. No markdown fences, no prefix text, no trailing whitespace. The object must validate against `${CLAUDE_PLUGIN_ROOT}/references/sibling-audit-contract.md`:

```json
{
  "plugin": "pronto-kernel",
  "dimension": "kernel",
  "categories": [...],
  "composite_score": 71,
  "letter_grade": "C",
  "recommendations": [...]
}
```

Any progress or error output goes to stderr (use Bash `>&2` redirection).

### If OUTPUT_MODE == "markdown"

Present the standard kernel scorecard:

```
=== PRONTO KERNEL CHECK ===
Repo: <REPO_ROOT>
Composite: XX/100  Grade: X

  ✓  AGENTS.md scaffold               present (N lines)
  ✓  Project record container         present (plans/ tickets/ adrs/ pulse/)
  ✗  Tool-state (.pronto/)            missing
  ✓  .claude/ presence                present
  ✓  README                           present (N lines)
  ✓  LICENSE                          present
  ✗  .gitignore                       missing

Recommendations:
  [low]  Scaffold .pronto/ tool-state     → /pronto:init
  [low]  Scaffold .gitignore              → /pronto:init
=== END ===
```

Use `✓` for passed checks, `✗` for failed.

## Error handling

- Repo root resolution fails → treat as "not a git repo", score all checks as fail, emit a single finding explaining the state.
- A single check's Bash call fails → mark that check as failed with severity `medium` and proceed. Never traceback.
- File read to count non-blank lines fails → fall back to raw line count via `wc -l`; if that also fails, treat as file missing.

## Notes for the orchestrator

The orchestrator (`/pronto:audit`) consumes this skill's JSON output to fill in presence-check fallback scores for kernel-covered rubric dimensions. The category → rubric-dimension mapping is:

| Kernel category | Rubric dimension (fallback driver) |
|---|---|
| `AGENTS.md scaffold` | `agents-md` |
| `Project record container` | `project-record` |
| `.claude/ presence` | `claude-code-config` |
| `README` | `code-documentation` |

`Tool-state (.pronto/)`, `LICENSE`, and `.gitignore` do not map to rubric dimensions; they surface as kernel-health recommendations only.

The orchestrator is responsible for applying the presence cap (50) when using kernel scores as dimension fallbacks.
