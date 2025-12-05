# Pluggy

Your expert plugin development consultant for Claude Code.

## What is Pluggy?

Pluggy is a meta-plugin that provides expert guidance for building, auditing, and maintaining Claude Code plugins and marketplaces. Unlike simple scaffolding tools, Pluggy uses specialized subagents with deep knowledge of the entire Claude Code plugin ecosystem.

## Features

🔍 **Expert Audits** - Comprehensive plugin review by a specialized subagent
📋 **Interactive Planning** - Collaborative design sessions that understand your needs
🧠 **Deep Knowledge** - Full understanding of commands, hooks, skills, subagents, MCP, and more
🛠️ **Smart Scaffolding** - Generate code only after proper planning
💡 **Best Practices** - Guidance based on production plugins like Courtney
🎯 **Smart Discovery** - Auto-detect context and find plugins by name (`arborist` finds `./plugins/arborist/`)

## Installation

### From Quickstop Marketplace

```bash
# Add the Quickstop marketplace
/plugin marketplace add acostanzo/quickstop

# Install Pluggy
/plugin install pluggy@quickstop
```

### From Local Clone

```bash
# Clone the repository
git clone https://github.com/acostanzo/quickstop.git

# Add as local marketplace
/plugin marketplace add ./quickstop

# Install Pluggy
/plugin install pluggy@quickstop
```

## Commands

### `/pluggy:audit [plugin-name-or-path]` - Expert Plugin Audit

Launch a specialized plugin development expert to conduct a comprehensive audit.

```bash
# Audit current directory (if in a plugin)
/pluggy:audit

# Audit by plugin name (smart search finds ./plugins/arborist/)
/pluggy:audit arborist

# Audit by path
/pluggy:audit plugins/my-plugin

# List available plugins (when in marketplace root)
/pluggy:audit
```

**Smart Discovery**: When you're in a marketplace, Pluggy automatically detects context and finds plugins by name. Type `arborist` instead of `plugins/arborist`.

**What gets reviewed:**
- Structure & configuration
- Manifest completeness
- Command design and clarity
- Hook implementation and safety
- Security vulnerabilities
- Code quality and patterns
- Error handling
- Test coverage
- Documentation quality
- Best practices compliance

**Output includes:**
- Executive summary with score (1-10)
- Detailed findings (critical/important/minor)
- Specific fix recommendations with code examples
- Best practices checklist
- Concrete next steps

### `/pluggy:plan [description]` - Interactive Planning

Start a collaborative planning session to design and build a plugin.

```bash
# Plan a new plugin
/pluggy:plan I want to track my coding sessions

# Add feature to existing plugin (from plugin directory)
/pluggy:plan Add a search command

# General consultation
/pluggy:plan
```

**Context-Aware**: Pluggy detects if you're in a marketplace (creates plugins in `./plugins/`) or a standalone directory (creates in current location).

**The expert subagent will:**

1. **Understand** - Ask clarifying questions about your goals
2. **Architect** - Propose structure (commands, hooks, storage, etc.)
3. **Design** - Detail each component with specifications
4. **Confirm** - Review the complete plan with you
5. **Scaffold** - Generate the plugin once you approve
6. **Guide** - Explain next steps and offer continued help

**Interactive questions include:**
- What problem are you solving?
- How will users interact with it?
- Does it need to persist data?
- Should it run automatically or on-demand?

## The Expert Knows

Pluggy's subagents have comprehensive knowledge of:

### Plugin Components
- **Manifests** - Required/recommended fields, versioning
- **Commands** - Frontmatter, instructions, allowed-tools
- **Hooks** - All 7 types (SessionStart, SessionEnd, UserPromptSubmit, Stop, SubagentStop, PreToolUse, PostToolUse)
- **Skills** - Reusable capabilities
- **Subagents** - Task tool patterns
- **MCP Servers** - Integration patterns

### Best Practices
- Security (SQL injection, path traversal, etc.)
- Performance (fast hooks, resource limits)
- Reliability (error handling, graceful degradation)
- Testing patterns
- Documentation standards

