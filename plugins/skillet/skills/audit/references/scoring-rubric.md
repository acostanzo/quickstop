# Skillet Scoring Rubric

## Overview

Each category starts at a base score of **100** and has deductions applied for issues found. Bonuses are awarded for quality that goes beyond baseline. The overall quality score is a weighted average of all categories.

## Categories & Weights

| Category | Weight | What It Measures |
|----------|--------|------------------|
| Frontmatter Correctness | 15% | Required fields, values match spec, name matches directory |
| Instruction Quality | 25% | Phase organization, clarity, error handling, argument handling |
| Agent Design | 15% | Frontmatter, model selection, tool scoping, output format |
| Directory Structure | 15% | Template compliance, reference usage, no loose files |
| Over-Engineering | 15% | Verbosity, restated built-ins, unnecessary agents |
| Reference & Tooling | 15% | Reference integrity, hook correctness, cross-references |

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

- Fill chars = round(score/100 * 25)
- Empty chars = 25 - fill chars
- Append numeric score and letter grade

## Category: Frontmatter Correctness (15%)

**What:** SKILL.md and agent frontmatter — required fields, valid values, naming consistency.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing `name` frontmatter | -20 | Required field for skills and agents |
| Missing `description` frontmatter | -20 | Required field for skills and agents |
| `name` doesn't match directory | -10 | Skill name must match its directory name |
| Missing `tools` on agent | -20 | Required field for agents |
| Invalid frontmatter field | -5 each | Fields not recognized by Claude Code |
| `argument-hint` set but no `$ARGUMENTS` usage | -10 | Accepts args but never uses them |
| Missing `allowed-tools` on complex skill | -5 | Complex multi-phase skills should restrict tools |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| All required fields present and valid | +5 | Clean frontmatter |
| Appropriate `disable-model-invocation` | +5 | Correctly applied based on skill purpose |

## Category: Instruction Quality (25%)

**What:** SKILL.md body — phase organization, clarity, error handling, argument handling.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| No phase structure in complex skill | -15 | Multi-step skills should have clear phases |
| Vague instructions | -10 each (max -20) | Instructions too ambiguous to follow reliably |
| Missing error handling guidance | -10 | No guidance for when things go wrong |
| `$ARGUMENTS` not parsed when `argument-hint` set | -10 | Accepts args but doesn't parse them |
| Missing input validation | -5 | No validation of user input or arguments |
| No user interaction points | -5 | Complex skills should confirm plans with user |
| Inconsistent phase numbering | -5 | Phases numbered incorrectly or skipped |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Clear phase organization | +10 | Well-structured multi-phase flow |
| Good argument handling | +5 | Clean `$ARGUMENTS` parsing with validation |
| Explicit error handling | +5 | Clear guidance for failure modes |
| User confirmation at key points | +5 | AskUserQuestion for plan approval |

## Category: Agent Design (15%)

**What:** Agent .md files — frontmatter, model selection, tool scoping, output format.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| `opus` model for simple tasks | -10 | Expensive model for work haiku/sonnet could do |
| Overly broad tool list | -10 | Agent has tools it never needs |
| Missing tool that instructions reference | -10 each | Instructions mention tools not in the list |
| No output format specified | -10 | Agent should define its return format |
| Missing budget/scope constraints | -5 | No limits on how much the agent does |
| Agent duplicates another agent's purpose | -15 | Redundant agents |
| Vague agent instructions | -10 each (max -20) | Instructions too ambiguous |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Appropriate model selection | +10 | Right model for the complexity |
| Minimal, precise tool list | +5 | Only tools actually needed |
| Clear output format | +5 | Well-defined return structure |
| Good budget constraints | +5 | Explicit limits on fetches, reads, etc. |

**No agents = neutral (100):** If a skill has no agents and doesn't need them, score stays at 100.

## Category: Directory Structure (15%)

