# Quickstop Documentation Standards

This document defines the documentation standards for the Quickstop plugin marketplace. Dante uses this as a reference when reviewing documentation.

## Philosophy

> *"I assure you we're open."*

Good documentation is:
- **Scannable** - Key info visible in seconds
- **Actionable** - Copy-paste and go
- **Accurate** - Matches actual functionality
- **Consistent** - Same patterns everywhere

## Root README Structure

The marketplace README (`quickstop/README.md`) follows this structure:

```markdown
# Quickstop

> Quote from Clerks

Brief description of what Quickstop is.

## Available Plugins

### 🎙️ Plugin Name
**Tagline**

Brief description (2-3 sentences max).

**Features:**
- Feature 1
- Feature 2
- Feature 3

[📖 Read Plugin Documentation](./plugins/plugin-name/README.md)

[Repeat for each plugin]

## Installation

### Quick Start
[Commands to install]

### From Local Clone
[Alternative installation]

## Plugin Management
[Common commands]

## Repository Structure
[Directory tree]

## Contributing
[Link to CONTRIBUTING.md]

## Philosophy
[Core principles]

## About the Name
[Clerks reference]

## License
MIT

## Author
[Contact info]
```

## Plugin README Structure

Each plugin README (`plugins/*/README.md`) follows this structure:

```markdown
# Plugin Name

> Optional tagline or quote

Brief description of what the plugin does and why.

## Features

- Feature 1 with brief explanation
- Feature 2 with brief explanation
- Feature 3 with brief explanation

## Installation

```bash
# Add marketplace (if not already added)
/plugin marketplace add acostanzo/quickstop

# Install plugin
/plugin install plugin-name@quickstop
```

Restart Claude Code to activate.

## Usage

### Basic Usage
[Simple example with explanation]

### Command Reference

#### `/plugin:command`
Description of what this command does.

**Arguments:**
- `arg1` - Description
- `arg2` - Description (optional)

**Examples:**
```bash
/plugin:command arg1
/plugin:command arg1 --flag
```

[Repeat for each command]

## Configuration

[If applicable - environment variables, config files, etc.]

## How It Works

[Brief technical explanation for those who want to understand]

## Troubleshooting

[Common issues and solutions]

## License

MIT - See [LICENSE](../../LICENSE)
```

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

All notable changes to [Plugin Name] will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature description

## [1.0.1] - YYYY-MM-DD

### Added
- **Feature Name**: Description of what was added and why it matters

### Changed
- **Component Name**: What changed and impact on users

### Fixed
- **Bug Name**: What was broken and how it's fixed now

### Security
- Security-related changes

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release
- [List all initial features]

[Version comparison links at bottom]
[1.0.1]: https://github.com/acostanzo/quickstop/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/acostanzo/quickstop/releases/tag/v1.0.0
```

### CHANGELOG Best Practices

1. **Explain the "why"** - Not just "Added X" but "Added X to enable Y"
2. **Bold the component** - `**Feature Name**: Description`
3. **User perspective** - What does this mean for users?
4. **Group related changes** - Under appropriate categories
5. **Link versions** - Enable easy diff viewing

## CLAUDE.md Guidelines

For AI assistant context (`CLAUDE.md`):

```markdown
# CLAUDE.md

Guidelines for Claude working on [Plugin Name].

## Project Overview
[What this plugin does]

## Core Philosophy
[Design principles]

## Architecture
[Key components and how they interact]

## Development Principles
[What to do and not do]

## Key Files
[Important file locations]

## Testing
[How to run tests]

## Common Tasks
[Frequent development tasks]

## Future Enhancements
[Planned but not implemented]
```

## Consistency Rules

### Naming Conventions
- Plugin names: lowercase, single word preferred
- Command names: `plugin:action` format
- File names: lowercase with hyphens

### Emoji Usage
- 🎙️ Courtney (microphone - recording)
- 🔌 Pluggy (plug - plugin development)
- 🌳 Arborist (tree - git trees/worktrees)
- Use sparingly, mainly in root README headers

### Code Blocks
- Always specify language: ```bash, ```python, ```json
- Use actual working examples, not pseudocode
- Include expected output when helpful

### Links
- Relative paths within repo: `./path/to/file.md`
- External links: Full URLs
- Use descriptive link text, not "click here"

## Quality Checklist

### README Quick Check
- [ ] Can understand purpose in 10 seconds?
- [ ] Can install and use in 2 minutes?
- [ ] All commands documented with examples?
- [ ] No broken links?
- [ ] Matches current functionality?

### CHANGELOG Quick Check
- [ ] Follows Keep a Changelog format?
- [ ] Entries explain user impact?
- [ ] Version links present and correct?
- [ ] New features reflected in README?

### Cross-Plugin Check
- [ ] All plugins in root README?
- [ ] Descriptions match individual READMEs?
- [ ] Directory structure accurate?
- [ ] Consistent formatting across plugins?

## Common Issues

### README Problems
1. **Missing features** - CHANGELOG has items not in README
2. **Outdated examples** - Code that no longer works
3. **Wrong paths** - Links that 404
4. **Inconsistent format** - Different structure than siblings

### CHANGELOG Problems
1. **No user impact** - Just "Fixed bug" without context
2. **Missing links** - No version comparison URLs
3. **Wrong dates** - Typos or future dates
4. **Orphaned versions** - In CHANGELOG but not tagged

### Sync Problems
1. **Root README outdated** - Missing new plugins
2. **Description mismatch** - Root says X, plugin says Y
3. **Feature drift** - README lists features not yet built

## Dante's Review Process

When Dante reviews documentation:

1. **Read all relevant files** - README, CHANGELOG, root README
2. **Check for sync issues** - Do they all agree?
3. **Verify accuracy** - Does documentation match code?
4. **Apply standards** - Does it follow this guide?
5. **Suggest specific fixes** - With exact text changes
6. **Prioritize issues** - Critical > Important > Minor

Remember: Documentation is the first thing users see. Make it count!
