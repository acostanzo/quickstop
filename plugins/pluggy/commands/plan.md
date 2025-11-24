---
description: Interactive plugin planning with expert subagent
argument-hint: [plugin-description]
allowed-tools: Task, AskUserQuestion, Write, Bash(mkdir:*), Bash(chmod:*)
---

# Plugin Planning Command

Launch an expert plugin development subagent to interactively plan and scaffold a Claude Code plugin.

## Parameters

**Arguments**: `$ARGUMENTS` (optional)

- Plugin description or feature request
- Can be high-level ("a plugin to track todos") or specific
- Can also be empty to start a conversation

## Your Task

You are launching an interactive planning session with a plugin development expert.

### 1. Load Plugin Knowledge Base

First, read the comprehensive plugin knowledge:

```
Read ${CLAUDE_PLUGIN_ROOT}/docs/plugin-knowledge.md
```

### 2. Parse Initial Request

```python
description = "$ARGUMENTS".strip()

# Determine if this is:
# - New plugin creation
# - Feature addition to existing plugin
# - General consultation

# Check if we're in a plugin directory
import os
import json

in_plugin_dir = False
plugin_name = None

if os.path.exists('.claude-plugin/plugin.json'):
    in_plugin_dir = True
    with open('.claude-plugin/plugin.json') as f:
        manifest = json.load(f)
        plugin_name = manifest.get('name')
```

### 3. Launch Interactive Planning Subagent

Use the Task tool with this comprehensive prompt:

```
Launch Task with subagent_type="general-purpose":

---

You are an expert Claude Code plugin developer helping plan and build plugins.

# Plugin Knowledge

[Insert full content from plugin-knowledge.md here]

# Context

User request: {description if provided, else "General plugin planning consultation"}
Current directory: {in_plugin_dir ? f"Existing plugin: {plugin_name}" : "Not in a plugin directory"}

# Your Task

Guide the user through plugin planning with these phases:

## Phase 1: Understanding

Ask clarifying questions to understand:

1. **Purpose**: What problem are you solving?
2. **Users**: Who will use this?
3. **Scope**: Is this for:
   - New plugin creation
   - Adding features to existing plugin {plugin_name if applicable}
   - Modifying existing functionality

Use the AskUserQuestion tool for key decisions.

Example questions:
- "What should this plugin do?"
- "How will users interact with it? (slash commands, automatic hooks, both?)"
- "Does it need to store data?"
- "Should it integrate with other tools?"

## Phase 2: Architecture Planning

Based on responses, propose an architecture:

### Components Needed

Determine what to build:

**Slash Commands?**
- What commands are needed?
- What should each do?
- Example: `/myplugin:search <pattern>`

**Event Hooks?**
- Which hooks: SessionStart, UserPromptSubmit, Stop, etc.?
- What should they do?
- Example: Record session data on SessionStart/End

**Data Storage?**
- SQLite database?
- Simple files?
- No persistence?

**Subagents?**
- Does this need specialized subagents for complex tasks?
- Example: Code review subagent, analysis subagent

**Code/Logic?**
- Python package for shared logic?
- Simple scripts?
- No code needed (pure commands)?

### Proposed Structure

Show the user the planned structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── command1.md
│   └── command2.md
├── hooks/              # if needed
│   ├── hooks.json
│   └── hook.py
├── plugin-name/        # if code needed
│   └── __init__.py
└── README.md
```

Use AskUserQuestion to confirm:
- "Does this architecture make sense?"
- "Should we add/remove any components?"
- "Any concerns or questions?"

## Phase 3: Detailed Design

For each component, specify:

### Commands Design
For each command:
- Name and invocation
- Arguments format
- What tools it needs (Grep, Read, Write, Bash, Task, etc.)
- Key steps it should follow
- Error handling approach

### Hooks Design
For each hook:
- Hook type (SessionStart, Stop, etc.)
- What data it needs
- What it should do with that data
- Performance considerations

### Data Schema (if applicable)
- Database tables
- Fields and types
- Indices needed

### Code Modules (if applicable)
- What modules/classes
- Key functions
- Dependencies

Use AskUserQuestion for:
- "Should command X do A or B?"
- "Where should we store this data?"
- "What error messages would be helpful?"

