# Hone Scoring Rubric

## Overview

Each category starts at a base score of **100** and has deductions applied for issues found. Bonuses are awarded for quality that goes beyond baseline. The overall quality score is a weighted average of all categories.

## Categories & Shares

Shares are stored here; effective weights are computed at scoring time via share-based renormalization (see Scoring Algorithm). Non-sibling total share = 100 (Pronto Compliance excluded). Sibling total share = 110 (Pronto Compliance included).

| Category | Share | What It Measures |
|----------|-------|------------------|
| Skill Quality | 20 | Frontmatter, instructions, phases, argument handling |
| Structure Compliance | 15 | Directory layout, required files, naming conventions |
| Agent Quality | 15 | Frontmatter, tool lists, model selection, instruction clarity |
| Metadata Quality | 10 | plugin.json, marketplace.json, version consistency |
| Hook Quality | 10 | Event types, timeouts, matchers, no duplication, ADR-006 §3 |
| Documentation | 10 | README quality, inline docs, usage examples, ADR-006 §1 |
| Over-Engineering | 10 | Agent sprawl, verbose instructions, unnecessary complexity |
| Security | 10 | Secrets scan, tool restrictions, permission scope, ADR-006 §2 |
| Pronto Compliance | 10 | Sibling-shape compliance — ADR-004/005 wire contract, :audit skill (sibling-only) |

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

## Category: Skill Quality (20%)

**What:** SKILL.md files — frontmatter correctness, instruction quality, phase organization, argument handling.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing SKILL.md | -50 | Skill directory exists but no SKILL.md |
| Missing `name` frontmatter | -20 | Required field |
| Missing `description` frontmatter | -20 | Required field |
| `name` doesn't match directory | -10 | Naming mismatch |
| Missing `$ARGUMENTS` when `argument-hint` set | -10 | Accepts args but never uses them |
| No phase structure in complex skill | -15 | Multi-step skills should have clear phases |
| Vague instructions | -10 each (max -20) | Instructions too ambiguous to follow reliably |
| Missing error handling guidance | -5 | No guidance for when things go wrong |
| Overly broad `allowed-tools` | -5 | Lists tools never referenced in instructions |
| Missing `allowed-tools` on complex skill | -5 | Complex skills should restrict tool access |
| `disable-model-invocation` missing on internal skill | -5 | Internal-only skills should disable auto-invocation |
| References non-existent reference files | -10 each | Broken `${SKILL_ROOT}` or `${CLAUDE_PLUGIN_ROOT}` paths |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Clear phase organization | +10 | Well-structured multi-phase flow |
| Effective reference file usage | +5 | Heavy content in references/, not inline |
| Appropriate `disable-model-invocation` | +5 | Correctly applied to internal-only skills |
| Good argument handling | +5 | Clean `$ARGUMENTS` parsing with validation |

## Category: Structure Compliance (15%)

**What:** Directory layout, required vs optional files, legacy pattern detection.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing `.claude-plugin/plugin.json` | -50 | Required file |
| Missing `README.md` | -15 | Every plugin should have docs |
| Using `commands/` instead of `skills/` | -15 | Legacy pattern, should use `skills/` |
| Both `commands/` and `skills/` present | -10 | Mixed patterns, confusing |
| Empty directories | -5 each | Directories with no content |
| Files outside standard directories | -5 each | Loose files not in skills/, agents/, hooks/, etc. |
| Agent files not in `agents/` | -10 | Agents should be in the agents/ directory |
| Non-kebab-case naming | -5 each | Files/dirs should use kebab-case |
| Missing `references/` for reference-heavy skill | -5 | Inline content that should be in references/ |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Clean, minimal structure | +10 | Only directories that are used |
| Proper references/ usage | +5 | Reference files for heavy content |
| No legacy patterns | +5 | Fully migrated to current conventions |

## Category: Agent Quality (15%)

