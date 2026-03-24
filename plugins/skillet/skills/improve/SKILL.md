---
name: improve
description: Improve an existing Claude Code skill using audit findings or manual direction
disable-model-invocation: true
argument-hint: skill-path
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion
---

# Skillet: Improve a Skill

You are the Skillet improve orchestrator. When the user runs `/skillet:improve`, execute this workflow to enhance an existing skill. This skill bridges audit findings to implementation. Follow each phase in order.

## Phase 0: Context Resolution

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for the skill path or name.

Supported formats:
- Full path: `.claude/skills/my-skill` or `plugins/my-plugin/skills/my-skill`
- Skill name only: `my-skill` (search for it)

If `$ARGUMENTS` is empty, use AskUserQuestion: "Which skill should I improve? Provide a path or name."

### Step 2: Locate the Skill

If a full path was given, verify it exists. If only a name was given, search for it:

1. Glob for `.claude/skills/$NAME/SKILL.md`
2. Glob for `plugins/*/skills/$NAME/SKILL.md`
3. If multiple matches, ask the user which one

If not found, report the error and stop.

### Step 3: Check for Audit Context

Determine if audit results exist in the current conversation context:

- Look for a Skillet Quality Report in the conversation (score card, recommendations)
- If found, ask the user via AskUserQuestion:

```
I found audit results for this skill in our conversation. Would you like to:

1. Use audit findings — improve based on the recommendations from the audit
2. Describe improvements — tell me what you want to change instead
3. Re-audit first — run a fresh audit before improving
```

- If no audit results found, ask:

```
No audit results found. Would you like to:

1. Run audit first — audit the skill, then improve based on findings
2. Describe improvements — tell me what you want to change
```

If the user chooses to run an audit first, dispatch `/skillet:audit` on the skill path, then continue with the audit findings.

---

## Phase 1: Research

**Skip this phase if an audit already ran it in this session** — the Expert Context is already available.

### Step 1: Check Claudit Knowledge Cache

Check if claudit's cached ecosystem research is available and fresh:

1. Run via Bash: `claude --version 2>/dev/null` → store as **CURRENT_VERSION**
2. Run via Bash: `cat ~/.cache/claudit/manifest.json 2>/dev/null`
3. If the manifest exists, apply invalidation:
   a. **Version check**: manifest's `claude_code_version` must match CURRENT_VERSION
   b. **Per-domain time check**: check `domains.ecosystem.cached_at` age — must be < `max_ttl_days` (7 days)
   c. **File check**: `~/.cache/claudit/ecosystem.md` must exist
4. All three must pass → **FRESH**

**If FRESH:**
- Read `~/.cache/claudit/ecosystem.md`
- Also read `${CLAUDE_PLUGIN_ROOT}/references/skill-spec-baseline.md` for skill-authoring-specific detail (frontmatter field semantics, variable substitution rules) that the ecosystem cache may not cover at full depth
- Use both as **Expert Context**
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

---

## Phase 2: Improvement Plan

### Build the Plan

From audit findings or manual description, combined with Expert Context:

1. **Read the current skill files** — SKILL.md, agents, hooks, references
2. **Read the directory template** — `${CLAUDE_PLUGIN_ROOT}/references/directory-template.md`
3. **List each change** with:
   - What will change (specific file and section)
   - Why (rationale from audit finding or user request)
   - Expected score impact (if from audit)

### Enforce Directory Template

Check if any improvements should include structural changes:
- Agents in wrong location → move to `agents/`
- Loose files in skill directory → relocate
- Non-kebab-case names → rename
- Missing references/ for heavy content → create and move

### Present for Approval

Use AskUserQuestion to present the plan:

```
=== IMPROVEMENT PLAN ===

1. [Change description]
   File: [path]
   Rationale: [why]
   Impact: [estimated score change, if from audit]

2. [Change description]
   ...

Approve this plan? (yes / modify / cancel)
```

If the user wants modifications, adjust and re-present.

---

## Phase 3: Implement

### Apply Approved Changes

For each approved change:

1. Read the target file (if not already read)
2. Apply the change using Edit (for modifications) or Write (for new files)
3. Briefly explain what changed and why

### Change Types

Common improvements:

- **Frontmatter fixes**: Add missing fields, fix name mismatches, adjust tool lists
- **Phase restructuring**: Add phase organization to unstructured skills
- **Error handling**: Add error handling guidance
- **Argument parsing**: Add `$ARGUMENTS` parsing and validation
- **Directory restructuring**: Move files to match template
- **Agent refinement**: Adjust model, tools, output format, budget
- **Reference extraction**: Move heavy inline content to `references/`
- **Hook cleanup**: Add timeouts, fix matchers, remove duplicates
- **Verbosity reduction**: Trim restated built-ins, consolidate instructions
- **Cross-reference fixes**: Fix broken `${SKILL_ROOT}` and `${CLAUDE_PLUGIN_ROOT}` paths

---

## Phase 4: Verify

### If Audit Was Run

Re-score the affected categories using the rubric at `${CLAUDE_PLUGIN_ROOT}/skills/audit/references/scoring-rubric.md`:

1. Re-evaluate only the categories that were affected by changes
2. Show before/after delta:

```
Score Delta:
  Frontmatter          65 → 85  (+20)
  Instruction Quality  70 → 88  (+18)
  Overall              72 → 84  (+12)  Grade: C → B
```

### If Manual Improvements

Summarize what was changed:

```
=== CHANGES APPLIED ===

Files modified:
  [path] — [brief description of change]

Files created:
  [path] — [brief description]

Files moved:
  [old path] → [new path]

Next steps:
  - Test with: claude --plugin-dir /path/to/plugin
  - Audit with: /skillet:audit <path>
```

---

## Error Handling

- If the skill doesn't exist, report it and stop
- If the research agent fails, continue with the baseline spec
- If a file edit fails, report the error and continue with remaining changes
- If the user cancels, stop gracefully and report what was done
- If structural changes (file moves) fail, suggest manual steps

## Important Notes

- **Always read before editing** — never modify files you haven't read
- **Present the plan first** — no changes without user approval
- **Preserve existing logic** — improvements should enhance, not replace, domain-specific content
- **Follow the directory template** — structural improvements are first-class changes
- **Show the delta** — when re-scoring, always show before/after for each affected category
