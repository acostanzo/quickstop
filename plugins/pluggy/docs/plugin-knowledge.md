# Claude Code Plugin Knowledge Base

This document contains comprehensive knowledge about Claude Code plugins for use by Pluggy's expert subagents.

## Plugin Structure

A Claude Code plugin is a directory with this structure:

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # REQUIRED: Plugin manifest
├── commands/                # OPTIONAL: Slash commands
│   ├── command1.md
│   └── command2.md
├── hooks/                   # OPTIONAL: Event hooks
│   ├── hooks.json
│   └── hook_script.py
├── skills/                  # OPTIONAL: Skill definitions
│   └── skill.md
├── agents/                  # OPTIONAL: Subagent definitions
│   └── agent.md
├── my-plugin/               # OPTIONAL: Python/JS code
│   └── __init__.py
├── README.md
├── setup.py                 # If Python package
└── requirements.txt
```

## Plugin Manifest (plugin.json)

**Location**: `.claude-plugin/plugin.json`

**Required fields:**
- `name` (string) - Plugin identifier (lowercase, alphanumeric, hyphens/underscores)
- `description` (string) - Brief description of plugin functionality
- `version` (string) - Semantic version (x.y.z)

**Recommended fields:**
- `author` (object) - `{name, email}`
- `repository` (string) - Source code URL
- `keywords` (array) - Search keywords
- `license` (string) - License type (e.g., "MIT")

**Example:**
```json
{
  "name": "my-plugin",
  "description": "Does awesome things",
  "version": "1.0.0",
  "author": {
    "name": "Developer Name",
    "email": "dev@example.com"
  },
  "repository": "https://github.com/user/repo",
  "keywords": ["automation", "productivity"],
  "license": "MIT"
}
```

## Slash Commands

### Purpose
Slash commands provide user-invoked functionality. They give Claude specific instructions to accomplish a task.

### Structure
Commands are Markdown files in the `commands/` directory.

**File naming**: `command-name.md` → invoked as `/plugin:command-name`

### Frontmatter (Optional but Recommended)
```markdown
---
description: Brief description of what this command does
argument-hint: Expected argument format
allowed-tools: Comma-separated list of tools Claude can use
---
```

### Command Body
The markdown body contains instructions for Claude on how to execute the command. Think of it as a specialized system prompt.

**Best practices:**
- Be specific and detailed
- Include examples
- Handle error cases
- Show expected output format
- Use `$ARGUMENTS` to reference user-provided arguments
- Use `${CLAUDE_PLUGIN_ROOT}` for plugin-relative paths

**Example:**
```markdown
---
description: Search codebase for patterns
argument-hint: <search-pattern> [--type file-type]
allowed-tools: Grep, Read
---

# Search Command

Search the codebase for specific patterns.

## Parameters
**Arguments**: `$ARGUMENTS`

## Your Task
1. Parse the search pattern from $ARGUMENTS
2. Use Grep to search for the pattern
3. Show results with context
4. If --type flag provided, filter by file type
```

## Event Hooks

### Purpose
Hooks execute automatically when specific events occur in Claude Code sessions.

### Available Hook Types

1. **SessionStart**
   - Triggered when a Claude Code session begins
   - Data: `session_id`, `transcript_path`, `source` (startup/cli/api)

2. **SessionEnd**
   - Triggered when session ends
   - Data: `session_id`, `transcript_path`, `reason`

3. **UserPromptSubmit**
   - Triggered when user submits a prompt
   - Data: `session_id`, `prompt`, `permission_mode`

4. **Stop**
   - Triggered when Claude finishes a response
   - Data: `session_id`, `transcript_path`, `permission_mode`

5. **SubagentStop**
   - Triggered when a subagent completes
   - Data: `session_id`, `transcript_path`

6. **PreToolUse**
   - Triggered before a tool is used
   - Data: Tool information

7. **PostToolUse**
   - Triggered after a tool is used
   - Data: Tool results

### Hook Configuration

**File**: `hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session_hook.py"
          }
        ]
      }
    ]
  }
}
```

### Hook Script Best Practices

1. **Always exit 0** - Never block Claude Code
2. **Read from stdin** - Hook data comes as JSON on stdin
3. **Fail silently** - Log errors but don't crash
4. **Be fast** - Hooks run synchronously
5. **Use absolute paths** - Rely on `CLAUDE_PLUGIN_ROOT` environment variable

**Example hook script:**
```python
#!/usr/bin/env python3
import sys
import json

