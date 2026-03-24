---
name: claudit
description: Audit and optimize Claude Code configuration with dynamic best-practice research
disable-model-invocation: true
argument-hint: "[focus-area]"
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion
---

# Claudit: Claude Code Configuration Audit

You are the Claudit orchestrator. When the user runs `/claudit` or `/claudit <focus-area>`, execute this 5-phase audit workflow. Follow each phase in order. Do not skip phases.

## Phase 0: Environment Detection & Configuration Map

### Step 1: Environment Detection

1. **PROJECT_ROOT**: Run `git rev-parse --show-toplevel 2>/dev/null` via Bash. If this fails (not in a git repo), set PROJECT_ROOT to empty.
2. **HOME_DIR**: Run `echo $HOME` via Bash.

### Step 1.5: Parse Focus Argument

Extract the focus area from `$ARGUMENTS`.

- If `$ARGUMENTS` is empty or missing → set **FOCUS_MODE = false**. Proceed with a full audit (default behavior).
- If `$ARGUMENTS` is provided → set **FOCUS_MODE = true**. Set **FOCUS_AREA** to the user's input.

Match `$ARGUMENTS` as a whole string against this mapping (fuzzy — use judgment for synonyms and variations):

| User Input (examples) | Focus Area | Primary Scoring Categories |
|----------------------|------------|---------------------------|
| skills, agents, skill quality | Skills & Agents | CLAUDE.md Quality, Over-Engineering |
| CLAUDE.md, instructions, rules, instruction files | Instruction Files | CLAUDE.md Quality, Over-Engineering, Context Efficiency |
| MCP, servers, mcp servers, mcp config | MCP Configuration | MCP Configuration, Context Efficiency |
| hooks, hook config, hook sprawl | Hooks | Over-Engineering, Security Posture |
| plugins, plugin health | Plugins | Plugin Health |
| security, permissions, secrets | Security | Security Posture |
| over-engineering, verbosity, redundancy | Over-Engineering | Over-Engineering |
| context, tokens, context efficiency | Context Efficiency | Context Efficiency |
| `<text matching an installed plugin name>` | Specific Plugin | Plugin Health |
| `<any other text>` | Free-form (use as-is) | all categories (best effort) |

**Plugin name matching** is deferred to Step 3.5 (after the config map is built), since it requires reading `installed_plugins.json`. At this step, only apply keyword matching from the table above. If no keyword matches, tentatively mark as free-form — Step 3.5 may reclassify it as a specific plugin.

Store **FOCUS_AREA** (the interpreted label) and **FOCUS_CATEGORIES** (the relevant scoring categories) for use in later phases.

### Step 2: Scope Detection

- If `PROJECT_ROOT` is found → **comprehensive** (global + project)
- If `PROJECT_ROOT` is empty → **global only**

### Step 3: Comprehensive Configuration Scan

Run parallel Glob calls to discover every Claude-related file. Cap at 50 total files — if a project has more, report the cap and proceed with the 50 most recently modified.

**Project-level (if comprehensive):**

| Category | Glob Pattern | Notes |
|----------|-------------|-------|
| Instructions | `{PROJECT_ROOT}/**/CLAUDE.md` | Exclude node_modules, .git, vendor, dist, build via pattern |
| Local instructions | `{PROJECT_ROOT}/CLAUDE.local.md` | Personal/gitignored |
| Rules | `{PROJECT_ROOT}/.claude/rules/**/*.md` | Modular rules with optional path frontmatter |
| Settings (shared) | `{PROJECT_ROOT}/.claude/settings.json` | Team settings |
| Settings (local) | `{PROJECT_ROOT}/.claude/settings.local.json` | Personal project settings |
| Skills | `{PROJECT_ROOT}/.claude/skills/*/SKILL.md` | Project skills |
| Agents | `{PROJECT_ROOT}/.claude/agents/*.md` | Project subagents |
| Memory | `{PROJECT_ROOT}/.claude/MEMORY.md` | Project memory |
| MCP | `{PROJECT_ROOT}/.mcp.json` | Project MCP servers |
| Plugin hooks | `{PROJECT_ROOT}/.claude/plugins/*/hooks/hooks.json` | Plugin-level hooks |