**What:** Agent .md files — frontmatter, tool lists, model selection, instruction clarity.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing `name` frontmatter | -20 | Required field |
| Missing `description` frontmatter | -20 | Required field |
| Missing `tools` frontmatter | -20 | Required field |
| Overly broad tool list | -10 | Agent has tools it never needs |
| Missing tool that instructions reference | -10 each | Instructions mention tools not in the list |
| No model specified | -5 | Should explicitly choose model |
| `opus` model for simple tasks | -10 | Expensive model for work haiku/sonnet could do |
| Vague instructions | -10 each (max -20) | Instructions too ambiguous |
| No output format specified | -10 | Agent should define its return format |
| Missing budget/scope constraints | -5 | No limits on how much the agent does |
| Agent duplicates another agent's purpose | -15 | Redundant agents |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Appropriate model selection | +10 | Right model for the complexity |
| Minimal, precise tool list | +5 | Only tools actually needed |
| Clear output format | +5 | Well-defined return structure |
| Good budget constraints | +5 | Explicit limits on fetches, reads, etc. |

## Category: Metadata Quality (10%)

**What:** plugin.json completeness, marketplace version consistency, semver validity.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing `name` in plugin.json | -30 | Required field |
| Missing `version` in plugin.json | -30 | Required field |
| Missing `description` in plugin.json | -20 | Required field |
| Invalid semver | -15 | Version doesn't follow semver format |
| Version mismatch: plugin.json vs marketplace.json | -20 | Must match |
| Version mismatch: plugin.json vs README.md | -10 | Should match |
| Missing `source` in marketplace.json | -10 | Required for installation |
| Missing `keywords` in marketplace.json | -5 | Helps discovery |
| Missing `author` in plugin.json | -5 | Recommended field |
| Description mismatch between plugin.json and marketplace | -5 | Should be consistent |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| All three versions match | +10 | plugin.json, marketplace.json, README |
| Complete author info | +5 | Name and URL |
| Good keyword coverage | +5 | Relevant, non-redundant keywords |

## Category: Hook Quality (10%)

**What:** Hook definitions — event types, timeouts, matchers, no duplication of built-in behavior, ADR-006 §3 invariants.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing timeout | -10 each | All hooks should have explicit timeouts |
| Timeout > 60000ms | -5 each | Excessively long timeouts |
| Duplicate built-in behavior | -15 each | Hooks doing what Claude already does |
| Overly broad matcher | -10 | Matcher catches too many tools |
| Missing matcher on Pre/PostToolUse | -5 | Should filter to relevant tools |
| Invalid event type | -20 | Event type not in Claude Code spec |
| Hook command not found | -15 | Command binary doesn't exist |
| No hooks when plugin has complex behavior | -5 | May benefit from hooks |

#### ADR-006 §3 Hook Invariant Deductions

| Issue | Points | Severity | Description |
|-------|--------|----------|-------------|
| Hook returns `updatedInput`, `updatedOutput`, `decision`, `behavior`, or `permissionDecision` | -25 each (max -50) | Critical | ADR-006 §3 invariant 1 — payload/flow mutation |
| Hook installs persistent host state (`npm install`, `brew install`, `pip install`, `cargo install`, `go install`, `systemctl enable`, `launchctl load`, `sudo`) | -15 each (max -30) | High | ADR-006 §3 invariant 2 |
| Hook writes to Tier 1 literal paths (`/etc/`, `/usr/local/`, `~/.bashrc`, `~/.zshrc`, `~/.gitconfig`, `~/.profile`) | -15 each (max -30) | High | ADR-006 §3 invariant 3 — undeclared write |
| `hooks/hooks.json` declares an event with no corresponding script | -5 each | Low | Manifest drift |

ADR-006 §3 deductions stack with existing Hook Quality deductions. Category score is floored at 0 after stacking.

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| All hooks have timeouts | +10 | Explicit timeout on every hook |
| Precise matchers | +5 | Narrow, well-targeted matchers |
| Hooks serve unique purposes | +5 | No overlap with built-in behavior |

**No hooks = neutral (100):** If a plugin has no hooks and doesn't need them, score stays at 100. ADR-006 §3 deductions and manifest-drift deduction are skipped when no `hooks/` directory is present.

## Category: Documentation (10%)

**What:** README quality, usage examples, installation instructions, ADR-006 §1 surface declaration.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing README.md | -30 | Every plugin needs docs |
| No description in README | -10 | What does this plugin do? |
| No installation instructions | -10 | How to install |
| No usage examples | -10 | How to use commands |
| No command/skill listing | -10 | What commands are available? |
| Stale version in README | -10 | Doesn't match plugin.json |
| README > 500 lines | -5 | Over-documented |