### Production Examples
- Courtney - Database recording, comprehensive testing
- Pluggy - Subagents, interactive commands

## Example: Creating a Todo Plugin

```bash
/pluggy:plan I want a plugin to manage my todos
```

**Pluggy asks:**
> How should users add todos? Via slash command or automatically?

You: "Slash commands"

**Pluggy asks:**
> Should todos persist across sessions?

You: "Yes, use a database"

**Pluggy proposes:**
```
Great! Here's the architecture:

Commands:
- /todos:add <task> - Add a todo
- /todos:list - Show all todos
- /todos:done <id> - Mark complete

Storage:
- SQLite database at ~/.claude/todos.db

Structure:
todos/
├── .claude-plugin/plugin.json
├── commands/
│   ├── add.md
│   ├── list.md
│   └── done.md
├── todos/
│   ├── __init__.py
│   └── database.py
└── README.md

Does this look good?
```

You: "Yes, let's build it"

**Pluggy scaffolds the plugin and guides you on next steps.**

## Example: Auditing a Plugin

```bash
/pluggy:audit ./my-plugin
```

**Output:**
```
📋 AUDIT REPORT
═══════════════════════════════════

## Executive Summary

Overall Assessment: **Needs Work** (7/10)

Key Strengths:
✓ Well-structured manifest
✓ Good documentation
✓ Comprehensive test coverage

Critical Issues:
❌ Hook script uses bare exception handler
❌ SQL queries not parameterized

## Detailed Findings

### ⚠️ Critical: SQL Injection Vulnerability

**Location**: todos/database.py:45

**Problem**:
cursor.execute(f"SELECT * FROM todos WHERE id = {id}")

**Why it matters**:
Allows SQL injection attacks

**Fix**:
cursor.execute("SELECT * FROM todos WHERE id = ?", (id,))

[Full report continues...]

## Score: 7/10

## Next Steps:
1. Fix SQL injection vulnerability
2. Replace bare except with specific exceptions
3. Add input validation
4. Run tests after fixes

Would you like help addressing these findings?
```

## Why Subagents?

Traditional scaffolding tools just copy templates. Pluggy is different:

| Traditional | Pluggy |
|-------------|--------|
| Templates | Interactive planning |
| One-size-fits-all | Custom to your needs |
| No review | Expert audits |
| Static knowledge | Deep ecosystem understanding |
| Generate and forget | Ongoing guidance |

The subagent approach means Pluggy can:
- Ask follow-up questions
- Understand context
- Make intelligent recommendations
- Provide detailed explanations
- Adapt to your specific needs

## Plugin Knowledge Base

Pluggy includes a comprehensive knowledge base at `docs/plugin-knowledge.md` covering:

- Complete plugin structure
- All manifest fields
- Command design patterns
- All 7 hook types with examples
- Security best practices
- Performance guidelines
- Common pitfalls
- Testing strategies
- Documentation standards

This knowledge is injected into every subagent session.

## Best Practices

### When to Use Audit
- Before releasing a plugin
- After major changes
- When inheriting someone else's plugin
- For learning (audit good plugins to learn patterns)

### When to Use Plan
- Starting a new plugin
- Adding significant features
- Unsure about architecture
- Want expert guidance

### General Tips
- Be specific about your goals
- Answer the expert's questions thoughtfully
- Review the plan before scaffolding
- Use audit on your work before releasing

## Development

### Running Tests

```bash
cd plugins/pluggy
python3 test_pluggy.py
```

### Dogfooding

Pluggy audits itself:

```bash
/pluggy:audit ./plugins/pluggy
```

## Contributing

Contributions welcome! The best way to improve Pluggy:

1. Use it to build plugins
2. Note what could be better
3. Update the knowledge base
4. Improve the prompts
5. Add test cases

## License

MIT

## Credits

Created by Anthony Costanzo for the Quickstop marketplace.

Pluggy helps you build plugins with expert guidance. 🔌
