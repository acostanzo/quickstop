# CLAUDE.md

Guidelines for Claude (or any AI assistant) working on the Pluggy project.

## Project Overview

Pluggy is a meta-plugin for Claude Code that provides expert plugin development guidance through specialized subagents. It's an intelligent consultant, not just a scaffolding tool.

## Core Philosophy

### Pluggy's Purpose

1. **Expert guidance** - Subagents with deep plugin ecosystem knowledge
2. **Interactive design** - Collaborative planning with users
3. **Comprehensive audits** - Thorough reviews, not just validation
4. **Best practices** - Guide users toward good patterns
5. **Ongoing help** - Not just generate-and-forget

### Design Principles

1. **Subagents over templates** - Launch experts, not copy files
2. **Ask questions** - Understand before building
3. **Be thorough** - Comprehensive reviews and plans
4. **Be helpful** - Provide fixes, not just problems
5. **Knowledge-rich** - Inject full plugin ecosystem knowledge

## Architecture

### Key Components

```
pluggy/
├── commands/
│   ├── audit.md      # Launches audit expert subagent
│   └── plan.md       # Launches planning expert subagent
├── docs/
│   └── plugin-knowledge.md   # Comprehensive plugin ecosystem guide
├── pluggy/
│   ├── scaffolder.py  # Code generation for final scaffolding
│   └── validator.py   # Basic validation utilities
└── test_pluggy.py
```

### How It Works

1. **User invokes command** (`/pluggy:audit` or `/pluggy:plan`)
2. **Command reads knowledge base** (`docs/plugin-knowledge.md`)
3. **Command launches Task** with subagent_type="general-purpose"
4. **Subagent has full context** on plugin ecosystem
5. **Subagent interacts with user** (asks questions, shows results)
6. **Subagent can scaffold** using pluggy.scaffolder

### The Knowledge Base

`docs/plugin-knowledge.md` is crucial. It contains:
- Complete plugin structure
- All manifest fields
- All 7 hook types with examples
- Command design patterns
- Skills and subagents
- Security best practices
- Common pitfalls
- Questions to ask when auditing/planning

This gets injected into every subagent session.

## Command Design

### Audit Command

**Purpose**: Launch expert to review a plugin thoroughly

**Flow**:
1. Determine plugin path
2. Read knowledge base
3. Launch subagent with:
   - Full plugin knowledge
   - Specific audit checklist
   - Output format requirements
4. Subagent explores plugin, finds issues, reports

**Key aspects**:
- Score (1-10) for quick assessment
- Critical/Important/Minor categorization
- Specific fixes with code examples
- Best practices checklist

### Plan Command

**Purpose**: Interactive plugin design and scaffolding

**Flow**:
1. Parse initial description
2. Detect if in existing plugin
3. Read knowledge base
4. Launch subagent with:
   - Full plugin knowledge
   - Phase-based planning process
   - Access to AskUserQuestion
   - Access to scaffolder
5. Subagent guides through phases:
   - Understanding (questions)
   - Architecture (proposal)
   - Design (details)
   - Confirmation
   - Scaffolding
   - Next steps

**Key aspects**:
- Interactive (uses AskUserQuestion)
- Iterative (user can refine)
- Comprehensive (considers all components)
- Actionable (scaffolds at the end)

## Updating the Knowledge Base

When plugin ecosystem changes:

1. **Update plugin-knowledge.md** with new info
2. **Add examples** from real plugins
3. **Include common patterns**
4. **Document pitfalls** people actually hit
5. **Keep it current**

The knowledge base is the expert's brain. Keep it comprehensive and accurate.

## Adding New Commands

If adding new commands (e.g., `/pluggy:test`):

1. **Create command file** in `commands/`
2. **Read knowledge base** first
3. **Launch appropriate subagent**
4. **Define clear phases/output**
5. **Update README**

Pattern:
```markdown
---
description: What this does
argument-hint: Expected format
allowed-tools: Task, [others as needed]
---

# Command Name

## Parameters
...

## Your Task

### 1. Load Knowledge
Read ${CLAUDE_PLUGIN_ROOT}/docs/plugin-knowledge.md

### 2. Launch Subagent
Use Task tool with comprehensive prompt including:
- Full knowledge base
- Specific task instructions
- Output format

### 3. Present Results
...
```

## Subagent Prompts

### Best Practices for Prompts

1. **Inject full knowledge** - The subagent doesn't know about plugins by default
2. **Be specific about output** - Define exactly what report format you want
3. **List all steps** - Guide the subagent through the process
4. **Include examples** - Show what good output looks like
5. **Allow flexibility** - Let subagent adapt to situation

### Prompt Structure

```
You are an expert Claude Code plugin developer...

# Plugin Knowledge
[Full content from plugin-knowledge.md]

# Your Task
[Specific task with phases]

# Output Format
[Exactly how to format the result]
```

## The Scaffolder Module

`pluggy/scaffolder.py` provides code generation utilities:

- `PluginScaffolder` - Create plugins, add commands/hooks
- `MarketplaceScaffolder` - Create marketplaces

Used by the plan command after user confirms the design.

Keep this module for the actual file generation, but the intelligence comes from the subagent, not the scaffolder.

## Testing Strategy

### What to Test

1. **Scaffolder** - Still test file generation
2. **Validator** - Still test basic checks
3. **Knowledge base** - Verify it's comprehensive
4. **Commands** - Manual testing with real plugins

### Manual Testing

Since Pluggy uses subagents, manual testing is important:

```bash
# Test audit on Courtney
/pluggy:audit ../courtney

# Test plan for new plugin
/pluggy:plan I want a todo tracker

# Test audit on Pluggy itself
/pluggy:audit .
```

## Common Tasks

### Improving Audit Quality

1. Update checklist in audit.md
2. Add new categories of issues
3. Improve fix recommendations
4. Add more code examples

### Improving Planning Flow

1. Add/refine questions in plan.md
2. Improve architecture proposals
3. Better component design prompts
4. Clearer confirmation format

### Expanding Knowledge

1. Add new patterns to plugin-knowledge.md
2. Include examples from production plugins
3. Document new Claude Code features
4. Update best practices

## Debugging

### Subagent Issues

If subagent doesn't perform well:
1. Check knowledge base is complete
2. Verify prompt is specific enough
3. Ensure output format is clear
4. Test with simpler cases first

### Scaffolder Issues

If file generation fails:
1. Check directory permissions
2. Verify paths are correct
3. Test scaffolder directly in Python

## Future Enhancements

Potential additions:
- `/pluggy:test` - Generate and run tests
- `/pluggy:docs` - Generate documentation
- `/pluggy:upgrade` - Migrate to new patterns
- `/pluggy:publish` - Publish to marketplace

Each would follow the same pattern:
1. Read knowledge base
2. Launch specialized subagent
3. Provide comprehensive guidance

## Remember

Pluggy is an **intelligent consultant**, not a template copier. The value is in:
- Deep ecosystem knowledge
- Interactive guidance
- Comprehensive reviews
- Actionable recommendations
- Ongoing help

Keep improving the knowledge base and subagent prompts to make the expert smarter.
