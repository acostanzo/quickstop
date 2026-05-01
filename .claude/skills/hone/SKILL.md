---
name: hone
description: Audit and improve an existing Quickstop plugin's quality against Claude Code plugin spec
disable-model-invocation: true
argument-hint: plugin-name
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, WebSearch, WebFetch, AskUserQuestion
---

# Hone: Plugin Quality Auditor

You are the Hone orchestrator. When the user runs `/hone <plugin-name>`, execute this 5-phase audit workflow. Follow each phase in order. Do not skip phases.

## Phase 0: Discovery

### Step 1: Parse Plugin Name

Extract the plugin name from `$ARGUMENTS`. If empty or missing, list available plugins by globbing `plugins/*/` and use AskUserQuestion to ask which to audit.

### Step 2: Validate Plugin Exists

Glob for `plugins/$ARGUMENTS/.claude-plugin/plugin.json`. If not found, tell the user the plugin doesn't exist and abort.

### Step 3: Build Plugin Manifest

Run parallel Glob calls to discover all files under `plugins/<name>/`:

| Category | Glob Pattern |
|----------|-------------|
| Metadata | `plugins/<name>/.claude-plugin/*.json` |
| Skills | `plugins/<name>/skills/*/SKILL.md` |
| Skill references | `plugins/<name>/skills/*/references/*.md` |
| Agents | `plugins/<name>/agents/*.md` |
| Hooks | `plugins/<name>/hooks/*.json` |
| MCP | `plugins/<name>/.mcp.json` |
| Docs | `plugins/<name>/README.md` |
| Legacy | `plugins/<name>/commands/*.md` |
| All files | `plugins/<name>/**/*` |

Get line counts for all discovered files via a single Bash call: `wc -l <file1> <file2> ...`

### Step 4: Present Plugin Map

```
=== PLUGIN MAP ===
Plugin: <name> v<version>

Skills (N):
  skills/<skill>/SKILL.md              XX lines
  skills/<skill>/references/foo.md     XX lines
Agents (N):
  agents/<agent>.md                    XX lines
Hooks:
  hooks/hooks.json                     XX lines
Metadata:
  .claude-plugin/plugin.json           XX lines
  README.md                            XX lines
Legacy:
  [commands/ if found]

Total: N files, ~N lines
=== END MAP ===
```

Tell the user:
```
Phase 1: Building expert context from official plugin documentation...
```

---

## Phase 1: Build Expert Context

### Step 1: Load Expert Context

Invoke `/claudit:knowledge ecosystem` to retrieve ecosystem knowledge.

**If the skill runs successfully** (outputs `=== CLAUDIT KNOWLEDGE: ecosystem ===` block):
- Use its output as the ecosystem portion of Expert Context
- Also read `.claude/skills/smith/references/plugin-spec.md` for plugin-authoring-specific detail (plugin.json schema, directory conventions) that the ecosystem cache may not cover at full depth
- Combine both as **Expert Context**
- **Skip to Phase 2**

**If the skill is not available** (claudit not installed — the invocation produces an error, is not recognized as a command, or produces no knowledge output):
- Proceed to Step 2

### Step 2: Dispatch Research Agents (Fallback)

Dispatch **2 research subagents in parallel** using the Task tool. Both must be foreground.

In a single message, dispatch both Task tool calls:

**Research Plugin Spec:**
- `description`: "Research plugin spec docs"
- `subagent_type`: "research-plugin-spec"
- `prompt`: "Build expert knowledge on Claude Code plugin, skill, and sub-agent authoring. Read the baseline from .claude/skills/smith/references/plugin-spec.md first, then fetch official Anthropic documentation. Return structured expert knowledge."

**Research Hooks & MCP:**
- `description`: "Research hooks/MCP docs"
- `subagent_type`: "research-hooks-mcp"
- `prompt`: "Build expert knowledge on Claude Code hooks and MCP server configuration. Fetch official Anthropic documentation. Return structured expert knowledge."

### Assemble Expert Context

Once both return, combine results:

```
=== EXPERT CONTEXT ===

## Plugin System Knowledge
[Results from research-plugin-spec]

## Hooks & MCP Knowledge
[Results from research-hooks-mcp]

=== END EXPERT CONTEXT ===
```

Tell the user:
```
Expert context assembled. Dispatching audit agents...

Phase 2: Analyzing plugin against expert knowledge...
```

---

## Phase 2: Audit

### Step 1: Sibling Detection

Before dispatching any audit agents, determine whether the plugin is a pronto sibling. Either of the following paths marks it as a sibling:

**Path 1 — contract-native:** Read `plugins/<name>/.claude-plugin/plugin.json`. Check whether a `pronto` key exists at the top level.

**Path 2 — registry:** Read `plugins/pronto/references/recommendations.json`. Check whether `<name>` appears as a `recommended_plugin` value for any dimension entry.

Record which path(s) matched: `pronto-block`, `registry-only`, `both`, or `none`.

### Step 2: Build Agent Prompts

Read all plugin files before dispatching. Each agent needs:
1. The full Expert Context from Phase 1
2. Its specific file contents (read and include them in the prompt)

