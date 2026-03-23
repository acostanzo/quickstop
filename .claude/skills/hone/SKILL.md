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

### Step 1: Check Claudit Knowledge Cache

Check if claudit's cached ecosystem research is available and fresh:

1. Run via Bash: `claude --version 2>/dev/null` → store as **CURRENT_VERSION**
2. Run via Bash: `cat ~/.cache/claudit/manifest.json 2>/dev/null`
3. If the manifest exists, apply invalidation:
   a. **Version check**: manifest's `claude_code_version` must match CURRENT_VERSION
   b. **Time check**: manifest's `cached_at` age must be < `max_ttl_days` (7 days)
   c. **File check**: `~/.cache/claudit/ecosystem.md` must exist
4. All three must pass → **FRESH**

**If FRESH:**
- Read `~/.cache/claudit/ecosystem.md`
- Use the plugins, skills, sub-agents, hooks, and MCP sections as **Expert Context**
- Tell the user: `Expert context loaded from claudit cache (fetched {date}). Dispatching audit agents...`
- **Skip to Phase 2**

**If STALE or MISSING:**
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

Dispatch **4 audit agents in parallel** using the Task tool. Each receives Expert Context plus its relevant file slice.

### Build Agent Prompts

Read all plugin files before dispatching. Each agent needs:
1. The full Expert Context from Phase 1
2. Its specific file contents (read and include them in the prompt)

### Dispatch All Four Simultaneously

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

---

## Phase 3: Scoring

Once all 4 audit agents return, read the scoring rubric:
- Read `${SKILL_ROOT}/references/scoring-rubric.md`

### Score Each Category

Apply the rubric to audit findings. For each of the 8 categories:

1. Start at base score of **100**
2. Apply matching **deductions** from the rubric
3. Apply matching **bonuses** from the rubric
4. Clamp to 0-100 range

**Categories, weights, and audit sources:**

| Category | Weight | Audit Source |
|----------|--------|-------------|
| Skill Quality | 20% | audit-skills-agents |
| Structure Compliance | 15% | audit-structure |
| Agent Quality | 15% | audit-skills-agents |
| Metadata Quality | 10% | audit-metadata-docs |
| Hook Quality | 10% | audit-design |
| Documentation | 10% | audit-metadata-docs |
| Over-Engineering | 10% | audit-design |
| Security | 10% | audit-metadata-docs |

**Scope-aware scoring:** If a plugin has no component for a category (e.g., no hooks), that category scores 100 (neutral) unless the plugin clearly needs it.

### Compute Overall Score

```
overall = sum(category_score * category_weight for all categories)
```

Look up letter grade from rubric's grade threshold table.

### Build Recommendations

Compile ranked recommendations from all audit findings:

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
```

For visual bars: `█` for filled (score/100 * 25 chars), `░` for remaining. Append numeric score and letter grade.

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
- **Documentation**: Add missing README sections
- **Security**: Remove hardcoded paths, scope tool lists

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
