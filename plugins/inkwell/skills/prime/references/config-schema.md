# .inkwell.json Schema

Configuration file that drives all Inkwell detection and output paths. Lives in the project root.

## Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | `number` | Yes | Schema version. Currently `1`. |
| `stack` | `string` | Yes | Detected project stack: `"typescript"`, `"go"`, `"rust"`, `"python"`, or `"generic"`. Informational — does not affect behavior at runtime. |
| `docs` | `object` | Yes | Map of doc type names to their configuration. |

## Doc Type Configuration

Each key under `docs` is a doc type name. All doc types share this shape:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enabled` | `boolean` | Yes | Whether this doc type is active. Disabled types are skipped by hooks and agents. |
| `file` | `string` | Conditional | Output file path, relative to project root. Required for types that produce a single file. |
| `directory` | `string` | Conditional | Output directory path, relative to project root. Required for types that produce multiple files (e.g., `api-reference`). |
| `paths` | `string[]` | No | Glob patterns for matching changed files by path. If a changed file matches any glob, the doc type is triggered. |
| `patterns` | `string[]` | No | Regex patterns for matching changed file contents. If a changed file's content matches any pattern, the doc type is triggered. Used as a fallback when `paths` alone is insufficient. |

### Constraints

- Exactly one of `file` or `directory` must be present (not both).
- `paths` and `patterns` are both optional. A doc type with neither (e.g., `changelog`, `architecture`) is triggered by other means (commit message format, structural heuristics).
- Glob patterns in `paths` use standard glob syntax (`**` for recursive, `*` for single-level).
- Regex patterns in `patterns` use POSIX Extended Regular Expression syntax (compatible with `grep -E`).

## Doc Types

### changelog

Triggered by conventional commit messages (`feat:`, `fix:`, `refactor:`, etc.), not by file matching.

```json
{
  "enabled": true,
  "file": "CHANGELOG.md"
}
```

### api-reference

Triggered when changed files match `paths` globs. Produces one doc file per source module in the output `directory`.

```json
{
  "enabled": true,
  "directory": "docs/reference/",
  "paths": ["src/**", "lib/**", "app/**"]
}
```

### api-contract

Triggered when changed files match `paths` globs OR file contents match `patterns` regexes. Produces a single endpoint table.

```json
{
  "enabled": true,
  "file": "docs/reference/api.md",
  "paths": ["src/routes/**", "src/api/**", "app/controllers/**", "routes/**", "api/**"],
  "patterns": ["app\\.(get|post|put|patch|delete)\\(", "router\\.(get|post|put|patch|delete|use|all|route)\\(", "@(Get|Post|Put|Patch|Delete)"]
}
```

### env-config

Triggered when changed files match `paths` globs OR file contents match `patterns` regexes. Produces a single variable table.

```json
{
  "enabled": true,
  "file": "docs/reference/configuration.md",
  "paths": [".env*", "config/**", "src/config/**"],
  "patterns": ["process\\.env\\.", "Deno\\.env"]
}
```

### domain-scaffold

Triggered when newly added files match `paths` globs. Produces skeleton entries for new models.

```json
{
  "enabled": true,
  "file": "docs/reference/domain.md",
  "paths": ["src/models/**", "src/entities/**", "src/types/**", "models/**", "domain/**"]
}
```

### architecture

Triggered by structural heuristics (many new top-level directories). No `paths` or `patterns` needed.

```json
{
  "enabled": true,
  "file": "docs/ARCHITECTURE.md"
}
```

### index

Triggered when doc files are added or removed. Matches against `paths` to detect doc changes.

```json
{
  "enabled": true,
  "file": "docs/INDEX.md",
  "paths": ["docs/**/*.md"]
}
```

## Full Example

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
