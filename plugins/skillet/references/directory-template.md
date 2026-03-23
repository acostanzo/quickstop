# Opinionated Skill Directory Template

Enforced by `/skillet:build` and `/skillet:improve`. This template defines the canonical structure for Claude Code skills.

## Project Skills (`.claude/`)

```
.claude/
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md              # REQUIRED — skill definition with frontmatter
│       └── references/           # OPTIONAL — heavy content loaded on demand
│           └── *.md
├── agents/                       # Shared agents across skills
│   └── <agent-name>.md
└── hooks/                        # Centralized hook config (if needed)
    └── hooks.json
```

## Plugin Skills (`plugins/<plugin>/`)

```
plugins/<plugin>/
├── .claude-plugin/
│   └── plugin.json               # Plugin metadata
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md              # REQUIRED
│       └── references/           # OPTIONAL
│           └── *.md
├── agents/                       # Shared agents across plugin skills
│   └── <agent-name>.md
├── hooks/                        # Plugin hook config (if needed)
│   └── hooks.json
├── references/                   # Plugin-wide reference files
│   └── *.md
└── README.md
```

## Rules

### What Goes Where

| Content | Location | Why |
|---------|----------|-----|
| Skill definition | `skills/<name>/SKILL.md` | Skill orchestration and instructions |
| Heavy reference content | `skills/<name>/references/*.md` | Loaded on demand via `${SKILL_ROOT}`, not always in context |
| Shared reference content | `references/*.md` (plugin root) | Shared across multiple skills via `${CLAUDE_PLUGIN_ROOT}` |
| Sub-agent definitions | `agents/<name>.md` | Shared resources, not owned by a single skill |
| Hook configuration | `hooks/hooks.json` | Centralized, one file per plugin/project |
| Utility scripts | `scripts/*.sh` | Shell scripts for hooks or development |

### Constraints

1. **SKILL.md is the only required file** in a skill directory
2. **`references/` is the only allowed subdirectory** inside a skill directory
3. **No loose files** in skill directories — everything else goes in standard locations
4. **No empty directories** — only create directories that have content
5. **kebab-case everywhere** — directories, files, skill names, agent names
6. **Agents are shared** — place them in `agents/` at the parent level, not inside skill directories
7. **One hooks.json** — centralized hook config, not per-skill

### Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Agent .md inside `skills/<name>/` | Agents are shared resources | Move to `agents/` |
| Multiple hooks.json files | Hook config should be centralized | Merge into one `hooks/hooks.json` |
| Scripts inside skill directories | Scripts are utilities, not skill content | Move to `scripts/` |
| Deeply nested references | Hard to discover and maintain | Flatten to `references/*.md` |
| Non-kebab-case names | Inconsistent naming | Rename to kebab-case |
| Empty `references/` directory | Unnecessary structure | Remove empty directory |