#### ADR-006 §1 Surface Declaration Deductions

| Issue | Points | Severity | Description |
|-------|--------|----------|-------------|
| README missing "Plugin surface" section | -5 | Low | ADR-006 §1 — capability enumeration |
| Hooks declared in `hooks/hooks.json` but absent from README's surface enumeration | -5 each (max -15) | Low | ADR-006 §1 visibility |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Clear, concise README | +10 | Good structure, right level of detail |
| Architecture overview | +5 | Explains how components fit together |
| Troubleshooting section | +5 | Common issues and fixes |

## Category: Over-Engineering (10%)

**What:** Unnecessary complexity, agent sprawl, verbose instructions.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Agent sprawl (>6 agents) | -15 | Too many agents for the task |
| Agent that could be inline logic | -10 each | Simple tasks don't need dedicated agents |
| Skill instructions > 400 lines | -15 | Excessively verbose |
| Agent instructions > 200 lines | -10 | Agents should be focused |
| Duplicate logic across agents | -10 | Same checks in multiple agents |
| Unnecessary hook complexity | -10 | Hooks doing what skills could handle |
| Over-parameterized (many optional features) | -5 | YAGNI — features no one uses |
| Reference files > 300 lines each | -5 each | Reference content too heavy |

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Minimal agent count | +10 | Fewest agents needed for the job |
| Focused, concise instructions | +5 | Short, clear, unambiguous |
| Good skill/agent boundary | +5 | Clean separation of orchestration vs work |
| Deferred loading patterns | +5 | Reference files loaded on demand |

## Category: Security (10%)

**What:** Secrets in files, tool restrictions, permission scope, ADR-006 §2 silent consumer-artefact mutation.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Secrets in any file | -30 each | API keys, tokens, passwords in code/config |
| Agents with unrestricted Bash | -15 | Agents should have scoped tool access |
| No `allowed-tools` on skills with Bash | -10 | Skills using Bash should restrict scope |
| Hardcoded file paths outside project | -5 each | Potential info leakage |
| Environment variables with secrets in hooks | -10 | Secrets in hook commands |
| Write/Edit tools on agents that should be read-only | -10 | Audit agents shouldn't modify files |

#### ADR-006 §2 Consumer-Artefact Mutation Deductions

These deductions apply to **Scope A (automatic execution paths)** only. Scope B matches (user-invoked skills) are informational — no deduction.

| Issue | Points | Severity | Description |
|-------|--------|----------|-------------|
| Plugin code (Scope A) calls `gh pr edit --body-file/-F/-B` | -25 each | Critical | ADR-006 §2 — silent PR-body mutation |
| Plugin code (Scope A) calls `git config --global` | -25 each | Critical | ADR-006 §2 — consumer config mutation |
| Plugin code (Scope A) calls `gh repo edit` | -25 each | Critical | ADR-006 §2 — consumer repo mutation |
| Plugin code (Scope A) calls `gh release create` or `gh release edit` | -25 each | Critical | ADR-006 §2 — consumer release mutation |

False-positive guard: matches inside README fenced code blocks (documented examples) are noted but never deducted.

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Clean secrets scan | +10 | No secrets found anywhere |
| Appropriate tool restrictions | +5 | Each agent has minimal needed tools |
| Read-only audit agents | +5 | Audit agents can't modify files |

## Category: Pronto Compliance (share: 10, sibling-only)

**What:** Sibling-shape compliance with ADR-004 / ADR-005 — wire contract, `:audit` skill, parser agent state, version handshake.

**When applicable:** Plugin is detected as a sibling (pronto block in `plugin.json` OR listed as `recommended_plugin` in `recommendations.json`). Non-sibling plugins skip this category entirely — it does not score 100 neutral; it is excluded from the rubric for those plugins.

Findings come from `audit-pronto`. Source: `audit-pronto`.

### Deductions

