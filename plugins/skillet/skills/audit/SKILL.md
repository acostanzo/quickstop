---
name: audit
description: Audit an existing Claude Code skill's quality with research-first analysis and 6-category scoring
disable-model-invocation: true
argument-hint: skill-path
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion
---

# Skillet: Audit a Skill

You are the Skillet audit orchestrator. When the user runs `/skillet:audit`, execute this 4-phase workflow to assess and optionally improve a skill's quality. Follow each phase in order. Do not skip phases.

## Phase 0: Discovery

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for the skill path or name.

Supported formats:
- Full path: `.claude/skills/my-skill` or `plugins/my-plugin/skills/my-skill`
- Skill name only: `my-skill` (search for it)

If `$ARGUMENTS` is empty, use AskUserQuestion: "Which skill should I audit? Provide a path or name."

### Step 2: Locate the Skill

If a full path was given, verify it exists. If only a name was given, search for it:

1. Glob for `.claude/skills/$NAME/SKILL.md`
2. Glob for `plugins/*/skills/$NAME/SKILL.md`
3. If multiple matches, ask the user which one

If not found, report the error and stop.

### Step 3: Determine Parent Context

Based on the skill's location, determine:
- **Parent type**: project skill (`.claude/`) or plugin skill (`plugins/<name>/`)
- **Parent root**: the directory containing `agents/`, `hooks/`, etc.
- **Plugin metadata**: if plugin, read `.claude-plugin/plugin.json`

### Step 4: Build Skill Manifest

Discover all files related to this skill:

1. **SKILL.md**: Read it and extract frontmatter
2. **References**: Glob for `<skill-dir>/references/*.md`
3. **Agents**: Parse SKILL.md for `subagent_type` references, then Glob for `<parent>/agents/*.md`
4. **Hooks**: Check for `<parent>/hooks/hooks.json`
5. **Scripts**: Check for any scripts referenced in hooks

For each file, get its line count via `wc -l` (batch in a single Bash call).

Present the manifest:

```
=== SKILL MANIFEST ===
Skill: <name>
Location: <path>
Parent: <project or plugin name>

Files:
  SKILL.md                           XX lines
  references/scoring-rubric.md       XX lines
  ../agents/research-agent.md        XX lines
  ../hooks/hooks.json                XX lines

Total: N files, ~N lines
=== END MANIFEST ===
```

Tell the user:

```
Phase 1: Building expert context from official Anthropic documentation...
```

---

## Phase 1: Research

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
- Use the hooks, skills, and sub-agents sections as **Expert Context**
- Tell the user: `Expert context loaded from claudit cache (fetched {date}). Dispatching audit agent...`
- **Skip to Phase 2**

**If STALE or MISSING:**
- Proceed to Step 2

### Step 2: Dispatch Research Agent (Fallback)

Use the Task tool:
- `description`: "Research skill spec docs"
- `subagent_type`: "skillet:research-skill-spec"
- `prompt`: "Build expert knowledge on Claude Code skill, agent, and hook authoring. Read the baseline from ${CLAUDE_PLUGIN_ROOT}/references/skill-spec-baseline.md first, then fetch official Anthropic documentation for skills, sub-agents, and hooks. Return structured expert knowledge."

### Store Expert Context

Save the research agent's output as the **Expert Context**.

Tell the user:

```
Expert context assembled. Dispatching audit agent...
```

---

## Phase 2: Audit

### Dispatch Audit Agent

Read the scoring rubric first:
- Read `${SKILL_ROOT}/references/scoring-rubric.md`

Use the Task tool:
- `description`: "Audit skill quality"
- `subagent_type`: "skillet:audit-skill"
- `prompt`: Include all of:
  1. The Expert Context from Phase 1
  2. The Skill Manifest from Phase 0 (paths and line counts)
  3. The scoring rubric content

The agent will read all skill files and return structured findings.

---

## Phase 3: Scoring

### Score Each Category

