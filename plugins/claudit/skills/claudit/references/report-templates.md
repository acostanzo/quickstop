# Claudit Report Templates

Presentation templates for the `/claudit` orchestrator: focus-argument mapping (Phase 0), the configuration map (Phase 0), the health report card (Phase 3), and the focus-mode report adjustments (Phase 3). The orchestrator reads this reference when it reaches those steps.

## Focus-Area Mapping

Match `$ARGUMENTS` as a whole string against this mapping (fuzzy — use judgment for synonyms and variations). Store the interpreted label as **FOCUS_AREA** and the relevant scoring categories as **FOCUS_CATEGORIES**.

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

**Plugin name matching** is deferred to Phase 0 Step 3.5 (after the config map is built), since it requires reading `installed_plugins.json`. At this step, only apply keyword matching from the table above. If no keyword matches, tentatively mark as free-form — Step 3.5 may reclassify it as a specific plugin.

## Configuration Map

Present the configuration map to the user:

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

Estimate tokens for instruction files as `(total_lines * 40) / 4` (rough: ~10 words/line, ~4 chars/word, ÷4 chars/token). This line-based estimate is for the config map display only; audit agents use `chars/4` for precise per-file counts after reading file contents. Show the aggregate token estimate for instruction files.

After presenting the map, if **FOCUS_MODE is true**, display:

```
Focus: {FOCUS_AREA}
  Primary categories: {FOCUS_CATEGORIES}
  Auditing all categories; {FOCUS_AREA}-related findings will include deeper analysis.
```

## Health Report Card

Display the report header showing detected scope and file count, then the per-category score bars:

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

For the visual bars, use `█` for filled and `░` for empty, scaled to 25 characters total; append the numeric score and letter grade. In global-only scope, render the CLAUDE.md Quality row as `CLAUDE.md Quality    skipped (no project detected)` instead of a score bar.

## Focus Mode Report Adjustments

If **FOCUS_MODE is true**, apply these adjustments to the report:

1. **Report header**: add a `Focus:` line inside the header box:
   ```
   ║  Focus: {FOCUS_AREA}                                    ║
   ```

2. **Score bars**: mark focus-relevant categories (from FOCUS_CATEGORIES) with a `◆` indicator:
   ```
   Over-Engineering  ◆  ████████████████████░░░░░  XX/100  X
   CLAUDE.md Quality ◆  ████████████████████░░░░░  XX/100  X
   Security Posture     ████████████████████░░░░░  XX/100  X
   ```

3. **Focus Deep Dive**: after the score card and before recommendations, add a **Focus Deep Dive** section consolidating all focus-related findings from every audit agent into a single narrative with specific file references, line numbers, and actionable detail.

4. **Findings order**: present focus-area findings and recommendations first, then other findings.