For the Instructions glob, exclude common vendor directories. Use Glob with pattern `**/CLAUDE.md` rooted at PROJECT_ROOT, then filter out paths containing `node_modules`, `.git`, `vendor`, `dist`, or `build`.

**Global-level (always):**

| Category | Path | Notes |
|----------|------|-------|
| Settings | `~/.claude/settings.json` | Global settings |
| Instructions | `~/.claude/CLAUDE.md` | Global instructions (check `~/CLAUDE.md` too as legacy) |
| Rules | `~/.claude/rules/**/*.md` | Personal modular rules |
| Memory | `~/.claude/MEMORY.md` | Global memory |
| MCP | `~/.claude/.mcp.json` | Global MCP servers |
| Plugins | `~/.claude/plugins/installed_plugins.json` | Installed plugins |
| Marketplaces | `~/.claude/plugins/known_marketplaces.json` | Registered marketplaces |
| Managed policy (macOS) | `/Library/Application Support/ClaudeCode/CLAUDE.md` | macOS managed policy |
| Managed policy (Linux) | `/etc/claude-code/CLAUDE.md` | Linux/WSL managed policy |

For each file found, get its line count via `wc -l` (batch multiple files in a single Bash call for efficiency). Quote paths containing spaces (e.g., `/Library/Application Support/...`) in any Bash commands.

### Step 3.5: Resolve Plugin Name Focus

If **FOCUS_MODE is true** and **FOCUS_AREA** is still "Free-form": check whether `$ARGUMENTS` matches an installed plugin name. Read `installed_plugins.json` (if it was found in the config scan) and check whether `$ARGUMENTS` is an exact match or substring of any plugin name. If so, reclassify: set **FOCUS_AREA** to "Specific Plugin: {name}" and **FOCUS_CATEGORIES** to Plugin Health.

### Step 4: Build and Present the Configuration Map

Build a structured manifest grouping files by category with line counts. Present it to the user:

```
=== CONFIGURATION MAP ===
Scope: Comprehensive (project + global)

PROJECT: {PROJECT_ROOT}
  Instructions (N files, ~N tokens):
    CLAUDE.md                        45 lines
    src/api/CLAUDE.md                30 lines
    CLAUDE.local.md                  10 lines
    .claude/rules/testing.md         15 lines
  Settings (N files):
    .claude/settings.json            exists
    .claude/settings.local.json      exists
  Skills (N): [list]
  Agents (N): [list]
  Memory: .claude/MEMORY.md          30 lines
  MCP: .mcp.json                     N servers configured

GLOBAL: ~/.claude/
  Instructions: ~/.claude/CLAUDE.md  20 lines
  Rules: [list or "none"]
  Settings: ~/.claude/settings.json  exists
  Memory: ~/.claude/MEMORY.md        15 lines
  MCP: ~/.claude/.mcp.json           N servers configured
  Plugins: N installed

MANAGED POLICY: [found (N lines) / not found]
=== END MAP ===
```

Estimate tokens for instruction files as `(total_lines * 40) / 4` (rough estimate: ~10 words per line, ~4 chars per word, divided by 4 chars per token). This line-based estimate is for the config map display only. Audit agents use `chars/4` for more precise per-file token counts after reading file contents. Show the aggregate token estimate for instruction files.

After presenting the map, if **FOCUS_MODE is true**, display:

```
Focus: {FOCUS_AREA}
  Primary categories: {FOCUS_CATEGORIES}
  Audit agents will go deeper on this area while still performing a full audit.
```

### Step 5: Load Decision Memory

Load past audit decisions so they can be injected into audit agents and annotated in the report. Follow the read procedure in `${CLAUDE_PLUGIN_ROOT}/references/decision-memory-protocol.md`.

