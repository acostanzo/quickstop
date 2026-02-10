# Claudit Scoring Rubric

## Overview

Each category starts at a base score of **100** and has deductions applied for issues found. Bonuses are awarded for optimizations that go beyond baseline. The overall health score is a weighted average of all categories.

## Categories & Weights

| Category | Weight | What It Measures |
|----------|--------|------------------|
| Over-Engineering Detection | 20% | Unnecessary complexity, verbosity, redundancy |
| CLAUDE.md Quality | 20% | Structure, conciseness, relevance, token efficiency |
| Security Posture | 15% | Permission hygiene, secrets exposure, tool restrictions |
| MCP Configuration | 15% | Server health, tool sprawl, unused servers |
| Plugin Health | 15% | Version currency, structure, legacy patterns |
| Context Efficiency | 15% | Token budget awareness, memory usage, config bloat |

## Grade Thresholds

| Grade | Score Range | Label |
|-------|-------------|-------|
| A+ | 95-100 | Exceptional |
| A | 90-94 | Excellent |
| B | 75-89 | Good |
| C | 60-74 | Fair |
| D | 40-59 | Needs Work |
| F | 0-39 | Critical |

## Visual Score Bar

Use this format for displaying scores:

```
Category Name        ████████████████████░░░░░  82/100  B
```

- `█` for filled portion (score/100 * 25 chars)
- `░` for remaining
- Score value and letter grade

## Category: Over-Engineering Detection (20%)

**Philosophy:** Claude does the heavy lifting. Less is more. Verbose instructions, excessive hooks, and complex permission rules actively hurt performance by consuming context and fighting Claude's natural capabilities.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| CLAUDE.md > 2500 tokens | -20 | Excessive verbosity consuming context budget |
| CLAUDE.md > 1500 tokens | -10 | Getting verbose, likely contains redundancy |
| Restated built-in behaviors | -10 each (max -30) | Instructions telling Claude what it already does |
| Prescriptive formatting rules | -5 each (max -15) | Over-specifying how Claude should format output |
| Redundant/duplicate instructions | -10 each (max -20) | Same instruction stated multiple ways |
| Instruction conflicts | -15 each | Contradictory instructions |
| Permission over-specification | -15 | Dozens of granular rules when a mode would suffice |
| Hook sprawl | -10 | Hooks duplicating built-in behavior |
| MCP server sprawl | -10 | Servers configured but rarely/never used |
| Legacy `commands/` dirs | -5 each | Should be migrated to `skills/` |
| Fighting Claude's style | -10 each (max -20) | Instructions that contradict Claude's natural approach |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Minimal, focused CLAUDE.md | +10 | Under 500 tokens with clear project context |
| Clean permission mode | +5 | Using permission mode instead of granular rules |
| No redundant hooks | +5 | All hooks serve unique purposes |

## Category: CLAUDE.md Quality (20%)

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing entirely | -50 | No CLAUDE.md at project level |
| No project context | -15 | Missing what the project is / tech stack |
| No build/test commands | -10 | Missing how to build or test |
| Stale file references | -10 each (max -20) | References to files that don't exist |
| No directory structure | -5 | Missing repo layout |
| Embeds full API docs | -15 | Should reference files, not embed |
| Includes secrets/keys | -30 | Secrets should never be in CLAUDE.md |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Well-structured sections | +10 | Clear headings, logical flow |
| Links to reference files | +5 | Points to docs instead of embedding |
| Project-specific conventions only | +5 | Doesn't repeat general knowledge |

## Category: Security Posture (15%)

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| `full-auto` permission mode | -20 | No guardrails on tool execution |
| Secrets in config files | -30 | API keys, tokens in settings or CLAUDE.md |
| Overly broad `Bash(*)` allow | -15 | Allows any bash command without review |
| No permission config at all | -10 | Relying entirely on defaults |
| Sensitive paths in allowedTools | -10 | Edit/Write access to system dirs |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Scoped bash permissions | +10 | Specific Bash(...) patterns for project commands |
| Path-scoped file access | +5 | Edit/Write restricted to project dirs |
| Thoughtful deny rules | +5 | Explicit deniedTools for dangerous operations |

## Category: MCP Configuration (15%)

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing binary for server | -20 each | Command not found on PATH |
| Duplicate functionality | -10 | Multiple servers providing same tools |
| Unused servers | -10 each | Configured but tools never invoked |
| No .mcp.json when MCP used | -5 | MCP config in wrong location |
| Server without env isolation | -5 | Missing env vars that server needs |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| All servers healthy | +10 | Every configured server has working binary |
| Minimal tool surface | +5 | Only servers that are actively used |

## Category: Plugin Health (15%)

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Plugin install path missing | -20 each | Plugin directory doesn't exist |
| Legacy `commands/` structure | -10 | Should use `skills/` |
| Missing plugin.json fields | -5 each | Incomplete plugin metadata |
| Stale plugin versions | -10 | Plugins significantly behind marketplace |
| Disabled but loaded plugins | -10 | Consuming context for no benefit |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| All plugins current | +10 | Versions match or exceed marketplace |
| Clean plugin structure | +5 | Uses current `skills/` + `agents/` patterns |

## Category: Context Efficiency (15%)

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Total config > 5000 tokens | -20 | Combined config consuming too much context |
| Total config > 3000 tokens | -10 | Getting heavy |
| Redundant memory entries | -10 | MEMORY.md duplicating CLAUDE.md |
| Large hook output | -10 | Hooks producing verbose output consumed as context |
| Unused skill/agent definitions | -5 each | Loaded but never triggered |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Lean total config | +10 | Under 1500 tokens total |
| Effective memory usage | +5 | MEMORY.md complements (not duplicates) CLAUDE.md |
| Minimal loaded context | +5 | Only what's needed is loaded |

## Scoring Algorithm

```
For each category:
  1. Start at 100
  2. Apply all matching deductions (sum cannot go below 0)
  3. Apply all matching bonuses (sum cannot exceed 100)
  4. category_score = max(0, min(100, 100 - deductions + bonuses))

Overall score:
  weighted_sum = Σ (category_score × category_weight)
  overall_grade = lookup grade threshold table
```

## Report Format

Present the health report as:

```
╔══════════════════════════════════════════════════════════╗
║                  CLAUDIT HEALTH REPORT                  ║
╠══════════════════════════════════════════════════════════╣
║  Overall Score: 78/100  Grade: B  (Good)                ║
╚══════════════════════════════════════════════════════════╝

Over-Engineering     ████████████████░░░░░░░░░  65/100  C
CLAUDE.md Quality    █████████████████████░░░░  85/100  B
Security Posture     ██████████████████████░░░  90/100  A
MCP Configuration    ████████████████████░░░░░  80/100  B
Plugin Health        ██████████████████░░░░░░░  70/100  C
Context Efficiency   █████████████████████░░░░  82/100  B
```

## Recommendation Ranking

Rank recommendations by impact score:

| Priority | Impact | Action Type |
|----------|--------|-------------|
| Critical | > 20 pts | Must fix - actively harming performance |
| High | 10-20 pts | Should fix - significant improvement potential |
| Medium | 5-9 pts | Nice to have - incremental improvement |
| Low | < 5 pts | Optional - minor polish |

Include both:
1. **Issues to fix** - Problems found in current config
2. **Features to adopt** - New capabilities from Expert Context the user isn't using
