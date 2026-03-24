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
| CLAUDE.md > 2500 tokens | -20 | Excessive verbosity consuming context budget (tiers are exclusive — apply highest matching only) |
| CLAUDE.md > 1500 tokens | -10 | Getting verbose, likely contains redundancy (not applied if >2500 tier matches) |
| Restated built-in behaviors | -10 each (max -30) | Instructions telling Claude what it already does |
| Prescriptive formatting rules | -5 each (max -15) | Over-specifying how Claude should format output |
| Redundant/duplicate instructions | -10 each (max -20) | Same instruction stated multiple ways |
| Instruction conflicts (within-file) | -15 each | Contradictory instructions within the same file (cross-file conflicts are scored under CLAUDE.md Quality, not here) |
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
| Individual file > 200 lines | -10 each (max -20) | Per Anthropic docs, instruction files should be under 200 lines |
| Duplicated instructions across project files | -5 each (max -25) | Same instruction in root ↔ subdirectory or root ↔ rules (within project scope only, never cross-scope) |
| Conflicting instructions across project files | -15 each | Contradictory instructions between project instruction files (same scope only) |
| Broken `@import` references | -10 each (max -20) | `@path/to/file` references pointing to files that don't exist |
| `@import` depth > 3 levels | -5 | Import chains deeper than 3 levels add complexity; hard limit is 5 but shallow trees (<=3) are preferred for maintainability |
| Circular `@imports` | -15 | Import cycle detected in instruction files |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Well-structured sections | +10 | Clear headings, logical flow |
| Links to reference files | +5 | Points to docs instead of embedding |
| Project-specific conventions only | +5 | Doesn't repeat general knowledge |
| Effective `.claude/rules/` usage | +10 | Path-specific rules with proper frontmatter scoping |
| Good file decomposition | +5 | Subdirectory CLAUDE.md files scoped to their domain |
| Clean `@import` tree | +5 | All imports valid, no circular refs, depth <= 3 (bonus threshold is stricter than the hard limit of 5 to reward shallow, maintainable import trees) |

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
| Total config > 5000 tokens | -20 | Combined config consuming too much context (tiers are exclusive — apply highest matching only) |
| Total config > 3000 tokens | -10 | Getting heavy (not applied if >5000 tier matches) |
| Aggregate instruction files > 8000 tokens | -15 | All CLAUDE.md + rules files combined are very large (tiers are exclusive) |
| Aggregate instruction files > 5000 tokens | -10 | All CLAUDE.md + rules files combined are getting heavy (not applied if >8000 tier matches) |
| Redundant memory entries | -10 | MEMORY.md duplicating CLAUDE.md |
| Large hook output | -10 | Hooks producing verbose output consumed as context |
| Unused skill/agent definitions | -5 each | Loaded but never triggered |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Lean total config | +10 | Under 1500 tokens total |
| Effective memory usage | +5 | MEMORY.md complements (not duplicates) CLAUDE.md |
| Minimal loaded context | +5 | Only what's needed is loaded |
| On-demand-only subdirectory files | +5 | Good architecture — subdirectory CLAUDE.md files load only when needed, not always |

## Issue Type Slugs for Decision Fingerprinting

Each rubric deduction maps to a normalized slug used in decision fingerprints (`{category_slug}:{issue_type}:{file_stem}:{hash}`).

| Category Slug | Issue Type Slug | Rubric Deduction |
|---------------|----------------|------------------|
| `over-engineering` | `verbose-claudemd-2500` | CLAUDE.md > 2500 tokens |
| `over-engineering` | `verbose-claudemd-1500` | CLAUDE.md > 1500 tokens |
| `over-engineering` | `restated-builtin` | Restated built-in behaviors |
| `over-engineering` | `prescriptive-formatting` | Prescriptive formatting rules |
| `over-engineering` | `redundant-instructions` | Redundant/duplicate instructions |
| `over-engineering` | `instruction-conflict` | Instruction conflicts (within-file) |
| `over-engineering` | `permission-over-spec` | Permission over-specification |
| `over-engineering` | `hook-sprawl` | Hook sprawl |
| `over-engineering` | `mcp-sprawl` | MCP server sprawl |
| `over-engineering` | `legacy-commands` | Legacy commands/ dirs |
| `over-engineering` | `fighting-style` | Fighting Claude's style |
| `claudemd-quality` | `missing-claudemd` | Missing entirely |
| `claudemd-quality` | `no-project-context` | No project context |
| `claudemd-quality` | `no-build-commands` | No build/test commands |
| `claudemd-quality` | `stale-reference` | Stale file references |
| `claudemd-quality` | `no-directory-structure` | No directory structure |
| `claudemd-quality` | `embedded-docs` | Embeds full API docs |
| `claudemd-quality` | `includes-secrets` | Includes secrets/keys |
| `claudemd-quality` | `file-over-200-lines` | Individual file > 200 lines |
| `claudemd-quality` | `cross-file-duplication` | Duplicated instructions across project files |
| `claudemd-quality` | `cross-file-conflict` | Conflicting instructions across project files |
| `claudemd-quality` | `broken-import` | Broken @import references |
| `claudemd-quality` | `import-depth` | @import depth > 3 levels |
| `claudemd-quality` | `circular-import` | Circular @imports |
| `security` | `full-auto-mode` | full-auto permission mode |
| `security` | `secrets-in-config` | Secrets in config files |
| `security` | `broad-bash-allow` | Overly broad Bash(*) allow |
| `security` | `no-permission-config` | No permission config at all |
| `security` | `sensitive-paths` | Sensitive paths in allowedTools |
| `mcp-config` | `missing-binary` | Missing binary for server |
| `mcp-config` | `duplicate-functionality` | Duplicate functionality |
| `mcp-config` | `unused-server` | Unused servers |
| `mcp-config` | `wrong-mcp-location` | No .mcp.json when MCP used |
| `mcp-config` | `missing-env-isolation` | Server without env isolation |
| `plugin-health` | `missing-install-path` | Plugin install path missing |
| `plugin-health` | `legacy-commands-structure` | Legacy commands/ structure |
| `plugin-health` | `missing-plugin-fields` | Missing plugin.json fields |
| `plugin-health` | `stale-plugin-version` | Stale plugin versions |
| `plugin-health` | `disabled-but-loaded` | Disabled but loaded plugins |
| `context-efficiency` | `config-over-5000` | Total config > 5000 tokens |
| `context-efficiency` | `config-over-3000` | Total config > 3000 tokens |
| `context-efficiency` | `instructions-over-8000` | Aggregate instruction files > 8000 tokens |
| `context-efficiency` | `instructions-over-5000` | Aggregate instruction files > 5000 tokens |
| `context-efficiency` | `redundant-memory` | Redundant memory entries |
| `context-efficiency` | `large-hook-output` | Large hook output |
| `context-efficiency` | `unused-skill-agent` | Unused skill/agent definitions |

For "Features to adopt" recommendations (not deductions), use issue type `feature-adoption` with the category slug of the most relevant category.

## Decision Annotation Format

When decision memory is available, annotate recommendations in the health report:

```
[N] Recommendation label  (+X pts Category)
    Previously rejected (YYYY-MM-DD, user): "reason"
    ⚠ Config changed since decision — recommend re-evaluating
```

Annotation prefixes:
- No annotation → new recommendation (first time seen)
- `Previously accepted` → issue recurred after being fixed (regression)
- `Previously rejected` → user intentionally declined, with their reason
- `Previously: alternative approach` → user took a different path
- `Deferred` → user planned to address later
- `⚠` prefix → decision is stale (with specific reason)

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