1. Determine the decisions file path:
   - **Comprehensive scope**: `{PROJECT_ROOT}/.claude/claudit-decisions.json`
   - **Global only**: `~/.cache/claudit/decisions.json`
2. Read the file via Bash: `cat {path} 2>/dev/null`
3. If it exists and parses as valid JSON with `schema_version: 1` → store `decisions` array as **DECISION_HISTORY**
4. If it doesn't exist → set **DECISION_HISTORY** to empty array (first run)
5. Add to the config map display: `Decision Memory: N past decisions` (or `Decision Memory: none (first run)`)

Also run `git config user.name 2>/dev/null` and store as **GIT_USER** for use in Phase 4.

Then tell the user:

```
Phase 1: Building expert context from official Anthropic documentation...
```

---

## Phase 1: Build Expert Context

### Step 1: Check Knowledge Cache

Check if cached research exists and is fresh before dispatching research agents. Follow the protocol in `${CLAUDE_PLUGIN_ROOT}/references/cache-check-protocol.md`.

1. Run via Bash: `claude --version 2>/dev/null` → store as **CURRENT_VERSION**
2. Run via Bash: `cat ~/.cache/claudit/manifest.json 2>/dev/null`
3. If the manifest file exists, apply **three-check invalidation**:
   a. **Version check**: Compare the manifest's `claude_code_version` to CURRENT_VERSION. If different → **STALE** (Claude Code was updated since last research).
   b. **Per-domain time check**: For each of the 3 domains (core-config, ecosystem, optimization), check that domain's `domains.<name>.cached_at`. Compute age vs current date. If any domain's age >= `max_ttl_days` (7 days) → **STALE**.
   c. **File check**: Verify all 3 cache files exist: `~/.cache/claudit/core-config.md`, `~/.cache/claudit/ecosystem.md`, `~/.cache/claudit/optimization.md`. If any is missing → **STALE**.
4. Cache is **FRESH** only if all three checks pass.

**If FRESH:**
- Read `~/.cache/claudit/core-config.md`, `~/.cache/claudit/ecosystem.md`, and `~/.cache/claudit/optimization.md`
- Assemble Expert Context from these files (same format as Step 3 below)
- Tell the user:
  ```
  Expert context loaded from cache (v{CURRENT_VERSION}, fetched {cached_at date}). Use /claudit:refresh to force-update.

  Phase 2: Analyzing your configuration against expert knowledge...
  ```
- **Skip to Phase 2**

**If STALE or MISSING:**
- If STALE due to version change, tell user: `Claude Code updated ({old_version} → {CURRENT_VERSION}), refreshing knowledge cache...`
- Proceed to Step 2

### Step 2: Dispatch Research Agents

Dispatch **3 research subagents in parallel** using the Task tool. All must be foreground (do NOT use `run_in_background`).

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

### Step 3: Assemble Expert Context + Write Cache

Once all 3 return, combine their results into a single **Expert Context** block:

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

**Write results to the knowledge cache** so future runs (and other tools like skillet, smith, hone) can reuse them:

1. Run via Bash: `mkdir -p ~/.cache/claudit`
2. Run via Bash: `claude --version 2>/dev/null` → store as CURRENT_VERSION (if not already stored)
3. Write the research-core results to `~/.cache/claudit/core-config.md` using the Write tool
4. Write the research-ecosystem results to `~/.cache/claudit/ecosystem.md` using the Write tool
5. Write the research-optimization results to `~/.cache/claudit/optimization.md` using the Write tool
6. Write `~/.cache/claudit/manifest.json` with the following structure:
   ```json
   {
     "claude_code_version": "{CURRENT_VERSION}",
     "cached_at": "{current ISO 8601 timestamp}",
     "max_ttl_days": 7,
     "domains": {
       "core-config": { "cached_at": "{current ISO 8601 timestamp}" },
       "ecosystem": { "cached_at": "{current ISO 8601 timestamp}" },
       "optimization": { "cached_at": "{current ISO 8601 timestamp}" }
     }
   }
   ```