### Step 3: Dispatch Audit Agents

**Non-sibling (detection = none):** dispatch 5 agents in parallel — the existing 4 plus `audit-boundary`.

**Sibling (detection = pronto-block / registry-only / both):** dispatch 6 agents in parallel — the existing 4 plus `audit-boundary` plus `audit-pronto`.

Dispatch all applicable agents simultaneously in a single message.

**audit-structure:**
- `description`: "Audit plugin structure"
- `subagent_type`: "audit-structure"
- `prompt`: Include Expert Context + the full plugin manifest with paths and line counts. The agent checks directory layout, required files, naming conventions.

**audit-skills-agents:**
- `description`: "Audit skills and agents"
- `subagent_type`: "audit-skills-agents"
- `prompt`: Include Expert Context + full contents of all SKILL.md and agent .md files. The agent validates frontmatter, instruction quality, and cross-references.

**audit-metadata-docs:**
- `description`: "Audit metadata and docs"
- `subagent_type`: "audit-metadata-docs"
- `prompt`: Include Expert Context + contents of plugin.json, marketplace.json entry, plugin README.md, and root README.md entry. Also include the plugin directory path for the security scan. The agent checks version consistency, docs quality, and secrets.

**audit-design:**
- `description`: "Audit design quality"
- `subagent_type`: "audit-design"
- `prompt`: Include Expert Context + contents of all plugin files (skills, agents, hooks). The agent assesses over-engineering, hook quality, and design patterns.

**audit-boundary (always):**
- `description`: "Audit ADR-006 boundary compliance"
- `subagent_type`: "audit-boundary"
- `prompt`: Include Expert Context + plugin name and root path (`plugins/<name>/`). The agent audits §1 surface declaration, §2 silent consumer-artefact mutation, §3 hook invariants, and manifest/script drift.

**audit-pronto (sibling only):**
- `description`: "Audit pronto sibling compliance"
- `subagent_type`: "audit-pronto"
- `prompt`: Include Expert Context + plugin name + `detection: <pronto-block|registry-only|both>`. The agent audits pronto block, `:audit` skill, wire contract emission, parser agent state, and version handshake hygiene.

---

## Phase 3: Scoring

Once all audit agents return, read the scoring rubric:
- Read `${SKILL_ROOT}/references/scoring-rubric.md`

### Score Each Category

Apply the rubric to audit findings. For each applicable category:

1. Start at base score of **100**
2. Apply matching **deductions** from the rubric
3. Apply matching **bonuses** from the rubric
4. Clamp to 0-100 range

**Categories, shares, and audit sources:**

| Category | Share | Audit Source |
|----------|-------|-------------|
| Skill Quality | 20 | audit-skills-agents |
| Structure Compliance | 15 | audit-structure |
| Agent Quality | 15 | audit-skills-agents |
| Metadata Quality | 10 | audit-metadata-docs |
| Hook Quality | 10 | audit-design + audit-boundary |
| Documentation | 10 | audit-metadata-docs + audit-boundary |
| Over-Engineering | 10 | audit-design |
| Security | 10 | audit-metadata-docs + audit-boundary |
| Pronto Compliance | 10 | audit-pronto (sibling plugins only) |

**Scope-aware scoring:** If a plugin has no component for a category (e.g., no hooks), that category scores 100 (neutral) unless the plugin clearly needs it. Pronto Compliance is excluded entirely for non-sibling plugins — it does not score 100 neutral.

### Compute Overall Score

```
total_share = sum(share_i for all applicable categories)
effective_weight_i = share_i / total_share
overall = sum(category_score_i * effective_weight_i for all applicable categories)
```

Applicable categories:
- **Non-sibling:** the original 8 categories, total_share = 100. Effective weights equal shares/100 — byte-equivalent to the pre-Q2 formula.
- **Sibling:** all 9 categories including Pronto Compliance, total_share = 110. Each effective weight = share/110 (~9% less than original, with Pronto Compliance filling the slack).

Look up letter grade from rubric's grade threshold table.

### Build Recommendations

Compile ranked recommendations from all audit findings (including boundary and pronto findings):

1. **Critical** (> 20 point impact): Must fix — actively harming quality
2. **High** (10-20 point impact): Should fix — significant improvement
3. **Medium** (5-9 point impact): Nice to have — incremental improvement
4. **Low** (< 5 point impact): Optional — minor polish

### Present the Quality Report

```
╔══════════════════════════════════════════════════════════╗
║                    HONE QUALITY REPORT                   ║
║  Plugin: <name> v<version>  | Overall: XX/100  Grade: X  ║
╚══════════════════════════════════════════════════════════╝

Skill Quality        ████████████████████░░░░░  XX/100  X
Structure Compliance ████████████████████░░░░░  XX/100  X
Agent Quality        ████████████████████░░░░░  XX/100  X
Metadata Quality     ████████████████████░░░░░  XX/100  X
Hook Quality         ████████████████████░░░░░  XX/100  X
Documentation        ████████████████████░░░░░  XX/100  X
Over-Engineering     ████████████████████░░░░░  XX/100  X
Security             ████████████████████░░░░░  XX/100  X
[Pronto Compliance   ████████████████████░░░░░  XX/100  X]  ← sibling plugins only
```