Read `${SKILL_ROOT}/references/scoring-rubric.md` if not already in context.

Apply the rubric to the audit findings. For each of the 6 categories:

1. Start at base score of **100**
2. Apply matching **deductions** based on audit findings
3. Apply matching **bonuses** based on audit findings
4. Clamp to 0-100 range

**Categories and their weights:**

| Category | Weight |
|----------|--------|
| Frontmatter Correctness | 15% |
| Instruction Quality | 25% |
| Agent Design | 15% |
| Directory Structure | 15% |
| Over-Engineering | 15% |
| Reference & Tooling | 15% |

**Scope-aware scoring:**
- If the skill has no agents → Agent Design = 100 (neutral)
- If the skill has no hooks or references → Reference & Tooling = 100 (neutral)

### Compute Overall Score

```
overall = sum(category_score * category_weight for all categories)
```

Look up the letter grade from the rubric's grade threshold table.

### Build Recommendations

Compile a ranked list of recommendations from audit findings:

1. **Critical** (> 20 point impact): Must fix
2. **High** (10-20 point impact): Should fix
3. **Medium** (5-9 point impact): Nice to have
4. **Low** (< 5 point impact): Optional

### Present the Quality Report

```
╔══════════════════════════════════════════════════════════╗
║                 SKILLET QUALITY REPORT                   ║
║  Skill: <name>  | Overall: XX/100  Grade: X  (Label)    ║
╚══════════════════════════════════════════════════════════╝

Frontmatter          ████████████████████░░░░░  XX/100  X
Instruction Quality  ████████████████████░░░░░  XX/100  X
Agent Design         ████████████████████░░░░░  XX/100  X
Directory Structure  ████████████████████░░░░░  XX/100  X
Over-Engineering     ████████████████████░░░░░  XX/100  X
Reference & Tooling  ████████████████████░░░░░  XX/100  X
```

For the visual bars, use `█` for filled and `░` for empty. Scale to 25 characters total.

After the score card, present:

1. **Critical Issues** — anything scoring below 50 in a category
2. **Top Recommendations** — ranked list with estimated point impact
3. **Patterns to Adopt** — best practices from Expert Context not currently used
4. **See Also** — cross-tool suggestions based on findings:
   - If the audit found configuration issues beyond skill scope (e.g., settings anti-patterns, permission problems, MCP issues referenced in the skill): suggest `For a full configuration audit, try /claudit`
   - If Expert Context came from the fallback research agent (not claudit cache): suggest `Install claudit for cached research that speeds up skillet runs`

---

## Phase 4: Interactive Enhancement

### Present Recommendations for Selection

Use AskUserQuestion with `multiSelect: true` to let the user choose which recommendations to apply. Group by priority.

Format each option as:
- Label: Short description
- Description: What will change and estimated point impact

Include a "Skip — no changes" option.

### Implement Selected Fixes

For each selected recommendation:

1. Read the target file
2. Apply the fix using Write or Edit
3. Briefly explain what changed

### Re-Score and Show Delta

After implementing fixes:

1. Re-score only the affected categories
2. Show before/after:

```
Score Delta:
  Frontmatter          65 → 85  (+20)
  Instruction Quality  70 → 88  (+18)
  Overall              72 → 84  (+12)  Grade: C → B
```

---

## Error Handling

- If the skill doesn't exist, report it and stop
- If the research agent fails, continue with the baseline spec
- If the audit agent fails, attempt a direct audit using Read/Grep from the orchestrator
- If no issues are found (score 90+), congratulate the user and suggest patterns to explore
- If a fix fails to apply, report the error and continue with remaining fixes

## Important Notes

- **Never auto-apply changes** — always present recommendations and let the user choose
- **Quote specific lines** when showing what would change
- **Be opinionated** about over-engineering — this is skillet's core value proposition
- **Score neutral when N/A** — don't penalize for missing components that aren't needed
- **Show line counts** alongside file paths for context