Tell the user:
```
Expert context assembled and cached. Proceeding to configuration analysis...

Phase 2: Analyzing your configuration against expert knowledge...
```

---

## Phase 2: Expert-Informed Audit

Dispatch audit subagents using the Task tool. Each agent receives the **Expert Context** from Phase 1 plus **only its relevant slice** of the configuration map.

### Build Agent Dispatch Prompts

**For `audit-global`**, include:
- Full Expert Context
- Global slice of config map: global instructions, global rules, global settings, global memory, global MCP, plugins, managed policy paths
- If comprehensive: also include the **content of the project's root CLAUDE.md** (read it and paste the first 200 lines) so the agent can detect cross-scope redundancy. Cap at 200 lines to avoid bloating the agent prompt for very large files.

**For `audit-project`** (comprehensive only), include:
- Full Expert Context
- Project slice of config map: all project instructions (with full paths), rules, settings, skills, agents, memory

**For `audit-ecosystem`**, include:
- Full Expert Context
- Ecosystem slice: all MCP config paths (global + project as applicable), plugins path, plugin hooks paths, paths to all settings files (agent reads them to check for hooks)

### Decision History Injection

If **DECISION_HISTORY** is non-empty, append a `=== DECISION HISTORY ===` block to each audit agent's dispatch prompt (after the Expert Context, before any Focus Directive). Route decisions to agents by **category slug** (not file_stem, which is ambiguous across scopes):

- **audit-global**: decisions where `category_slug` is `security` or `context-efficiency`
- **audit-project**: decisions where `category_slug` is `over-engineering`, `claudemd-quality`, `security`, or `context-efficiency`
- **audit-ecosystem**: decisions where `category_slug` is `mcp-config`, `plugin-health`, or `over-engineering` (for hook/MCP sprawl)

Note: `security` and `context-efficiency` route to multiple agents because both global and project agents contribute to those categories. `over-engineering` routes to both project (CLAUDE.md analysis) and ecosystem (hook/MCP sprawl). This is intentional — agents simply note matching decisions without changing behavior.

Format each decision concisely:

```
=== DECISION HISTORY ===
- [rejected] over-engineering:restated-builtin:CLAUDE.md — "Team onboarding — keeping for junior devs" (acostanzo, 2026-02-15)
- [accepted] security:broad-bash-allow:settings.json — applied fix (acostanzo, 2026-02-15)
=== END DECISION HISTORY ===
```

Agents are instructed to note matching decisions in their findings but never suppress issues.

### Focus Directive Injection

If **FOCUS_MODE is true**, prepend the following block to **each** audit agent's dispatch prompt (before the Expert Context):

```
=== FOCUS DIRECTIVE ===
The user has requested a focused audit on: {FOCUS_AREA}

Instructions:
1. Still perform your full audit scope (all checks in your playbook)
2. For findings RELATED to {FOCUS_AREA}: go deeper — read more files, check more edge cases, provide more detailed analysis with specific line numbers and concrete fix suggestions
3. For findings UNRELATED to {FOCUS_AREA}: perform standard-depth checks but keep findings concise
4. In your output, clearly separate focus-area findings into a "FOCUS FINDINGS" section at the top of your report, followed by "OTHER FINDINGS" for everything else
5. For focus findings, include specific file paths, line numbers, quoted content, and actionable recommendations
=== END FOCUS DIRECTIVE ===
```

The dispatch logic (which agents to send based on scope) does NOT change — always dispatch the same agents as the non-focused path. The Focus Directive is additive context, not a routing change.

### Dispatch Based on Scope

**Global only** → dispatch `audit-global` + `audit-ecosystem` in parallel (2 agents)
**Comprehensive** → dispatch all three in parallel (3 agents)

