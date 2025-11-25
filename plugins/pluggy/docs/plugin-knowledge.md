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

### 2025 Schema Requirements

**Required fields (strict):**
- `name` (string) - Plugin identifier
  - MUST be lowercase, alphanumeric, hyphens/underscores only
  - Kebab-case recommended (e.g., "my-plugin")
  - No spaces or special characters

**Strongly recommended fields:**
- `version` (string) - Semantic version (x.y.z format required)
- `description` (string) - Brief description of plugin functionality
- `author` (object) - Author information with `name` field minimum
  - `author.name` (string) - Author name
  - `author.email` (string) - Author email
- `repository` (string) - Source code URL (full GitHub/GitLab URL)
- `keywords` (array of strings) - Search/discovery tags
- `license` (string) - License identifier (e.g., "MIT", "Apache-2.0")

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

### Frontmatter Schema (2025)

**All fields optional, but strongly recommended:**

```markdown
---
description: Brief description of what this command does
argument-hint: Expected argument format (for autocomplete)
allowed-tools: Comma-separated list of tools (e.g., "Read, Write, Bash(git:*)")
model: Specific Claude model (e.g., "opus", "haiku", "claude-sonnet-4-5-20250929")
---
```

**Field details:**
- `description` - Shown in command menu and help
- `argument-hint` - Parameter guidance, shown during autocomplete
- `allowed-tools` - Can specify method patterns (e.g., `Bash(git add:*)` for granular control)
- `model` - Override default model for this command

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

## Skills (2025 Schema)

Skills are reusable capabilities that can be invoked within conversations. They provide specialized functionality.

**Location**: `skills/skill-name/SKILL.md` (directory structure required)

### Frontmatter Schema (2025 - STRICT)

**Required fields:**
- `name` (string) - Skill identifier
  - MUST be lowercase letters, numbers, and hyphens only
  - Maximum 64 characters
  - Example: `"monitoring-cpu-usage"`
- `description` (string) - What the skill does and when to use it
  - Maximum 1024 characters
  - MUST include trigger phrases for discovery
  - Example: "Use when you need to 'analyze CPU performance' or 'detect CPU bottlenecks'"

**Strongly recommended fields (2025):**
- `allowed-tools` (string) - Comma-separated tool names for security/performance
  - Example: `"Read, Write, Edit, Grep, Bash"`
- `version` (string) - Semantic version to track skill evolution
  - Example: `"1.0.0"`

**Example:**
```yaml
---
name: monitoring-cpu-usage
description: This skill monitors CPU usage patterns. Use when you need to 'analyze CPU performance' or 'detect CPU bottlenecks'.
allowed-tools: Read, Bash, Grep
version: 1.0.0
---
```

### Supporting Files
Skills can include additional files in the skill directory:
- `reference.md` - Additional documentation
- `examples.md` - Usage examples
- `scripts/` - Utility scripts
- `templates/` - Template files

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

## 2025 Schema Compliance Checklist

Use this checklist when auditing plugins for 2025 schema compliance:

### Plugin Manifest (plugin.json)
- [ ] `name` field present and follows naming rules (lowercase, alphanumeric, hyphens/underscores)
- [ ] `version` field present and uses semantic versioning (x.y.z)
- [ ] `description` field present and descriptive
- [ ] `author` object present with at least `name` field
- [ ] `author.email` field present
- [ ] `repository` field present with full URL
- [ ] `keywords` array present for discoverability
- [ ] `license` field present with valid identifier

### Commands
- [ ] All command files in `commands/` directory
- [ ] File naming follows kebab-case pattern
- [ ] `description` field in frontmatter
- [ ] `argument-hint` field in frontmatter (if command takes arguments)
- [ ] `allowed-tools` field in frontmatter
- [ ] Command body uses `$ARGUMENTS` for parameters
- [ ] Command body uses `${CLAUDE_PLUGIN_ROOT}` for paths

### Skills (2025 Schema - STRICT)
- [ ] Skills in `skills/skill-name/SKILL.md` directory structure
- [ ] `name` field: lowercase, numbers, hyphens only, max 64 chars
- [ ] `description` field: max 1024 chars, includes trigger phrases
- [ ] `allowed-tools` field present (strongly recommended)
- [ ] `version` field present (strongly recommended)
- [ ] Description includes quoted trigger phrases for discovery

### Agents
- [ ] Agent files in `agents/` directory
- [ ] `name` field in frontmatter
- [ ] `description` field in frontmatter
- [ ] `allowed-tools` field specified (recommended)

### Hooks
- [ ] `hooks.json` properly formatted
- [ ] All hook event types are valid
- [ ] Hook scripts exist and are executable
- [ ] Hook scripts have proper shebang (`#!/usr/bin/env python3`)
- [ ] Hook scripts always exit 0 (never block)
- [ ] Hook scripts read JSON from stdin
- [ ] Hook scripts use `${CLAUDE_PLUGIN_ROOT}` for paths
- [ ] Timeout values are reasonable (default 60s)

### Documentation
- [ ] README.md present with installation instructions
- [ ] README.md includes usage examples
- [ ] CLAUDE.md present with AI assistant guidelines (recommended)
- [ ] CHANGELOG.md present with version history (recommended)

### Repository Files (Context-Aware)
When auditing plugins that live inside a larger repository (e.g., a marketplace monorepo):

- **`.gitignore`**: Check parent directories up to the git root. A `.gitignore` in any parent directory covers subdirectories. Don't flag as missing if a parent has one.
- **`LICENSE`**: Check parent directories. A LICENSE file at the repo root covers all subdirectories. The plugin's `plugin.json` license field should match the parent LICENSE type.

**How to check**: Use `git rev-parse --show-toplevel` to find the repo root, then check for these files there.

Only flag these as missing if:
1. The plugin is standalone (not in a git repo), OR
2. Neither the plugin nor any parent directory has the file

### Code Quality
- [ ] No SQL injection vulnerabilities (use parameterized queries)
- [ ] No path traversal vulnerabilities (validate paths)
- [ ] No code injection vulnerabilities (sanitize inputs)
- [ ] Specific exception handling (not bare `except:`)
- [ ] Proper logging without blocking

### Testing
- [ ] Test file present (e.g., `test_pluginname.py`)
- [ ] Tests cover core functionality
- [ ] Tests are executable
- [ ] All tests pass