| Issue | Points | Description |
|-------|--------|-------------|
| Missing `compatible_pronto` | -20 | ADR-004 §2 soft finding |
| Missing `audits[]` | -30 | No rubric participation declaration |
| Off-canonical dimension | -15 each | Dimension not in `recommendations.json` |
| Missing `skills/audit/SKILL.md` | -25 | Step-1 discovery broken |
| `:audit` frontmatter incomplete | -5 each (max -15) | Missing required field (name, disable-model-invocation, argument-hint) |
| `$ARGUMENTS` not parsed | -10 | Skill ignores invocation flags (presence-gated: skip if audit skill absent) |
| stdout contains human-readable text | -15 | Wire contract violation (presence-gated: skip if audit skill absent) |
| No `$schema_version: 2` marker | -10 | Pre-H3 emission (presence-gated: skip if audit skill absent) |
| No `observations[]` emission | -15 | Legacy `score`-only emission (presence-gated: skip if audit skill absent) |
| Hardcoded `composite_score` | -10 | Should be null or computed (presence-gated: skip if audit skill absent) |
| Parser agent not deprecated when step-1 active | -5 | Discovery ambiguity |
| `compatible_pronto` floor >2 minor versions stale | -10 | Skew risk |

**Presence-gated deductions:** When `skills/audit/SKILL.md` is absent (the -25 deduction fires), deductions that check the skill body (`$ARGUMENTS` not parsed, stdout mix, `$schema_version`, `observations[]`, `composite_score`) are **not stacked** — the missing-skill finding subsumes them.

### Bonuses

| Optimization | Points | Description |
|-------------|--------|-------------|
| Clean wire-contract emission | +10 | All schema-2 fields emitted correctly |
| `:doctor` skill present | +5 | Optional self-health surface |
| All audit dimensions in canonical list | +5 | Plays well with the registry |

## Categories Reference Table

| Category | Share | Effective weight (sibling) | Effective weight (non-sibling) |
|----------|-------|----------------------------|-------------------------------|
| Skill Quality | 20 | 18.2% | 20% |
| Structure Compliance | 15 | 13.6% | 15% |
| Agent Quality | 15 | 13.6% | 15% |
| Metadata Quality | 10 | 9.1% | 10% |
| Hook Quality | 10 | 9.1% | 10% |
| Documentation | 10 | 9.1% | 10% |
| Over-Engineering | 10 | 9.1% | 10% |
| Security | 10 | 9.1% | 10% |
| **Pronto Compliance** | **10** | **9.1%** | — (excluded) |
| **Total** | **110 / 100** | **100%** | **100%** |

## Scoring Algorithm

```
For each applicable category:
  1. Start at 100
  2. Apply all matching deductions (sum cannot go below 0)
  3. Apply all matching bonuses (sum cannot exceed 100)
  4. category_score = max(0, min(100, 100 - deductions + bonuses))

Overall score (share-based renormalization):
  total_share = sum(share_i for all applicable categories)
  effective_weight_i = share_i / total_share
  overall = sum(category_score_i * effective_weight_i for all applicable categories)
  overall_grade = lookup grade threshold table

where applicable categories are:
  - all 9 (including Pronto Compliance, total_share = 110) when sibling detected
  - the original 8 (excluding Pronto Compliance, total_share = 100) when non-sibling

For non-sibling plugins total_share = 100, so effective_weight_i = share_i / 100,
which is identical to today's weights. Non-sibling scoring is byte-equivalent.

For sibling plugins total_share = 110, so each effective_weight = share_i / 110 —
approximately 9% less than its original percentage, with Pronto Compliance filling
the slack.
```

## Report Format

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
[Pronto Compliance   ████████████████████░░░░░  XX/100  X  ← sibling plugins only]
```

Show 8 bars for non-sibling plugins; 9 bars (Pronto Compliance appended at bottom) for sibling plugins.

## Recommendation Ranking

| Priority | Impact | Action Type |
|----------|--------|-------------|
| Critical | > 20 pts | Must fix — actively harming plugin quality |
| High | 10-20 pts | Should fix — significant improvement potential |
| Medium | 5-9 pts | Nice to have — incremental improvement |
| Low | < 5 pts | Optional — minor polish |

Include both:
1. **Issues to fix** — problems found in current plugin
2. **Patterns to adopt** — best practices from Expert Context not currently used

## Scope-Aware Scoring

If a plugin has no component for a category, that category scores neutral (100) rather than penalizing:
- No hooks → Hook Quality = 100
- No agents → Agent Quality = 100 (unless the plugin clearly needs agents)
- No skills → Skill Quality is still scored (every plugin should have at least one skill)
