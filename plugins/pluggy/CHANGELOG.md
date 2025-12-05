# Changelog

All notable changes to Pluggy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-12-05

### Added

- **Smart Plugin Discovery** (`PluginFinder`) - Intelligent plugin finding that auto-detects context and searches intelligently:
  - Auto-detects if you're in a marketplace or plugin directory
  - Find plugins by name: `/pluggy:audit arborist` finds `./plugins/arborist/`
  - Find plugins by path: `/pluggy:audit plugins/my-plugin`
  - Lists available plugins when run from marketplace root without arguments
  - Always operates on source files in CWD, not installed copies in `~/.claude/`

### Changed

- **Audit command** now uses PluginFinder for smart discovery and provides CWD context to Claude
- **Plan command** now uses PluginFinder for context detection and creates plugins in correct location
- Explicit guidance to Claude to use CWD, not installed plugin location

### Fixed

- Commands now work correctly when developing plugins in a source repo separate from installed location

## [1.2.0] - 2025-12-02

### Added

- **Marketplace Documentation Command** (`/pluggy:docs`) - Review and synchronize documentation across plugin marketplaces. Ensures READMEs are digestible, changelogs meaningful, and everything stays in sync.
  - `all` - Review entire marketplace
  - `root` - Review root README only
  - `sync` - Auto-update root README from plugin manifests
  - `<plugin-name>` - Review specific plugin docs
  - Smart mode (no args) - Review based on recent git changes
- **Marketplace documentation best practices** added to knowledge base
  - Marketplace structure and manifest format
  - README templates and standards
  - Documentation synchronization guidelines
  - Changelog best practices

### Changed

- Consolidated dante:review functionality into Pluggy (removed separate command)

## [1.1.0] - 2025-12-02

### Added

- **Automatic marketplace registration** - When scaffolding a plugin inside a marketplace, the plugin is automatically registered in the parent `marketplace.json`. No more manual registration required!

### Improved

- **Context-aware audit for repository files** - Audit now checks parent directories for `.gitignore` and `LICENSE` files. Plugins inside a monorepo (like a marketplace) inherit these from the repo root, so they no longer get incorrectly flagged as missing.

### Changed

- Updated `docs/plugin-knowledge.md` with "Repository Files (Context-Aware)" section explaining inheritance rules
- Updated `commands/audit.md` to instruct subagent to check parent directories

## [1.0.0] - 2025-11-16

### Added

- **Expert Audit Command** (`/pluggy:audit`)
  - Launches specialized plugin development subagent
  - Comprehensive review covering structure, security, performance
  - Detailed findings with critical/important/minor categorization
  - Specific fix recommendations with code examples
  - Production readiness score (1-10)
  - Best practices checklist
  - Actionable next steps

- **Interactive Planning Command** (`/pluggy:plan`)
  - Collaborative plugin design sessions
  - Five-phase planning process:
    1. Understanding - Ask clarifying questions
    2. Architecture - Propose structure
    3. Design - Detail each component
    4. Confirmation - Review with user
    5. Scaffolding - Generate code
  - Uses AskUserQuestion for interactive decisions
  - Supports new plugins and adding features to existing ones
  - Smart scaffolding based on approved plan

- **Comprehensive Plugin Knowledge Base** (`docs/plugin-knowledge.md`)
  - Complete plugin structure documentation
  - All manifest fields (required/recommended)
  - All 7 hook types with examples and use cases
  - Command design patterns and best practices
  - Skills and subagents documentation
  - MCP server integration
  - Security best practices (SQL injection, path traversal, etc.)
  - Performance guidelines
  - Common pitfalls and how to avoid them
  - Questions to ask when auditing/planning

- **Scaffolding Utilities** (`pluggy/scaffolder.py`)
  - PluginScaffolder class for creating plugins
  - MarketplaceScaffolder class for creating marketplaces
  - Add commands and hooks to existing plugins
  - Template-based file generation

- **Validation Utilities** (`pluggy/validator.py`)
  - PluginValidator for basic structure checks
  - MarketplaceValidator for marketplace validation
  - ValidationResult class for reporting

### Architecture

Pluggy uses a subagent-based architecture:

1. User invokes command
2. Command reads comprehensive knowledge base
3. Command launches expert subagent via Task tool
4. Subagent has full plugin ecosystem context
5. Subagent interacts with user (questions, proposals)
6. Subagent can scaffold using pluggy.scaffolder

This approach provides:
- Deep plugin ecosystem understanding
- Interactive guidance (not just templates)
- Comprehensive reviews (not just validation)
- Actionable recommendations
- Ongoing help throughout development

### Commands

- `/pluggy:audit [path]` - Comprehensive plugin audit by expert
- `/pluggy:plan [description]` - Interactive planning and scaffolding

### Knowledge Coverage

The expert subagents know about:

**Components**
- Manifests (plugin.json)
- Commands (markdown with frontmatter)
- Hooks (SessionStart, SessionEnd, UserPromptSubmit, Stop, SubagentStop, PreToolUse, PostToolUse)
- Skills
- Subagents
- MCP Servers

**Patterns**
- Database recording (Courtney pattern)
- Code generation (scaffolding)
- Analysis tools (subagents)

**Best Practices**
- Security (parameterized queries, path validation)
- Performance (fast hooks, resource limits)
- Reliability (error handling, graceful degradation)
- Testing
- Documentation

### Testing

- Unit tests for scaffolder and validator (13 tests)
- Manual testing with real plugins recommended
- Dogfooding: `/pluggy:audit .` on Pluggy itself

### Documentation

- README with usage examples
- CLAUDE.md with development guidelines
- Comprehensive plugin knowledge base
- Inline command documentation

### Technical Details

- Pure Python stdlib (no external dependencies)
- Python 3.7+ compatible
- Subagent-based architecture
- Knowledge injection pattern

## Upcoming Features (Planned)

### [1.4.0]
- `/pluggy:test` - Generate and run plugin tests
- Enhanced security analysis

### [1.5.0]
- `/pluggy:publish` - Publish to marketplace
- `/pluggy:upgrade` - Migrate to new patterns
- Version compatibility checking

### [2.0.0]
- Custom knowledge base extensions
- Plugin dependency resolution
- Multi-language support (JavaScript, etc.)

[1.3.0]: https://github.com/acostanzo/quickstop/releases/tag/pluggy-v1.3.0
[1.2.0]: https://github.com/acostanzo/quickstop/releases/tag/pluggy-v1.2.0
[1.1.0]: https://github.com/acostanzo/quickstop/releases/tag/pluggy-v1.1.0
[1.0.0]: https://github.com/acostanzo/quickstop/releases/tag/pluggy-v1.0.0