def main():
    try:
        hook_data = json.load(sys.stdin)
        event_type = hook_data.get("hook_event_name")

        # Do work here

        # Always exit successfully
        sys.exit(0)
    except Exception as e:
        # Log but don't block
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
```

## Skills

Skills are reusable capabilities that can be invoked within conversations. They provide specialized functionality.

**Location**: `skills/` directory

Skills expand inline when invoked, providing additional context and capabilities to Claude.

## Subagents

Subagents are specialized AI agents launched via the Task tool to handle complex, multi-step operations.

### When to Use Subagents
- Complex analysis requiring multiple steps
- Code reviews
- Architecture planning
- Testing and validation
- Research tasks

### How to Launch Subagents

In commands, use:
```markdown
Use the Task tool with subagent_type="Explore" to search the codebase thoroughly.
```

Claude will then launch the appropriate subagent.

## MCP Servers

MCP (Model Context Protocol) servers provide additional tools and resources to Claude Code.

Plugins can:
- Recommend MCP servers for users to install
- Integrate with existing MCP servers
- Provide custom MCP server implementations

## Plugin Best Practices

### Security
1. **SQL Injection**: Use parameterized queries
2. **Path Traversal**: Validate all file paths
3. **Code Injection**: Sanitize all inputs
4. **File Size Limits**: Prevent memory exhaustion
5. **Permissions**: Minimal necessary permissions

### Performance
1. **Fast Hooks**: Keep hooks under 100ms when possible
2. **Async Operations**: Don't block Claude Code
3. **Resource Limits**: Set timeouts and size limits
4. **Caching**: Cache expensive operations

### Reliability
1. **Error Handling**: Catch and log all errors
2. **Graceful Degradation**: Fail safely
3. **Idempotency**: Operations should be repeatable
4. **Testing**: Comprehensive test coverage

### User Experience
1. **Clear Documentation**: README with examples
2. **Helpful Errors**: Guide users to solutions
3. **Progress Feedback**: Show what's happening
4. **Defaults**: Sensible default behaviors

## Common Patterns

### Pattern 1: Database Recording (See: Courtney)
- **Hooks**: SessionStart, SessionEnd, UserPromptSubmit, Stop
- **Purpose**: Record conversation history
- **Implementation**: SQLite with WAL mode, parameterized queries
- **Key Features**: Corruption recovery, thread-safe, silent failure

### Pattern 2: Code Generation (See: Pluggy)
- **Commands**: Interactive commands that generate code/files
- **Purpose**: Scaffold boilerplate
- **Implementation**: Template-based generation
- **Key Features**: Validation before creation, customizable templates

### Pattern 3: Analysis Tools
- **Commands**: Search, analyze, report
- **Subagents**: Deep analysis with specialized agents
- **Purpose**: Code review, security audit, quality checks
- **Implementation**: Combine Grep, Read, and expert knowledge

## Testing Plugins

### Unit Tests
Test individual components:
- Manifest validation
- File generation
- Hook data parsing
- Configuration loading

### Integration Tests
Test full workflows:
- Create plugin → validate → install
- Hook triggering and execution
- Command invocation
- Error handling

### Manual Testing
1. Install plugin locally: `/plugin marketplace add ./plugin-dir`
2. Test commands: `/plugin:command-name`
3. Verify hooks trigger correctly
4. Check error messages are helpful

## Common Pitfalls

1. **Blocking Hooks** - Hooks that hang or crash block Claude
2. **Bare Exceptions** - Use specific exception types
3. **Print to stdout in Hooks** - Use logging instead
4. **Missing Error Handling** - Always handle errors gracefully
5. **No Tests** - Untested code will have bugs
6. **Poor Documentation** - Users need examples
7. **Hardcoded Paths** - Use environment variables
8. **No Version Schema** - Plan for schema migrations

## Plugin Development Workflow

1. **Plan**: Define purpose, features, architecture
2. **Scaffold**: Create basic structure
3. **Implement**: Build features incrementally
4. **Test**: Write and run tests
5. **Document**: README, examples, troubleshooting
6. **Validate**: Check structure and configuration
7. **Dogfood**: Use the plugin yourself
8. **Release**: Version, changelog, publish

## Example Plugins to Study

1. **Courtney** - Database recording, hooks, validation
2. **Pluggy** - Subagents, interactive commands, scaffolding

## Advanced Topics

### Schema Versioning
Add migration support for database schema changes:
```python
SCHEMA_VERSION = 1

def migrate_to_version(version):
    if version == 1:
        # Initial schema
    elif version == 2:
        # Migration from 1 to 2
```

### Multi-language Support
Plugins can use any language:
- Python (most common)
- JavaScript/TypeScript
- Shell scripts
- Any executable

### Hook Chaining
Multiple plugins can hook the same events. They execute in order.

### Environment Variables
Available to hooks and commands:
- `CLAUDE_PLUGIN_ROOT` - Plugin installation directory
- `CLAUDE_SESSION_ID` - Current session ID

## Questions to Ask When Auditing

1. **Purpose**: What problem does this solve?
2. **Structure**: Is the directory structure correct?
3. **Manifest**: Are all required/recommended fields present?
4. **Security**: Are there injection vulnerabilities?
5. **Performance**: Will this be fast enough?
6. **Errors**: Are errors handled gracefully?
7. **Testing**: Is there adequate test coverage?
8. **Documentation**: Can users understand how to use it?
9. **Best Practices**: Does it follow patterns?
10. **Maintainability**: Is the code clean and documented?

## Questions to Ask When Planning

1. **Goal**: What should the plugin accomplish?
2. **Users**: Who will use this and how?
3. **Features**: What specific capabilities are needed?
4. **Components**: Commands, hooks, both, or neither?
5. **Dependencies**: Any external dependencies?
6. **Storage**: Does it need to persist data?
7. **Integration**: Does it interact with other tools/plugins?
8. **Scope**: MVP vs full-featured?
9. **Timeline**: How complex is this?
10. **Examples**: Are there similar plugins to learn from?
