---
name: build
description: Build a new Claude Code skill from scratch with research-first architecture and opinionated structure
disable-model-invocation: true
argument-hint: skill-name
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion
---

# Skillet: Build a New Skill

You are the Skillet build orchestrator. When the user runs `/skillet:build`, execute this 5-phase workflow to scaffold a new Claude Code skill. Follow each phase in order. Do not skip phases.

## Phase 0: Input & Validation

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for the skill name and optional description.

- If `$ARGUMENTS` is empty, use AskUserQuestion to ask: "What should the skill be named? (kebab-case, e.g., `deploy-check`)"
- If a description wasn't provided, use AskUserQuestion: "Briefly describe what this skill should do."

### Step 2: Validate Name

- Ensure the name is kebab-case (lowercase letters, numbers, hyphens only)
- If not, suggest a kebab-case version and confirm with the user

### Step 3: Determine Target Location

Use AskUserQuestion to ask:

```
Where should this skill be created?

1. Project skill (`.claude/skills/<name>/`) — for project-specific workflows
2. Plugin skill (`plugins/<plugin>/skills/<name>/`) — for a distributable plugin

If plugin: which plugin directory?
```

### Step 4: Check for Conflicts

- Glob for existing files at the target path
- If the skill directory already exists, warn the user and ask to proceed or choose a different name

Tell the user:

```
Phase 1: Building expert context from official Anthropic documentation...
```

---

## Phase 1: Research

### Step 1: Check Claudit Knowledge Cache

Check if claudit's cached ecosystem research is available and fresh (see `plugins/claudit/references/cache-check-protocol.md` for the full contract):

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
- Tell the user: `Expert context loaded from claudit cache (fetched {date}). Gathering requirements...`
- **Skip to Phase 2**

**If STALE or MISSING:**
- Proceed to Step 2

### Step 2: Dispatch Research Agent (Fallback)

Use the Task tool:
- `description`: "Research skill spec docs"
- `subagent_type`: "skillet:research-skill-spec"
- `prompt`: "Build expert knowledge on Claude Code skill, agent, and hook authoring. Read the baseline from ${CLAUDE_PLUGIN_ROOT}/references/skill-spec-baseline.md first, then fetch official Anthropic documentation for skills, sub-agents, and hooks. Return structured expert knowledge."

### Store Expert Context

Save the research agent's output as the **Expert Context** for use in subsequent phases.

Tell the user:

```
Expert context assembled. Gathering requirements...
```

---

## Phase 2: Requirements

Gather requirements from the user via AskUserQuestion. Skip questions where the answer is already known from the description or arguments.

### Question 1: Sub-agents

```
Does this skill need sub-agents?

If yes, list each agent (one per line):
  name: brief purpose

Example:
  analyze-code: reads and evaluates code quality
  fetch-docs: retrieves external documentation
```

### Question 2: Hooks

```
Does this skill need hooks? (Select event types that apply)

- SessionStart — run at session initialization
- PreToolUse — intercept before a tool is called
- PostToolUse — react after a tool returns
- Stop — run when the agent stops
- None — no hooks needed
```

### Question 3: Reference Files

```
Does this skill need reference files? (Heavy content loaded on demand)

Examples: scoring rubrics, spec baselines, templates, schemas

If yes, briefly describe each reference file.
If no, just say "none".
```

### Question 4: Auto-invocation

```
Should this skill auto-invoke (triggered by context) or require explicit /command?

- Explicit (default) — user must type /skill-name to run it
- Auto-invoke — Claude triggers it when the context matches the description
```

### Question 5: Tools

Based on the skill's complexity and sub-agents, suggest an appropriate tool list:

```
What tools does this skill need?

Suggested based on your requirements:
  [Generated tool list based on complexity]

Common tool sets:
- Read-only analysis: Read, Glob, Grep
- File creation: Read, Glob, Grep, Write, Edit
- Full orchestration: Task, Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion

Adjust as needed.
```

---

## Phase 3: Plan & Approve

### Build the Blueprint

Using the Expert Context and requirements, build a complete skill blueprint:

1. **Directory tree** — all files that will be created, following the template from `${CLAUDE_PLUGIN_ROOT}/references/directory-template.md`
2. **SKILL.md outline** — frontmatter + phase structure with descriptions
3. **Agent outlines** — frontmatter + purpose + output format for each agent
4. **Hook skeleton** — hooks.json structure if hooks are needed
5. **Reference file outlines** — structure for each reference file

Read the directory template:
- Read `${CLAUDE_PLUGIN_ROOT}/references/directory-template.md`

### Enforce Template

Validate the blueprint against the directory template:
- SKILL.md is the only file in the skill directory (besides references/)
- Agents go in `agents/` at the parent level
- Hooks go in centralized `hooks/hooks.json`
- kebab-case everywhere
- No empty directories

### Present for Approval

Present the full blueprint to the user using AskUserQuestion:

```
Here's the skill blueprint:

=== DIRECTORY STRUCTURE ===
[tree view of all files to create]

=== SKILL.md OUTLINE ===
[frontmatter + phase descriptions]

=== AGENT OUTLINES ===
[for each agent: frontmatter + purpose]

=== HOOKS ===
[hooks.json structure or "none"]

=== REFERENCES ===
[reference file descriptions or "none"]

Approve this blueprint? (yes / modify / cancel)
```

If the user wants modifications, adjust and re-present.

---

## Phase 4: Scaffold

Create all files following the approved blueprint.

### Create SKILL.md

Write the SKILL.md with:
- Complete frontmatter (name, description, disable-model-invocation, argument-hint, allowed-tools)
- Header section with skill purpose
- Phase structure with numbered phases (Phase 0, 1, 2...)
- Each phase has: description, steps, expected inputs/outputs
- TODO markers where the user needs to fill in domain-specific logic
- Error handling section at the end

### Create Agent Files

For each agent, write to `agents/<name>.md` at the parent level:
- Complete frontmatter (name, description, tools, model, memory if needed)
- Purpose section
- Step-by-step process
- Output format specification
- Budget constraints
- Critical rules
- TODO markers for domain-specific logic

### Create Hook Files

If hooks are needed, write `hooks/hooks.json`:
- Valid event types with appropriate matchers
- Explicit timeouts on every hook
- TODO markers for command implementation

### Create Reference Files

For each reference file, write to the appropriate `references/` directory:
- Structured content outline
- TODO markers for domain-specific content

---

## Phase 5: Summary

Present the created files and next steps:

```
=== SKILL CREATED ===

Files created:
  [list each file with path and line count]

Next steps:
  1. Fill in TODO sections with domain-specific logic
  2. Test with: claude --plugin-dir /path/to/plugin  (or reload session for .claude/ skills)
  3. Audit with: /skillet:audit <path>
```

---

## Error Handling

- If the research agent fails, continue with the baseline spec from `${CLAUDE_PLUGIN_ROOT}/references/skill-spec-baseline.md`
- If the target directory can't be created, report the error and suggest alternatives
- If the user cancels at any phase, stop gracefully and report what was done
- If a file write fails, report the error and continue with remaining files

## Important Notes

- **Follow the directory template strictly** — this is skillet's core value proposition
- **Always ask before creating files** — present the blueprint first
- **TODO markers are essential** — the scaffold is a starting point, not a finished product
- **Agent model selection matters** — suggest haiku for simple tasks, inherit for complex ones
- **Reference files are for heavy content** — short config belongs inline in SKILL.md
