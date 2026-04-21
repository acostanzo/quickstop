# Roll Your Own — Lint / Format / Language Rules

How to achieve the `lint-posture` dimension's readiness without installing the forthcoming `lintguini` plugin.

Lintguini (Phase 2+) is the recommended depth auditor. Until it ships, this document covers the manual setup.

## What "good" looks like

- A **formatter** runs automatically on save / commit. Disagreements about whitespace don't reach human review.
- A **linter** catches mistakes the compiler doesn't: unused variables, shadowed bindings, simplifiable expressions, forgotten `await`, suspicious equality comparisons.
- **Type-checking** (where applicable) is part of CI — not a local-only hope.
- **Rules are portable.** Config lives in `pyproject.toml` / `Cargo.toml` / `.eslintrc.json`, not a developer's editor settings.
- **Exceptions are inline and justified.** `# noqa: E501 — deliberately long CLI arg demonstration` beats a top-of-file blanket disable.

## Minimum viable setup by language

### Python

```toml
# pyproject.toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM", "RUF"]
ignore = ["E501"]  # line length handled by formatter

[tool.ruff.format]
quote-style = "double"
```

Run `ruff check .` and `ruff format .` on save.

### TypeScript / JavaScript

```json
// biome.json
{
  "$schema": "https://biomejs.dev/schemas/latest/schema.json",
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "linter": { "enabled": true, "rules": { "recommended": true } }
}
```

Or ESLint + Prettier if you prefer; Biome is faster and unified.

### Rust

```toml
# rustfmt.toml
edition = "2021"
max_width = 100
```

```toml
# Cargo.toml
[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
pedantic = "warn"
```

Run `cargo fmt` and `cargo clippy` in CI.

### Go

```yaml
# .golangci.yml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
```

`golangci-lint run` in CI; `gofmt -w .` locally.

## Editor / pre-commit hookup

```yaml
# .lefthook.yml
pre-commit:
  commands:
    format:
      glob: "*.{py,ts,tsx,rs,go}"
      run: <formatter> {staged_files}
```

## Periodic audit checklist

- Config file checked in, not `.editorconfig`-only?
- CI runs the linter and fails the build on warnings you've promoted to errors?
- Any file with a blanket disable at the top? Can it be replaced with per-rule inline comments?
- Anyone's editor pulling a different config from their personal dotfiles than what CI uses?
- Formatter version pinned (devDeps or tool-versions)? Unpinned formatters drift.

## Common anti-patterns

- **`"lint": "echo 'todo'"`** in package.json. Invisible until you need it. Bad.
- **Unified linter config for a polyglot repo.** Each language has its own tool; conceded. Don't try to make one tool's config dictate another's.
- **`disable-next-line` on every second line.** The config is wrong; fix the config.
- **Format-on-save disagreement between team members.** Lock the version; keep config in-repo.

## Presence check pronto uses

Pronto's kernel presence check for this dimension passes if any of these exist: `.eslintrc*`, `.prettierrc*`, `pyproject.toml` containing a `[tool.*]` lint block, `.flake8`, `rustfmt.toml`, `Cargo.toml` containing `[lints]`, `.golangci.yml`, `biome.json`, `dprint.json`. Presence-cap is 50 until a depth auditor runs.

## Concrete first step

Add the formatter + linter for your repo's primary language. That single commit will already move the dimension out of `presence-fail` into `presence-cap:50` — and once lintguini ships, the depth audit can start rewarding actual config quality.