**What:** Template compliance, reference usage, no loose files.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing SKILL.md | -50 | Skill directory exists but no SKILL.md |
| Agent .md inside skill directory | -10 | Agents should be in `agents/` at parent level |
| Loose files in skill directory | -5 each | Only SKILL.md and references/ allowed |
| Non-kebab-case naming | -5 each | Files/dirs should use kebab-case |
| Empty directories | -5 each | Directories with no content |
| Scripts inside skill directory | -5 | Scripts belong in `scripts/` |
| Missing `references/` for reference-heavy skill | -5 | Inline content that should be in references/ |
| Multiple hooks.json files | -10 | Hook config should be centralized |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Clean template compliance | +10 | Follows opinionated structure exactly |
| Proper references/ usage | +5 | Heavy content in references/, not inline |
| No legacy patterns | +5 | No `commands/` directory, fully migrated |

## Category: Over-Engineering (15%)

**What:** Verbosity, restated built-ins, unnecessary agents, complexity.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Skill instructions > 400 lines | -15 | Excessively verbose |
| Agent instructions > 200 lines | -10 | Agents should be focused |
| Restated built-in behaviors | -10 each (max -30) | Instructions telling Claude what it already does |
| Agent that could be inline logic | -10 each | Simple tasks don't need dedicated agents |
| Agent sprawl (>4 agents for a single skill) | -15 | Too many agents for the task |
| Reference files > 300 lines each | -5 each | Reference content too heavy |
| Over-parameterization | -5 | Features that add complexity without clear value |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Minimal agent count | +10 | Fewest agents needed for the job |
| Focused, concise instructions | +5 | Short, clear, unambiguous |
| Good skill/agent boundary | +5 | Clean separation of orchestration vs work |
| Deferred loading patterns | +5 | Reference files loaded on demand |

## Category: Reference & Tooling (15%)

**What:** Reference integrity, hook correctness, cross-references.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Broken `${SKILL_ROOT}` reference | -10 each (max -20) | Path doesn't resolve to existing file |
| Broken `${CLAUDE_PLUGIN_ROOT}` reference | -10 each (max -20) | Path doesn't resolve to existing file |
| Hook missing timeout | -10 each | All hooks should have explicit timeouts |
| Hook timeout > 60000ms | -5 each | Excessively long timeouts |
| Invalid hook event type | -20 | Event type not in Claude Code spec |
| Hook command not found | -15 | Command binary doesn't exist |
| Overly broad hook matcher | -10 | Matcher catches too many tools |
| Skill dispatches non-existent agent | -15 each | Agent type referenced doesn't exist |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| All references valid | +10 | Every path resolves to an existing file |
| All hooks have timeouts | +5 | Explicit timeout on every hook |
| Precise hook matchers | +5 | Narrow, well-targeted matchers |

**No hooks/references = neutral (100):** If neither is used, score stays at 100.

## Scoring Algorithm

```
For each category:
  1. Start at 100
  2. Apply all matching deductions (sum cannot go below 0)
  3. Apply all matching bonuses (sum cannot exceed 100)
  4. category_score = max(0, min(100, 100 - deductions + bonuses))

Overall score:
  weighted_sum = sum(category_score * category_weight for all categories)
  overall_grade = lookup grade threshold table
```

## Report Format

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

## Recommendation Ranking

| Priority | Impact | Action Type |
|----------|--------|-------------|
| Critical | > 20 pts | Must fix — actively harming skill quality |
| High | 10-20 pts | Should fix — significant improvement potential |
| Medium | 5-9 pts | Nice to have — incremental improvement |
| Low | < 5 pts | Optional — minor polish |

Include both:
1. **Issues to fix** — problems found in current skill
2. **Patterns to adopt** — best practices from Expert Context not currently used

## Scope-Aware Scoring

If a skill has no component for a category, that category scores neutral (100) rather than penalizing:
- No agents → Agent Design = 100
- No hooks or references → Reference & Tooling = 100
- No complex behavior → Over-Engineering bonuses apply freely
