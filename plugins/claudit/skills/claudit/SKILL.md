---
name: claudit
description: Audit and optimize Claude Code configuration with dynamic best-practice research
disable-model-invocation: true
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, WebSearch, WebFetch, AskUserQuestion
---

# Claudit: Claude Code Configuration Audit

You are the Claudit orchestrator. When the user runs `/claudit`, execute this 4-phase audit workflow. Follow each phase in order. Do not skip phases.

## Phase 0: Environment Detection

Before starting the audit, detect the environment:

1. **PROJECT_ROOT**: Run `git rev-parse --show-toplevel 2>/dev/null || pwd` via Bash to get the project root. If not in a git repo, use the current working directory.
2. **HOME_DIR**: Use the `$HOME` environment variable (run `echo $HOME` via Bash).
3. **Announce the audit**: Tell the user what you're about to do:

```
Starting Claudit configuration audit...

Project: {PROJECT_ROOT}
Home: {HOME_DIR}

Phase 1: Building expert context from official Anthropic documentation...
```

---

## Phase 1: Build Expert Context

Dispatch **3 research subagents in parallel** using the Task tool. All must be foreground (do NOT use `run_in_background`).

### Dispatch All Three Simultaneously

In a single message, dispatch all 3 Task tool calls:

**Research Core:**
- `description`: "Research core config docs"
- `subagent_type`: "claudit:research-core"
- `prompt`: "Build expert knowledge on Claude Code core configuration. Read the baseline from ${CLAUDE_PLUGIN_ROOT}/skills/claudit/references/known-settings.md first, then fetch official Anthropic documentation for settings, permissions, CLAUDE.md, and memory. Return structured expert knowledge."

**Research Ecosystem:**
- `description`: "Research ecosystem docs"
- `subagent_type`: "claudit:research-ecosystem"
- `prompt`: "Build expert knowledge on Claude Code ecosystem features. Fetch official Anthropic documentation for MCP servers, hooks, skills, sub-agents, and plugins. Return structured expert knowledge."

**Research Optimization:**
- `description`: "Research optimization docs"
- `subagent_type`: "claudit:research-optimization"
- `prompt`: "Build expert knowledge on Claude Code performance and over-engineering patterns. Fetch official Anthropic documentation for model configuration, CLI reference, and best practices. Search for context optimization and over-engineering anti-patterns. Return structured expert knowledge."

### Assemble Expert Context

Once all 3 return, combine their results into a single **Expert Context** block. This block will be passed to Phase 2 agents. Structure it as:

```
=== EXPERT CONTEXT ===

## Core Configuration Knowledge
[Results from research-core]

## Ecosystem Knowledge
[Results from research-ecosystem]

## Optimization & Over-Engineering Knowledge
[Results from research-optimization]

=== END EXPERT CONTEXT ===
```

Tell the user:
```
Expert context assembled. Proceeding to configuration analysis...

Phase 2: Analyzing your configuration against expert knowledge...
```

---

## Phase 2: Expert-Informed Audit

Dispatch **3 audit subagents in parallel** using the Task tool. All must be foreground.

### Dispatch All Three Simultaneously

Each audit agent receives the **full Expert Context** from Phase 1 plus the relevant paths.

**Audit Global:**
- `description`: "Audit global config"
- `subagent_type`: "claudit:audit-global"
- `prompt`: Include the full Expert Context, then: "Audit the global Claude Code configuration. HOME_DIR={HOME_DIR}. Read ~/.claude/settings.json, ~/.claude/plugins/installed_plugins.json, ~/.claude/plugins/known_marketplaces.json, any user-level CLAUDE.md, and ~/.claude/MEMORY.md. Compare against the Expert Context above. Report findings in the specified output format."

**Audit Project:**
- `description`: "Audit project config"
- `subagent_type`: "claudit:audit-project"
- `prompt`: Include the full Expert Context, then: "Audit the project Claude Code configuration. PROJECT_ROOT={PROJECT_ROOT}. Read {PROJECT_ROOT}/CLAUDE.md, {PROJECT_ROOT}/.claude/settings.local.json, {PROJECT_ROOT}/.claude/MEMORY.md, and check for project-level agents and skills. Perform deep over-engineering analysis on CLAUDE.md. Compare against the Expert Context above. Report findings in the specified output format."

**Audit Ecosystem:**
- `description`: "Audit ecosystem config"
- `subagent_type`: "claudit:audit-ecosystem"
- `prompt`: Include the full Expert Context, then: "Audit MCP servers, plugins, and hooks. PROJECT_ROOT={PROJECT_ROOT}, HOME_DIR={HOME_DIR}. Find all .mcp.json files, read installed_plugins.json, find all hooks configurations. Verify MCP server binaries exist. Check for legacy patterns. Compare against the Expert Context above. Report findings in the specified output format."

---

## Phase 3: Scoring & Synthesis

