---
name: prime
description: Guided interactive setup that creates .inkwell.json configuration for the project
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep, Write, Edit
---

# Prime

Guided interactive setup that creates or updates `.inkwell.json` — the configuration file that drives all Inkwell detection and output paths. Idempotent: safe to re-run on an existing config.

## `/inkwell:prime`

### Phase 1: Detect Project Stack

Inspect the project root for stack indicators:

| Indicator | Stack |
|-----------|-------|
| `package.json` or `tsconfig.json` | TypeScript / Node |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pyproject.toml`, `setup.py`, or `requirements.txt` | Python |

If multiple indicators exist, prefer the first match in the order above. If none match, use "generic" defaults.

### Phase 2: Scan for Existing Documentation

Before configuring defaults, scan the project for existing documentation files that Inkwell doc types would overlap with:

| Doc Type | Scan Locations |
|----------|---------------|
| `architecture` | `ARCHITECTURE.md`, `docs/architecture.md`, `docs/reference/architecture.md`, `docs/ARCHITECTURE.md` |
| `changelog` | `CHANGELOG.md`, `CHANGES.md`, `changelog.md` |
| `index` | `docs/INDEX.md`, `docs/index.md` |
| ADR directories | `docs/decisions/`, `docs/adr/`, `docs/adrs/` |
| General docs | `docs/` (note any existing structure) |

Store discovered paths for use in Phase 4. If a `docs/` directory exists, note its layout so that output paths can be suggested consistently with the existing structure.

### Phase 3: Load Existing Config

If `.inkwell.json` already exists, read it. Present a summary of the current configuration and ask the user whether to update it or start fresh.

### Phase 4: Configure Doc Types

For each doc type below, present the stack-appropriate defaults and ask the user whether to enable it. Accept `y`/`n` (default `y` for all except `domain-scaffold` which defaults to `n`).

**Use discovered files from Phase 2:** If an existing file was found that matches a doc type, suggest that path instead of the generic default. For example:

- Found `docs/reference/architecture.md` → suggest it for `architecture` output instead of `docs/ARCHITECTURE.md`
- Found `CHANGES.md` → suggest it for `changelog` output instead of `CHANGELOG.md`
- Found `docs/decisions/` → mention it when configuring ADR paths in the confirm step

Present the suggestion clearly: *"I found an existing architecture doc at `docs/reference/architecture.md` — should I use that path? [Y/n]"*

For enabled types, show the output path (discovered or default) and path/pattern globs. Let the user accept or override.

#### Stack Defaults

**TypeScript / Node:**

| Doc Type | Output | Paths | Patterns |
|----------|--------|-------|----------|
| `changelog` | `CHANGELOG.md` | — | — |
| `api-reference` | `docs/reference/` | `src/**`, `lib/**`, `app/**` | — |
| `api-contract` | `docs/reference/api.md` | `src/routes/**`, `src/api/**`, `app/controllers/**`, `routes/**`, `api/**` | `app\.(get\|post\|put\|patch\|delete)\(`, `router\.(get\|post\|put\|patch\|delete\|use\|all\|route)\(`, `@(Get\|Post\|Put\|Patch\|Delete)` |
| `env-config` | `docs/reference/configuration.md` | `.env*`, `config/**`, `src/config/**` | `process\.env\.`, `Deno\.env` |
| `domain-scaffold` | `docs/reference/domain.md` | `src/models/**`, `src/entities/**`, `src/types/**`, `models/**`, `domain/**` | — |
| `architecture` | `docs/ARCHITECTURE.md` | — | — |
| `index` | `docs/INDEX.md` | `docs/**/*.md` | — |

**Go:**

| Doc Type | Output | Paths | Patterns |
|----------|--------|-------|----------|
| `changelog` | `CHANGELOG.md` | — | — |
| `api-reference` | `docs/reference/` | `cmd/**`, `pkg/**`, `internal/**` | — |
| `api-contract` | `docs/reference/api.md` | `cmd/**/handler*`, `internal/api/**`, `internal/handler/**` | `\.HandleFunc\(`, `\.Handle\(`, `r\.(Get\|Post\|Put\|Patch\|Delete)\(` |
| `env-config` | `docs/reference/configuration.md` | `.env*`, `config/**` | `os\.Getenv` |
| `domain-scaffold` | `docs/reference/domain.md` | `internal/models/**`, `internal/domain/**`, `pkg/models/**` | — |
| `architecture` | `docs/ARCHITECTURE.md` | — | — |
| `index` | `docs/INDEX.md` | `docs/**/*.md` | — |

**Rust:**

| Doc Type | Output | Paths | Patterns |
|----------|--------|-------|----------|
| `changelog` | `CHANGELOG.md` | — | — |
| `api-reference` | `docs/reference/` | `src/**` | — |
| `api-contract` | `docs/reference/api.md` | `src/routes/**`, `src/api/**`, `src/handlers/**` | `#\[get\(`, `#\[post\(`, `#\[put\(`, `#\[patch\(`, `#\[delete\(`, `\.route\(` |
| `env-config` | `docs/reference/configuration.md` | `.env*`, `config/**` | `std::env::var`, `env::var` |
| `domain-scaffold` | `docs/reference/domain.md` | `src/models/**`, `src/entities/**`, `src/domain/**` | — |
| `architecture` | `docs/ARCHITECTURE.md` | — | — |
| `index` | `docs/INDEX.md` | `docs/**/*.md` | — |

**Python:**

| Doc Type | Output | Paths | Patterns |
|----------|--------|-------|----------|
| `changelog` | `CHANGELOG.md` | — | — |
| `api-reference` | `docs/reference/` | `app/**`, `src/**`, `lib/**` | — |
| `api-contract` | `docs/reference/api.md` | `app/views/**`, `src/routes/**`, `app/routes/**`, `app/api/**` | `@app\.(get\|post\|put\|patch\|delete)\(`, `@router\.(get\|post\|put\|patch\|delete)\(`, `path\(` |
| `env-config` | `docs/reference/configuration.md` | `.env*`, `config/**`, `src/config/**` | `os\.environ`, `os\.getenv` |
| `domain-scaffold` | `docs/reference/domain.md` | `app/models/**`, `src/models/**`, `models/**` | — |
| `architecture` | `docs/ARCHITECTURE.md` | — | — |
| `index` | `docs/INDEX.md` | `docs/**/*.md` | — |

**Generic (no stack detected):**

Use the TypeScript/Node defaults but omit framework-specific patterns from `api-contract` and `env-config`.

### Phase 5: Write .inkwell.json

Write the config file to the project root. Use the schema defined in `references/config-schema.md`.

Example output for a TypeScript project with all types enabled:

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
      "paths": ["src/routes/**", "src/api/**", "app/controllers/**", "routes/**", "api/**"],
      "patterns": ["app\\.(get|post|put|patch|delete)\\(", "router\\.(get|post|put|patch|delete|use|all|route)\\(", "@(Get|Post|Put|Patch|Delete)"]
    },
    "env-config": {
      "enabled": true,
      "file": "docs/reference/configuration.md",
      "paths": [".env*", "config/**", "src/config/**"],
      "patterns": ["process\\.env\\.", "Deno\\.env"]
    },
    "domain-scaffold": {
      "enabled": false,
      "file": "docs/reference/domain.md",
      "paths": ["src/models/**", "src/entities/**", "src/types/**", "models/**", "domain/**"]
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

### Phase 6: Recommend .gitignore Additions

Check if `.gitignore` exists and whether it already contains inkwell runtime entries. If missing, suggest:

```
.inkwell-queue.json
.inkwell-last-capture
```

Ask the user whether to append them automatically.

### Phase 7: Confirm

Output a summary:

```
Inkwell configured for <stack> project.

Enabled doc types:
  - changelog → CHANGELOG.md
  - api-reference → docs/reference/
  - api-contract → docs/reference/api.md
  - env-config → docs/reference/configuration.md
  - architecture → docs/ARCHITECTURE.md
  - index → docs/INDEX.md

Config written to .inkwell.json
Run /inkwell:capture to generate docs from existing commits.
```