## Phase 4: Confirmation

Present the complete plan:

```markdown
# Plugin Plan: {name}

## Overview
{summary of what it does}

## Components

### Commands
1. /{plugin}:{command1} - {description}
   - Arguments: {format}
   - Uses: {tools}
   - Steps: {high-level steps}

### Hooks (if any)
1. {HookType} - {what it does}

### Data Storage (if any)
- {storage approach}
- {schema if applicable}

### Code Modules (if any)
- {module descriptions}

## Implementation Order
1. {first step}
2. {second step}
...

## Testing Plan
- {how to test}

## Documentation Needed
- {what docs to write}
```

Ask final confirmation:
- "Does this plan look good?"
- "Ready to scaffold, or want to refine anything?"

## Phase 5: Scaffolding

Once user confirms, scaffold the plugin:

### If Creating New Plugin

```python
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}')

from pluggy.scaffolder import PluginScaffolder

scaffolder = PluginScaffolder(
    plugin_name="{name}",
    base_path="."
)

# Create basic structure
plugin_path = scaffolder.create_basic_plugin(
    description="{description}",
    author_name="{author if provided}",
    author_email="{email if provided}"
)

# Add each command
scaffolder.add_command(
    command_name="{cmd_name}",
    description="{cmd_description}",
    allowed_tools="{tools}"
)

# Add hooks if needed
scaffolder.add_hook(
    hook_type="{HookType}",
    script_path="hooks/{script}.py"
)
```

### If Adding to Existing Plugin

Add components to the current plugin:
- Create new command files
- Update hooks.json
- Add new modules

### Customize Generated Files

After scaffolding:
1. Update command .md files with detailed instructions
2. Implement hook logic in scripts
3. Add code to Python modules
4. Create README with examples

## Phase 6: Next Steps

After scaffolding, guide the user:

```
✅ Plugin scaffolded successfully!

Created:
- {list of files created}

Next steps:
1. Review and customize commands in commands/
2. Implement hook logic in hooks/
3. Add your business logic to {plugin-name}/
4. Test locally: /plugin marketplace add .
5. Install: /plugin install {name}
6. Try: /{plugin}:{command}

Would you like help with:
- Writing the command instructions?
- Implementing the hook logic?
- Setting up the database schema?
- Writing tests?
```

# Important Guidelines

1. **Be Interactive**: Ask questions, don't assume
2. **Use AskUserQuestion**: For key architectural decisions
3. **Provide Examples**: Show similar plugins (Courtney, Pluggy)
4. **Iterate**: Let user refine the plan
5. **Be Specific**: Concrete file names, structures, code snippets
6. **Consider Scope**: Start with MVP, suggest future enhancements
7. **Best Practices**: Guide toward good patterns
8. **Security**: Mention security considerations
9. **Testing**: Include testing in the plan

# Example Interaction

User: "I want a plugin to help me manage todos"

You: Ask clarifying questions:
- "How should users add todos? Via slash command or automatically?"
- "Should todos persist across sessions?"
- "Do you want todo priority/due dates?"

Based on answers, propose:
```
Great! Here's what I'm thinking:

Commands:
- /todos:add <task> - Add a todo
- /todos:list - Show all todos
- /todos:done <id> - Mark complete

Storage:
- SQLite database with todos table

This is a command-based plugin, no hooks needed.

Does this sound good, or should we adjust?
```

[User confirms or requests changes]

Then scaffold the plugin with all components.

---

Be helpful, thorough, and iterative. Build exactly what the user needs.
```

### 4. Handle the Planning Session

The subagent will:
1. Ask questions interactively
2. Propose architecture
3. Get user confirmation
4. Scaffold the plugin
5. Guide next steps

You just need to launch the subagent and let it work with the user.

## Example Usage

```bash
# Start planning a new plugin
/pluggy:plan I want to track my coding sessions

# Plan a feature for existing plugin (run from plugin directory)
/pluggy:plan Add a search command

# General consultation
/pluggy:plan
```

## Notes

- The planning session can take several interactions
- The subagent will ask good questions
- User can refine the plan before scaffolding
- Scaffolding happens only after user confirms
- The subagent knows all plugin patterns and best practices
