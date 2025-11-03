# Contributing to Quickstop

Thank you for considering contributing to Quickstop! This document provides guidelines for adding new plugins to the marketplace.

## Plugin Structure

Each plugin in Quickstop should follow this structure:

```
plugins/your-plugin/
├── .claude-plugin/
│   └── plugin.json              # Required: Plugin manifest
├── commands/                     # Optional: Slash commands
│   └── your-command.md
├── hooks/                        # Optional: Hook scripts
│   ├── hooks.json
│   └── your_hook.py
├── skills/                       # Optional: Agent skills
│   └── your-skill/
│       └── SKILL.md
├── agents/                       # Optional: Custom agents
│   └── your-agent.md
├── README.md                     # Required: Plugin documentation
└── [your plugin code]           # Your implementation
```

## Plugin Manifest Requirements

Your `plugin.json` must include:

```json
{
  "name": "your-plugin-name",
  "description": "Clear, concise description",
  "version": "1.0.0",
  "author": {
    "name": "Your Name",
    "email": "your@email.com"
  },
  "keywords": ["relevant", "keywords"],
  "license": "MIT"
}
```

## Documentation Requirements

### README.md

Your plugin README should include:

1. **Brief Description** - What does it do?
2. **Features** - Key capabilities
3. **Installation** - How to install (reference marketplace)
4. **Usage** - Examples and common workflows
5. **Configuration** - Any settings or options
6. **Examples** - Real-world use cases

### Example README Template

```markdown
# Your Plugin Name

Brief description of what your plugin does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

\`\`\`bash
/plugin marketplace add acostanzo/Courtney
/plugin install your-plugin@quickstop
\`\`\`

## Usage

### Basic Usage

\`\`\`bash
/your-command
\`\`\`

### Advanced Usage

[Examples...]

## Configuration

[Configuration details...]

## Examples

[Real examples...]
```

## Code Standards

1. **Python Code**
   - Follow PEP 8 style guidelines
   - Include type hints where appropriate
   - Add docstrings for classes and functions
   - Handle errors gracefully

2. **Hook Scripts**
   - Always exit 0 (never block Claude Code)
   - Fail silently with stderr logging
   - Test with various input scenarios

3. **Commands**
   - Use clear, descriptive frontmatter
   - Include `description` and `argument-hint`
   - Provide helpful examples

## Testing

Before submitting, ensure:

1. **Plugin installs cleanly** from local marketplace
2. **All features work** as documented
3. **No errors** in Claude Code logs
4. **Documentation is accurate** and up-to-date

### Testing Your Plugin

```bash
# Add your local repo as marketplace
/plugin marketplace add ./Courtney

# Install your plugin
/plugin install your-plugin@quickstop

# Test all features
[Test your commands, hooks, etc.]

# Check for errors
# Look in Claude Code logs
```

## Submission Process

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b plugin/your-plugin-name`)
3. **Add your plugin** to `plugins/your-plugin/`
4. **Update marketplace.json** to include your plugin
5. **Add tests** if applicable
6. **Create a Pull Request** with:
   - Clear description of what the plugin does
   - Screenshots/examples if helpful
   - Any special installation notes

## Pull Request Template

```markdown
## Plugin: [Your Plugin Name]

### Description
[Brief description of what your plugin does]

### Type of Plugin
- [ ] Hooks
- [ ] Commands
- [ ] Skills
- [ ] Agents
- [ ] Other: [specify]

### Testing Checklist
- [ ] Plugin installs cleanly
- [ ] All features tested and working
- [ ] Documentation complete and accurate
- [ ] No errors in Claude Code logs
- [ ] Examples work as documented

### Additional Notes
[Any special considerations or notes for reviewers]
```

## Plugin Ideas

Looking for inspiration? Consider plugins for:

- **Workflow Automation** - Repetitive task simplification
- **Code Quality** - Linting, formatting, review helpers
- **Documentation** - Auto-documentation, changelog generation
- **Team Collaboration** - Shared workflows, standards enforcement
- **Development Tools** - Testing helpers, deployment utilities
- **Data Processing** - Parsing, transformation, analysis
- **Integration** - External service connections

## Questions?

- Open an issue for clarification
- Check existing plugins for examples
- Refer to [Claude Code Plugin Documentation](https://docs.claude.com/claude-code/plugins)

## Code of Conduct

- Be respectful and constructive
- Focus on the plugin, not the person
- Help others learn and improve
- Keep discussions on-topic

Thank you for contributing to Quickstop! 🎬
