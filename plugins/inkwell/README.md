# Inkwell (v0.3.3)

Automatic documentation-as-code engine for Claude Code projects. Inkwell works automatically via hooks, but also provides commands for manual control.

## Getting Started

Run `/inkwell:prime` to create `.inkwell.json` — the configuration file that drives all detection and output paths. The setup wizard detects your project stack and suggests sensible defaults.

```
/inkwell:prime
→ Detected: TypeScript / Node
→ Enabled: changelog, api-reference, api-contract, env-config, architecture, index
→ Config written to .inkwell.json
```

Without `.inkwell.json`, the hook falls back to changelog-only detection (no config needed for commit-message-based triggers).

## Configuration

Inkwell is driven by `.inkwell.json` in the project root. Each doc type can be independently enabled/disabled with custom output paths and detection patterns.

```json
{
  "version": 1,
  "stack": "typescript",
  "docs": {
    "changelog": {
      "enabled": true,
      "file": "CHANGELOG.md"
    },
    "api-reference": {
      "enabled": true,
      "directory": "docs/reference/",
      "paths": ["src/**", "lib/**", "app/**"]
    },
    "api-contract": {
      "enabled": true,
      "file": "docs/reference/api.md",
      "paths": ["src/routes/**", "src/api/**"],
      "patterns": ["router\\.(get|post|put|patch|delete)\\("]
    },
    "env-config": {
      "enabled": true,
      "file": "docs/reference/configuration.md",
      "paths": [".env*", "config/**"],
      "patterns": ["process\\.env\\."]
    },
    "domain-scaffold": {
      "enabled": false,
      "file": "docs/reference/domain.md",
      "paths": ["src/models/**", "src/entities/**"]
    },
    "architecture": {
      "enabled": true,
      "file": "docs/ARCHITECTURE.md"
    },
    "index": {
      "enabled": true,
      "file": "docs/INDEX.md",
      "paths": ["docs/**/*.md"]
    }
  }
}
```