Use these agent types:
- `subagent_type`: "claudit:audit-global"
- `subagent_type`: "claudit:audit-project"
- `subagent_type`: "claudit:audit-ecosystem"

---

## Phase 3: Scoring & Synthesis

Once all audit agents return, read the scoring rubric:
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
| CLAUDE.md Quality | 20% | audit-project (structure, sections, references, multi-file) |
| Security Posture | 15% | audit-project (permissions) + audit-global (settings) |
| MCP Configuration | 15% | audit-ecosystem (server health, sprawl) |
| Plugin Health | 15% | audit-ecosystem (plugin structure) + audit-global (installed plugins) |
| Context Efficiency | 15% | All audits (token cost estimates, aggregate instruction size) |

**Scope-aware scoring:**
- **Global only**: Exclude CLAUDE.md Quality from scoring (no project to evaluate). Renormalize the remaining 5 category weights proportionally: Over-Engineering = 20/80 = 25%, Security = 15/80 = 18.75%, MCP = 18.75%, Plugin = 18.75%, Context = 18.75%. Note "CLAUDE.md Quality: skipped (no project detected)" in the report.
- **Comprehensive**: Score all 6 categories normally.

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

### Annotate with Decision Memory

If **DECISION_HISTORY** is non-empty, annotate each recommendation with past decision context. Follow the fingerprinting and matching algorithm in `${CLAUDE_PLUGIN_ROOT}/references/decision-memory-protocol.md`.

For each recommendation:

1. **Compute fingerprint**: `{category_slug}:{issue_type}:{file_stem}:{content_hash_8}` using the Issue Type Slugs table in the scoring rubric
2. **Match against DECISION_HISTORY**: exact match → high confidence; structural match (same prefix, different hash) → content changed; no match → new
3. **Check staleness** for matched decisions (any of: content hash changed, score impact delta >= 5, Claude Code version changed, age > 90 days, deferred > 30 days)
4. **Annotate** with status and any staleness reason (see Decision Annotation Format in scoring rubric)

**Ordering adjustment**: Present recommendations in this order:
1. New recommendations (no past decision)
2. Stale decisions (past decision exists but flagged for re-evaluation)
3. Previously accepted that recurred (regressions — most urgent, something was fixed but came back)
4. Previously rejected (with annotation showing reason and who decided)

**Never suppress recommendations** based on past decisions. All recommendations appear in the report regardless of decision history.

### Present the Health Report

Display the report header showing detected scope and file count:

