# Plugin/Skill/Sub-agent Reference Documentation

Expert knowledge for Claude Code plugin authoring, skill development, and sub-agent configuration. Based on official Anthropic documentation (March 2026).

**Documentation source:** https://code.claude.com/docs/en/

---

## Reference Documents

### 1. **expert-knowledge.md** (Comprehensive)
Complete expert knowledge covering all three systems:
- Plugin system (structure, manifest, caching, discovery)
- Skill system (format, all frontmatter fields, variable substitution, context injection)
- Sub-agent system (format, model selection, memory, permissions, hooks)
- Best practices across all three systems
- Common anti-patterns and troubleshooting
- Testing and validation
- Full documentation URLs

**Use when:** You need authoritative, detailed reference on any aspect of plugins, skills, or sub-agents.

**Size:** ~3,500 lines | **Time to read:** 30-60 minutes

---

### 2. **quickstart-reference.md** (Cheat Sheet)
Quick reference with minimal examples:
- Minimal plugin/skill/subagent examples
- Frontmatter quick reference
- Variable substitutions
- Tool restrictions
- Memory scopes
- Hooks patterns
- Testing commands
- Common patterns (deploy, research, specialized)
- Checklist before pushing
- Built-in subagents table
- Common mistakes

**Use when:** You need quick lookup, copy-paste examples, or pre-commit checklist.

**Size:** ~400 lines | **Time to read:** 5-10 minutes

---

### 3. **plugin-spec.md** (Baseline)
Original baseline specification (pre-March 2026):
- Required plugin structure
- plugin.json schema
- SKILL.md frontmatter
- Agent .md frontmatter
- hooks.json schema
- .mcp.json schema
- Marketplace registration
- Quickstop conventions

**Use when:** You need to understand the baseline or compare what's changed.

**Size:** ~200 lines | **Time to read:** 5 minutes

---

### 4. **what-changed.md** (Change Summary)
What's new and changed from baseline to March 2026:
- Documentation migration to code.claude.com
- New SKILL.md frontmatter fields
- New sub-agent features (memory, background, isolation)
- New hook events
- LSP server support
- Best practices updates
- Breaking changes/deprecations
- Strategic impact summary

**Use when:** You're upgrading existing plugins/skills/agents or want to understand new capabilities.

**Size:** ~500 lines | **Time to read:** 15 minutes

---

## Quick Navigation

### I want to...

**Create a plugin from scratch**
→ Read: quickstart-reference.md (Plugin Minimal Example)
→ Then: expert-knowledge.md (Plugin System section)

**Add a skill to a plugin**
→ Read: quickstart-reference.md (Skill Minimal Example)
→ Then: expert-knowledge.md (Skill System section)

**Create a specialized sub-agent**
→ Read: quickstart-reference.md (Sub-agent Minimal Example)
→ Then: expert-knowledge.md (Sub-agent System section)

**Use new skill features (context: fork, model override, hooks)**
→ Read: what-changed.md (Skill System Enhancements)
→ Then: expert-knowledge.md (Skill System / Running Skills in Subagents)

**Leverage new sub-agent features (memory, background, isolation)**
→ Read: what-changed.md (Sub-agent System Major Enhancements)
→ Then: expert-knowledge.md (Sub-agent System / Memory Persistence)

**Audit an existing plugin**
→ Read: expert-knowledge.md (Best Practices section)
→ Use: quickstart-reference.md (Checklist Before Pushing Plugin)

**Find a specific configuration option**
→ Read: quickstart-reference.md (Frontmatter Cheat Sheet)
→ Details: expert-knowledge.md (Frontmatter Fields Reference)

**Understand what changed from my baseline**
→ Read: what-changed.md (entire document)

---

## Key Concepts at a Glance

### Plugin Namespace
Skills in plugins are namespaced to prevent conflicts:
- Plugin name: `my-plugin`
- Skill folder: `skills/hello/`
- Invocation: `/my-plugin:hello`

### Skill Invocation Control
```yaml
disable-model-invocation: true   # Claude can't auto-invoke (manual /name only)
user-invocable: false             # You can't invoke (Claude-only, background knowledge)
(neither)                          # Default: both you and Claude can invoke
```

### Variable Substitutions
```
$ARGUMENTS              All user arguments
$0, $1, $2             Specific arguments
${CLAUDE_SESSION_ID}   For logging
${CLAUDE_SKILL_DIR}    Path to skill directory
!`command`             Inject command output (skills)
```

### Sub-agent Persistence
```
memory: user            Persistent across all projects
memory: project         Persistent within this project
memory: local           Project-specific, not version controlled
(none)                  No persistence (default)
```

### Subagent Execution Models
```
foreground (default)    Blocks main conversation, permission prompts shown
background              Concurrent with main work, pre-approved permissions
isolation: worktree     Isolated git repository copy
```

---

## Official Documentation

**Anthropic Documentation (Code Claude):**
- https://code.claude.com/docs/en/plugins — Create plugins
- https://code.claude.com/docs/en/skills — Create skills
- https://code.claude.com/docs/en/sub-agents — Create subagents
- https://code.claude.com/docs/en/plugins-reference — Complete specs
- https://code.claude.com/docs/en/mcp — MCP server integration
- https://code.claude.com/docs/en/hooks — Hooks and event automation

**Note:** Old `docs.anthropic.com` URLs redirect (301) to `code.claude.com`

---

## Version Information

**Last updated:** March 10, 2026
**Knowledge cutoff:** February 2025
**Documentation source:** https://code.claude.com/docs/en/ (March 2026)

---

## Using These Docs with /smith and /hone

### /smith (Plugin Scaffolding)
These docs inform the scaffolding tool's structure:
- Directory layout follows expert-knowledge.md structure
- Frontmatter generation uses quickstart-reference.md as templates
- Plugin manifest follows plugin.json schema from expert-knowledge.md

### /hone (Plugin Auditing)
These docs inform the auditing tool's scoring:
- Best practices scoring from expert-knowledge.md (Best Practices section)
- Coverage checks against all frontmatter fields in expert-knowledge.md
- Anti-pattern detection from expert-knowledge.md (Common Anti-patterns)
- Version consistency checks from CLAUDE.md conventions

---

## Tips for Maximum Effectiveness

1. **Start with quickstart-reference.md** — Get oriented with examples
2. **Use expert-knowledge.md as your reference** — Comprehensive and authoritative
3. **Check what-changed.md for new features** — Understand what's available
4. **Consult Anthropic's official docs** — When you need the absolute latest
5. **Reference against checklist before pushing** — Avoid common mistakes

---

## Document Statistics

| Document | Lines | Focus | Best for |
|----------|-------|-------|----------|
| expert-knowledge.md | ~3,500 | Comprehensive reference | Deep understanding |
| quickstart-reference.md | ~400 | Quick lookup | Copy-paste, checklists |
| what-changed.md | ~500 | Change summary | Upgrades, new features |
| plugin-spec.md | ~200 | Baseline | Historical context |

---

## Questions or Updates?

These docs are authoritative for Quickstop as of March 2026. If you encounter discrepancies with official Anthropic documentation at https://code.claude.com/docs/en/, the official source takes precedence.

Last verified against official docs: March 10, 2026