Each doc type supports:
- `enabled` — whether the type is active
- `file` or `directory` — output path (exactly one)
- `paths` — glob patterns for matching changed files by path
- `patterns` — regex patterns for matching changed file contents (fallback when paths don't match)

See the full schema at `skills/prime/references/config-schema.md`.

## How It Works

Inkwell uses a **queue-based architecture** to separate detection from generation:

```
git commit → PostToolUse hook → .inkwell-queue.json → Stop hook → doc-writer agent → docs/ committed
```

1. **Detect** (PostToolUse hook on `Bash`): After any `git commit`, a lightweight hook reads `.inkwell.json` and matches changed files against configured `paths` and `patterns`. Matching doc tasks are appended to `.inkwell-queue.json`. This runs in <2s and never blocks your workflow.

2. **Queue** (`.inkwell-queue.json`): Tasks accumulate during a session. Each task records the commit hash, message, changed files, and what type of documentation is needed.

3. **Process** (Stop hook): When Claude's turn ends, the Stop hook checks the queue. If tasks are pending, it instructs Claude to dispatch the doc-writer agent to process them.

4. **Write** (doc-writer agent): Reads `.inkwell.json` for output paths, processes source changes, writes documentation, commits with `docs:` prefix, and clears the queue.

### What Gets Documented

| Type | Trigger | Output |
|------|---------|--------|
| `api-reference` | Changed files match configured `paths` | Configured `directory` (default `docs/reference/`) |
| `api-contract` | Files match `paths` or contents match `patterns` | Configured `file` (default `docs/reference/api.md`) |
| `env-config` | Files match `paths` or contents match `patterns` | Configured `file` (default `docs/reference/configuration.md`) |
| `domain-scaffold` | Newly added files match configured `paths` | Configured `file` (default `docs/reference/domain.md`) |
| `changelog` | `feat:`, `fix:`, `refactor:` commits | Configured `file` (default `CHANGELOG.md`) |
| `architecture` | New modules, major restructuring | Configured `file` (default `docs/ARCHITECTURE.md`) |
| `index` | Doc files added or removed matching `paths` | Configured `file` (default `docs/INDEX.md`) |

### Queue Format

```json
[
  {
    "type": "changelog",
    "commit": "abc1234",
    "message": "feat(auth): add OAuth2 support",
    "files": ["src/auth.ts", "src/oauth.ts"],
    "timestamp": "2026-04-01T10:00:00Z"
  }
]
```

## Commands

| Command | Description |
|---------|-------------|
| `/inkwell:prime` | Guided setup wizard — creates `.inkwell.json` for your project |
| `/inkwell:capture` | Scan recent commits and generate missing documentation |
| `/inkwell:adr <title>` | Create a numbered Architecture Decision Record |
| `/inkwell:changelog` | Generate or update changelog from conventional commits |
| `/inkwell:index` | Rebuild documentation index to match files on disk |
| `/inkwell:stale` | Find docs that are out of date relative to code changes |

## Agents

| Agent | Role | Dispatched By |
|-------|------|---------------|
| `doc-writer` | Reads source changes, writes documentation, commits | Stop hook, `/inkwell:capture` |
| `index-builder` | Scans doc directories, rebuilds index | `/inkwell:index` |

## Examples

### First-time setup

```
/inkwell:prime
→ Detected: TypeScript / Node
→ Configure doc types? [y/n for each]
→ Config written to .inkwell.json
→ Recommended: add .inkwell-queue.json and .inkwell-last-capture to .gitignore
```

### Automatic documentation (no commands needed)

```
You: "Add OAuth2 support to the auth module"
Claude: [writes code, commits with 'feat(auth): add OAuth2 support']
         ↓ PostToolUse hook fires, reads .inkwell.json
         ↓ Queue: [{type: "changelog", ...}, {type: "api-reference", ...}]
         ↓ Stop hook fires → doc-writer processes queue
         ↓ CHANGELOG.md updated, docs/reference/auth.md updated
         ↓ Committed: 'docs: update documentation from recent changes'
```

### Manual capture of recent work

```
/inkwell:capture 10        # scan last 10 commits
/inkwell:capture           # scan since last capture
```

### Create an ADR

```
/inkwell:adr Use PostgreSQL for session storage
→ Created ADR #0003: Use PostgreSQL for session storage
  → docs/decisions/0003-use-postgresql-for-session-storage.md
```

### Check for stale docs

```
/inkwell:stale
→ Very Stale: docs/reference/auth.md (src/auth.ts changed 64 days after doc)
→ Fresh: docs/decisions/0001-use-postgresql.md
→ Summary: 5 docs checked, 1 very stale, 4 fresh
```

## Bundled Rules

Inkwell ships rules that apply automatically to matching files when the plugin is installed.

| Rule | Globs | Purpose |
|------|-------|---------|
| `code-comments` | `*.ts`, `*.js`, `*.py`, `*.go`, `*.rs`, `*.java`, `*.rb` | Enforces meaningful comments — no narration, no commented-out code, TODOs must be actionable |

Rules are in `rules/` and follow the Claude Code [bundled rules](https://docs.anthropic.com/en/docs/claude-code/plugins) format.

## Requirements

- `jq` — JSON processing in hook scripts (optional: falls back to changelog-only without it)
- `git` — commit analysis and doc commits

## Installation

### From Quickstop Marketplace

Install directly from the marketplace registry. This is the easiest method for most users.

```bash
claude plugin install inkwell@quickstop
```

### From Local Source (Development)

If you have the quickstop repo cloned locally, install the plugin from disk. Use `--scope project` to scope it to the current project or `--scope user` for all projects.

```bash
claude plugin install --source /path/to/quickstop/plugins/inkwell --scope project
```

### Manual Copy

Copy the plugin directory into your project's plugin folder. Useful when you want full control or are working offline.

```bash
cp -r /path/to/quickstop/plugins/inkwell .claude/plugins/inkwell
```

After installing with any method, run `/inkwell:prime` to configure for your project.

## Safety

- Hook scripts exit cleanly on missing dependencies (jq, git) — never block
- Without `.inkwell.json`, the hook falls back to changelog-only detection
- `docs:` commits from inkwell are detected and skipped to prevent feedback loops
- The Stop hook only suggests processing — Claude decides whether to act
- Queue file (`.inkwell-queue.json`) is plain JSON, human-readable, and safe to delete at any time
- Skills are `disable-model-invocation: true` — they only run when explicitly invoked

**Gitignore:** Inkwell creates runtime files in your project root that should not be committed:

```bash
echo -e '.inkwell-queue.json\n.inkwell-last-capture' >> .gitignore
```

## License

MIT