```
╔══════════════════════════════════════════════════════════╗
║                  CLAUDIT HEALTH REPORT                  ║
╠══════════════════════════════════════════════════════════╣
║  Scope: Comprehensive | Files: N project + N global     ║
║  Decision Memory: N past decisions (M stale, K new)     ║
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

### Focus Mode Report Adjustments

If **FOCUS_MODE is true**, apply these adjustments to the report:

1. **Report header**: Add a `Focus:` line inside the header box:
   ```
   ║  Focus: {FOCUS_AREA}                                    ║
   ```

2. **Score bars**: Mark focus-relevant categories (from FOCUS_CATEGORIES) with a `◆` indicator:
   ```
   Over-Engineering  ◆  ████████████████████░░░░░  XX/100  X
   CLAUDE.md Quality ◆  ████████████████████░░░░░  XX/100  X
   Security Posture     ████████████████████░░░░░  XX/100  X
   ```

3. **Focus Deep Dive**: After the score card and before recommendations, add a **Focus Deep Dive** section that consolidates all focus-related findings from all audit agents into a single narrative with specific file references, line numbers, and actionable detail.

4. **Findings order**: Present focus-area findings and recommendations first, then other findings.

After the score card, present:

1. **Focus Deep Dive** (focus mode only) — consolidated focus-area findings from all agents
2. **Critical Issues** — anything scoring below 50 in a category
3. **Top Recommendations** — ranked list with estimated point impact (focus-relevant recommendations first when in focus mode)
4. **New Features to Adopt** — capabilities from Expert Context not currently used
5. **See Also** — cross-tool suggestions based on findings:
   - If audit-project or audit-ecosystem found skill/agent structural issues (e.g., legacy commands/ directory, missing or malformed frontmatter, skills without proper structure): suggest `For detailed skill-level analysis, try /skillet:audit <skill-path>`
   - If the knowledge cache was stale or missing (Phase 1 Step 1 fell through to Step 2): suggest `Run /claudit:refresh periodically to speed up future audits`

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
- **Modularization**: Move instructions from monolithic CLAUDE.md to `.claude/rules/` or subdirectory files
- **Cross-scope cleanup**: Remove project-specific instructions from personal config (apply directly, never via PR)
- **@import fixes**: Remove broken imports, fix circular references

**Scope safety for fixes:**
- Project-scoped files (CLAUDE.md, .claude/settings.json, .claude/rules/): eligible for direct edit and PR
- `CLAUDE.local.md`: edit directly, never include in PR (it's gitignored/personal)
- `.claude/settings.local.json`: edit directly, never include in PR (it's personal/local)
- `~/.claude/` files: edit directly, never include in PR (they're personal)

### Capture Decisions

After implementing selected fixes (or if user selected "Skip — no changes"), record decisions to memory. Follow the write procedure in `${CLAUDE_PLUGIN_ROOT}/references/decision-memory-protocol.md`.

**If the user selected specific recommendations (not "Skip"):**

1. Record each **selected** recommendation as `action: "accepted"` with its computed fingerprint
2. For **unselected** recommendations (items the user did not select), present a single follow-up AskUserQuestion:

   ```
   Some recommendations were not selected. How should claudit treat them in future audits?
   ```

   Use `multiSelect: true` with options for each unselected recommendation:
   - `"<recommendation>" — Rejected (intentional / false positive)`
   - `"<recommendation>" — Deferred (will address later)`

   Include a `"Don't record — treat as new next time"` option.

   - If 3 or fewer items are marked as rejected, ask a follow-up for optional reasons (single AskUserQuestion with text per item)
   - Record rejected/deferred items with their respective actions

3. For each decision, populate:
   - `fingerprint`: computed in the annotation step
   - `decided_by`: **GIT_USER** from Phase 0
   - `timestamp`: current ISO 8601 timestamp
   - `context`: current claudit version, Claude Code version, score impact

4. Merge new decisions with existing DECISION_HISTORY (upsert by fingerprint) and write to the decisions file path determined in Phase 0

**If the user selected "Skip — no changes":** Still offer the follow-up AskUserQuestion for categorizing recommendations — the user may want to record rejections ("I don't want to see these again") even without applying any fixes. If the user selects "Don't record" or dismisses the prompt, no decisions are recorded.

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

## Phase 5: PR Delivery

Read `${CLAUDE_PLUGIN_ROOT}/skills/claudit/references/pr-delivery.md` and follow the PR delivery instructions.

---

## Error Handling

- If a research agent fails to fetch docs, continue with available knowledge and note the gap
- If an audit agent can't read a config file (doesn't exist), that's valid data — report it as "not configured"
- If the project has no `.claude/` directory at all, focus the audit on global config and recommend project-level setup
- If no issues are found (score 90+), congratulate the user and suggest any new features to explore
- If Glob returns too many files (>50), cap and note the truncation

## Important Notes

- **Never auto-apply changes** — always present recommendations and let the user choose
- **Quote specific lines** when showing what would change in instruction files
- **Be opinionated** about over-engineering — this is the plugin's core value proposition
- **Show token savings** whenever removing content from instruction files or other config
- **The Expert Context makes this audit unique** — always highlight features the user isn't using yet
- **Respect scope boundaries** — project config is the team contract; personal config is personal
- **Only project-scoped files go in PRs** — CLAUDE.local.md and ~/.claude/ changes are always local-only