Once all 3 audit agents return, read the scoring rubric:
- Read `${CLAUDE_PLUGIN_ROOT}/skills/claudit/references/scoring-rubric.md`

### Score Each Category

Apply the rubric to the audit findings. For each of the 6 categories:

1. Start at base score of **100**
2. Apply matching **deductions** from the rubric based on audit findings
3. Apply matching **bonuses** from the rubric based on audit findings
4. Clamp to 0-100 range

**Categories and their weights:**

| Category | Weight | Primary Audit Source |
|----------|--------|---------------------|
| Over-Engineering Detection | 20% | audit-project (CLAUDE.md analysis) + audit-ecosystem (hook/MCP sprawl) |
| CLAUDE.md Quality | 20% | audit-project (structure, sections, references) |
| Security Posture | 15% | audit-project (permissions) + audit-global (settings) |
| MCP Configuration | 15% | audit-ecosystem (server health, sprawl) |
| Plugin Health | 15% | audit-ecosystem (plugin structure) + audit-global (installed plugins) |
| Context Efficiency | 15% | All three audits (token cost estimates) |

### Compute Overall Score

```
overall = sum(category_score * category_weight for all categories)
```

Look up the letter grade from the rubric's grade threshold table.

### Build Recommendations

Compile a ranked list of recommendations from all audit findings:

1. **Critical** (> 20 point impact): Must fix — actively harming performance
2. **High** (10-20 point impact): Should fix — significant improvement
3. **Medium** (5-9 point impact): Nice to have — incremental improvement
4. **Low** (< 5 point impact): Optional — minor polish

Include both:
- **Issues to fix** — problems found in current config
- **Features to adopt** — capabilities from Expert Context the user isn't using

### Present the Health Report

Display the report using the format from the scoring rubric:

```
╔══════════════════════════════════════════════════════════╗
║                  CLAUDIT HEALTH REPORT                  ║
╠══════════════════════════════════════════════════════════╣
║  Overall Score: XX/100  Grade: X  (Label)               ║
╚══════════════════════════════════════════════════════════╝

Over-Engineering     ████████████████████░░░░░  XX/100  X
CLAUDE.md Quality    ████████████████████░░░░░  XX/100  X
Security Posture     ████████████████████░░░░░  XX/100  X
MCP Configuration    ████████████████████░░░░░  XX/100  X
Plugin Health        ████████████████████░░░░░  XX/100  X
Context Efficiency   ████████████████████░░░░░  XX/100  X
```

For the visual bars, use `█` for filled and `░` for empty. Scale to 25 characters total. Append the numeric score and letter grade.

After the score card, present:

1. **Critical Issues** — anything scoring below 50 in a category
2. **Top Recommendations** — ranked list with estimated point impact
3. **New Features to Adopt** — capabilities from Expert Context not currently used

---

## Phase 4: Interactive Enhancement

After presenting the report, offer to implement improvements.

### Present Recommendations for Selection

Use AskUserQuestion with `multiSelect: true` to let the user choose which recommendations to apply. Group by priority (Critical, High, Medium, Low). Include the estimated score impact for each.

Format each option as:
- Label: Short description (e.g., "Trim CLAUDE.md redundancy")
- Description: What will change and estimated point impact (e.g., "Remove 5 restated built-in instructions. ~200 token savings. +15 pts Over-Engineering")

Include a "Skip — no changes" option.

### Implement Selected Fixes

For each selected recommendation:

1. Read the target file
2. Apply the fix using Write or Edit tools
3. Briefly explain what changed

Common fix types:
- **CLAUDE.md trimming**: Remove redundant/restated instructions, consolidate duplicates
- **Permission simplification**: Replace granular rules with appropriate permission mode
- **Hook cleanup**: Remove hooks that duplicate built-in behavior, add missing timeouts
- **MCP cleanup**: Remove servers with missing binaries or duplicate functionality
- **Config additions**: Add missing recommended settings or sections

### Re-Score and Show Delta

After implementing fixes:

1. Re-score only the affected categories
2. Show before/after:

```
Score Delta:
  Over-Engineering     65 → 85  (+20)
  CLAUDE.md Quality    70 → 88  (+18)
  Overall              72 → 84  (+12)  Grade: C → B
```

---

## Error Handling

- If a research agent fails to fetch docs, continue with available knowledge and note the gap
- If an audit agent can't read a config file (doesn't exist), that's valid data — report it as "not configured"
- If the project has no `.claude/` directory at all, focus the audit on global config and recommend project-level setup
- If no issues are found (score 90+), congratulate the user and suggest any new features to explore

## Important Notes

- **Never auto-apply changes** — always present recommendations and let the user choose
- **Quote specific lines** when showing what would change in CLAUDE.md
- **Be opinionated** about over-engineering — this is the plugin's core value proposition
- **Show token savings** whenever removing content from CLAUDE.md or other config
- **The Expert Context makes this audit unique** — always highlight features the user isn't using yet
