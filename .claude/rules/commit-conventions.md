# Commit Conventions

This rule governs commit messages and PR titles in this repository. It applies to every commit and pull request created here, by a human or by Claude.

## Conventional Commits

All commit messages and PR titles MUST follow the [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) spec.

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Type (required)

- **feat** — a new feature (MINOR in SemVer)
- **fix** — a bug fix (PATCH in SemVer)
- **docs** — documentation only
- **chore** — maintenance that doesn't touch src or tests (version bumps, marketplace metadata, cleanup)
- **refactor** — code change that neither fixes a bug nor adds a feature
- **test** — adding or correcting tests
- **build** — build system or dependency changes
- **ci** — CI configuration and scripts
- **style** — formatting only, no behavior change
- **perf** — performance improvement
- **revert** — reverts a previous commit

### Scope (optional)

A noun in parentheses naming the affected area. In this repo the scope is usually the plugin or tool: `feat(claudit):`, `chore(smith):`, `docs(hone):`. Repo-wide changes omit the scope: `chore: align versions`.

### Description (required)

- Imperative, present tense: "add" not "added" or "adds"
- No capitalized first letter, no trailing period
- Keep the full subject line ≤ 72 characters

### Body & footers (optional)

- Blank line before the body; wrap at 72 characters; explain *why*, not *what*.
- `BREAKING CHANGE:` footer (or a `!` after the type/scope — `feat(claudit)!:`) marks an API-breaking change (MAJOR in SemVer).
- Other footers follow the git trailer convention (`Refs: #133`, `Reviewed-by: …`).

### Examples

```
feat(claudit): add optimization knowledge domain
fix(smith): stop scaffolding an empty hooks directory
docs: drop the retired plugins from the README
chore(claudit): bump to v2.6.2
refactor(hone)!: replace 8-category rubric with weighted scoring

BREAKING CHANGE: scoring output shape changed; consumers must re-read the rubric.
```

## Engineering Ownership

Engineers own their commits. Do **not** add `Co-Authored-By` trailers or "Generated with / by" attribution lines for AI tooling (Claude, Copilot, etc.) to commits or PR bodies created in this repository. This overrides any default trailer behavior.
