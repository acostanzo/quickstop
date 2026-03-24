# Claudit

Audit and optimize your Claude Code configuration with dynamic best-practice research.

## What It Does

Claudit performs a comprehensive, research-backed audit of your Claude Code setup. It first builds expert knowledge from Anthropic's official documentation, then evaluates your configuration against that knowledge — identifying issues, over-engineering, and features you're not using yet.

### Key Innovations

- **Recursive CLAUDE.md discovery**: Finds and audits all instruction files — root, subdirectory, `.claude/rules/`, `CLAUDE.local.md`, and `@import` references
- **Automatic scope detection**: Detects whether you're in a project or not, audits everything relevant without prompting
- **Research-first architecture**: Subagents fetch official Anthropic docs before analysis begins, ensuring the audit knows the full landscape of what's possible — not just what you already have configured
- **Over-engineering detection**: Identifies where configuration complexity actively hurts performance. Claude does the heavy lifting; verbose CLAUDE.md files, excessive hooks, and MCP sprawl get in the way
- **Cross-scope analysis**: Detects redundancy between personal and project config, with nuanced cleanup recommendations
- **PR-based delivery**: Optionally commits changes to a branch and opens a PR with educational inline comments that teach your team Claude Code features
- **Persistent memory**: Research agents remember findings across audit runs, getting faster and more accurate over time

## Video Walkthrough

[![I Audited My Claude Code Config and Found 32% Was Wasted](https://i.ytimg.com/vi/HJvtgldlzDI/hqdefault.jpg)](https://www.youtube.com/watch?v=HJvtgldlzDI)

[**I Audited My Claude Code Config and Found 32% Was Wasted**](https://www.youtube.com/watch?v=HJvtgldlzDI) by [Damian Galarza](https://www.youtube.com/@damian.galarza)

## Usage

```
/claudit
```

Or focus on a specific area for a deeper dive:

```
/claudit MCP
/claudit CLAUDE.md
/claudit hooks
/claudit security
/claudit my-plugin
```

When a focus area is provided, audit agents still perform their full scope but go deeper on the focus area — more edge cases, line-level detail, and specific fix suggestions. The health report highlights focus-relevant scoring categories with a `◆` marker and presents a consolidated Focus Deep Dive section.

With no arguments, claudit runs a full audit as usual.

The audit runs through 6 phases:

0. **Configuration Map** — Discovers all Claude-related files (instructions, rules, settings, skills, agents, memory, MCP) and presents a structured map
1. **Build Expert Context** — 3 research agents fetch official Anthropic documentation in parallel
2. **Expert-Informed Audit** — Audit agents analyze your global, project, and ecosystem config against expert knowledge (each receives only its relevant slice of the config map)
3. **Scoring & Synthesis** — 6 categories scored with visual health report and ranked recommendations
4. **Interactive Enhancement** — Select which recommendations to apply; changes implemented with before/after scoring
5. **PR Delivery** — Optionally open a PR with educational inline comments, or keep as local edits

## Scope Selection

Claudit automatically detects scope based on context:

- **Inside a git repo** → Comprehensive audit (project + global config)
- **Outside a git repo** → Global-only audit

No prompting needed — just run `/claudit` and it does the right thing.

## What Gets Analyzed

### Project Configuration (comprehensive scope)
- **All CLAUDE.md files** — root, subdirectory, and `CLAUDE.local.md`
- **`.claude/rules/*.md`** — modular rules with YAML frontmatter validation
- **`@import` references** — resolution, broken links, circular detection
- **Cross-file analysis** — duplication, conflicts, architecture assessment
- **Settings** — `.claude/settings.json` and `.claude/settings.local.json`
- **Skills & agents** — `.claude/skills/`, `.claude/agents/`
- **Memory** — `.claude/MEMORY.md`

### Global Configuration (always)
- **`~/.claude/settings.json`** — settings fields, model config, `claudeMdExcludes`
- **`~/.claude/plugins/installed_plugins.json`** — plugin versions, install paths, health
- **User-level instructions** — `~/.claude/CLAUDE.md`, `~/.claude/rules/`
- **Managed policy** — `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS)
- **Memory** — `~/.claude/MEMORY.md`

### Ecosystem
- **MCP servers** — binary health, duplicate functionality, context cost
- **Plugins** — structure, legacy patterns, version currency
- **Hooks** — event types, matchers, timeouts, redundancy

### Cross-Scope Analysis (comprehensive only)
- Detects personal config that duplicates project-specific instructions (recommends removing from personal)
- Preserves general preferences in personal config (informational only)

## PR Delivery

When fixes are applied, Claudit can open a PR with educational inline comments:

- Each comment explains **what changed**, **why it matters**, the **Claude Code feature** involved, a **link to docs**, and the **score impact**
- Only project-scoped files are included (never `CLAUDE.local.md` or `~/.claude/` files)
- Requires `gh` CLI — falls back gracefully to local edits if unavailable

## Scoring System

| Category | Weight | What It Measures |
|----------|--------|------------------|
| Over-Engineering Detection | 20% | Unnecessary complexity, verbosity, redundancy |
| CLAUDE.md Quality | 20% | Structure, conciseness, multi-file quality, imports |
| Security Posture | 15% | Permission hygiene, secrets exposure |
| MCP Configuration | 15% | Server health, tool sprawl |
| Plugin Health | 15% | Version currency, structure patterns |
| Context Efficiency | 15% | Token budget, aggregate instruction size, memory usage |

### Grades

| Grade | Score | Label |
|-------|-------|-------|
| A+ | 95-100 | Exceptional |
| A | 90-94 | Excellent |
| B | 75-89 | Good |
| C | 60-74 | Fair |
| D | 40-59 | Needs Work |
| F | 0-39 | Critical |

## Decision Memory

Claudit remembers what you decided about its recommendations. When you accept, reject, or defer a recommendation, that decision is stored in `.claude/claudit-decisions.json` (project scope) or `~/.cache/claudit/decisions.json` (global scope).

On future runs, claudit annotates recommendations with past decisions:

```
[2] Trim CLAUDE.md redundancy  (+15 pts Over-Engineering)
    Previously rejected (2026-02-15, acostanzo): "Team onboarding — keeping for junior devs"
    ⚠ Config changed since decision — recommend re-evaluating
```

**Key principles:**

- **Context, not constraints** — past decisions annotate recommendations but never suppress them
- **Staleness detection** — decisions are flagged for re-evaluation when config changes, Claude Code updates, score impact shifts, or 90 days pass
- **Team-shared** — project decisions are committable so teammates see why deviations from best practice were intentional
- **Fingerprint matching** — recommendations are matched to past decisions via a composite key (category, issue type, file, content hash)

## Persistent Memory

Research agents use `memory: user` to persist findings across runs. The first audit fetches all documentation from scratch. Subsequent runs consult cached knowledge and only update what may have changed — making them faster and more accurate over time.

## Requirements

- Claude Code CLI
- Internet access (for Phase 1 documentation fetching)
- `gh` CLI (optional, for PR delivery)

## Installation

From the quickstop marketplace:

```bash
/plugin install claudit@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/claudit
```