For visual bars: `█` for filled (score/100 * 25 chars), `░` for remaining. Append numeric score and letter grade. Show 8 bars for non-sibling plugins; append the Pronto Compliance bar (9th) for sibling plugins.

After the scorecard, present:
1. **Critical Issues** — anything scoring below 50
2. **Top Recommendations** — ranked list with estimated point impact
3. **Patterns to Adopt** — best practices from Expert Context not currently used

---

## Phase 4: Interactive Enhancement

### Present Recommendations for Selection

Use AskUserQuestion with `multiSelect: true` to let the user choose which recommendations to apply. Group by priority (Critical, High, Medium, Low). Include estimated score impact.

Format each option as:
- Label: Short description
- Include estimated point impact (e.g., "+15 pts Skill Quality")

Include a "Skip — no changes" option.

### Implement Selected Fixes

For each selected recommendation:

1. Read the target file
2. Apply the fix using Edit (preferred) or Write
3. Briefly explain what changed and the expected score impact

Common fix types:
- **Frontmatter fixes**: Add missing fields, fix mismatches
- **Version sync**: Align versions across plugin.json, marketplace.json, README
- **Structure cleanup**: Move files to correct directories, remove legacy patterns
- **Instruction improvements**: Add phase structure, output formats, error handling
- **Documentation**: Add missing README sections, add "Plugin surface" section (ADR-006 §1)
- **Security**: Remove hardcoded paths, scope tool lists

**ADR-006 boundary findings (from audit-boundary):**
- §1 missing README "Plugin surface" section — add the section listing declared capabilities.
- §2 Scope A consumer-artefact mutation — surface the finding; do not auto-apply. These are architectural decisions requiring the plugin author's deliberate migration (ref. relevant per-plugin migration ticket if one exists).
- §3 hook invariant violations — surface Critical findings clearly. For §3.1 payload mutation fields, flag the exact jq template or field construction. For §3.2 persistent host state, flag the installation call. Auto-apply is out of scope; recommend the author follow the migration ticket.

**Pronto Compliance findings (from audit-pronto, sibling plugins only):**
- Missing fields in `plugin.json` pronto block (e.g. `compatible_pronto`) — apply the field addition directly (low-risk, non-destructive edit).
- Missing `skills/audit/SKILL.md` or frontmatter issues — surface the finding; recommend `/smith --upgrade <plugin>` for scaffolding-shaped work (future enhancement); do not auto-generate the skill body.
- Registry-only detection finding ("migrate to contract-native shape") — surface as High recommendation; do not auto-apply.

### Re-Score and Show Delta

After implementing fixes, re-score affected categories and show before/after:

```
Score Delta:
  Skill Quality        65 → 85  (+20)
  Metadata Quality     70 → 95  (+25)
  Overall              72 → 84  (+12)  Grade: C → B
```

---

## Phase 5: PR Delivery

Check if any files were modified in Phase 4. If no changes were made, skip this phase.

### Offer PR Option

Use AskUserQuestion (single-select):
- **"Open a PR"** — branch, commit, push, PR with review comments
- **"Keep as local edits"** — leave changes uncommitted

### Check Prerequisites

1. `command -v gh` — verify gh CLI available
2. `gh auth status` — verify authenticated
3. If either fails, fall back to "Keep as local edits"

### Create the PR

If PR delivery is selected:

1. **Record current branch**: `CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)`
2. **Create branch**: `git checkout -b hone/<plugin>-improvements-$(date +%Y-%m-%d-%H%M)`
3. **Stage changed files**: Only files under `plugins/<name>/`, `.claude-plugin/marketplace.json`, and `README.md`
4. **Commit**:
   ```
   <Plugin> v<version>: hone quality improvements (score XX → YY)

   - [List key changes]
   ```
5. **Push**: `git push -u origin <branch-name>`
6. **Create PR** via `gh pr create --base $CURRENT_BRANCH`:
   - Title: `<Plugin> v<version>: hone quality improvements`
   - Body: Summary with score delta, list of changes
7. **Add inline review comments** via `gh api` for each changed file (educational comments explaining what changed and why)
8. Return the PR URL

### Fallback

If gh is not available or PR creation fails, show `git diff --stat` and explain what was changed.

---

## Error Handling

- If a research agent fails, continue with local baseline from `.claude/skills/smith/references/plugin-spec.md`
- If an audit agent fails, score its categories as "N/A — audit failed" and note the gap
- If a plugin has no skills, flag it as a critical issue but continue auditing other components
- If score is 90+, congratulate and suggest advanced patterns from Expert Context
- If the user selects "Skip" in Phase 4, skip directly to summary (no Phase 5)

## Important Notes

- **Never auto-apply changes** — always present recommendations and let the user choose
- **Quote specific lines** when showing what would change
- **Be opinionated** about over-engineering — this is a core value of the tool
- **Show point impact** for every recommendation
- **Expert Context makes this unique** — highlight spec compliance gaps the user may not know about
