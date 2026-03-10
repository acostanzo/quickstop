# Conventional Commits Specification Summary

Source: https://www.conventionalcommits.org/en/v1.0.0/

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Structural Elements

### Type (required)
Describes the category of change:

- **feat** — introduces a new feature (correlates with MINOR in SemVer)
- **fix** — patches a bug (correlates with PATCH in SemVer)
- **build** — changes to build system or external dependencies
- **chore** — maintenance tasks that don't modify src or test files
- **ci** — changes to CI configuration files and scripts
- **docs** — documentation only changes
- **style** — changes that do not affect the meaning of the code (whitespace, formatting, semicolons)
- **refactor** — code change that neither fixes a bug nor adds a feature
- **perf** — code change that improves performance
- **test** — adding missing tests or correcting existing tests
- **revert** — reverts a previous commit

### Scope (optional)
A noun describing the section of the codebase, in parentheses after the type:
- `feat(parser):` — feature in the parser module
- `fix(api):` — bug fix in the API layer

### Description (required)
A short summary of the code change:
- Use imperative, present tense: "add" not "added" or "adds"
- Don't capitalize the first letter
- No period at the end
- Maximum 72 characters for the full subject line (type + scope + description)

### Body (optional)
- Separated from the subject by a blank line
- Free-form, can consist of multiple paragraphs
- Use to explain the motivation for the change and contrast with previous behavior
- Wrap at 72 characters

### Footer(s) (optional)
- Separated from the body by a blank line
- Format: `token: value` or `token #value`
- `BREAKING CHANGE:` footer describes an API breaking change (correlates with MAJOR in SemVer)
- Other footers follow the git trailer convention (e.g., `Reviewed-by:`, `Refs:`)

## Breaking Changes

Indicated by either:
1. A `!` appended after the type/scope: `feat!:` or `feat(api)!:`
2. A `BREAKING CHANGE:` footer

Both can be used together. A breaking change can be part of any type.

## Examples

Simple feature:
```
feat: add email notifications for new signups
```

Feature with scope:
```
feat(auth): add OAuth2 login support
```

Fix with body:
```
fix(api): prevent racing of requests

Introduce a request ID and reference to latest request.
Dismiss incoming responses other than from latest request.
```

Breaking change with footer:
```
feat(api)!: remove deprecated /users/list endpoint

BREAKING CHANGE: The /users/list endpoint has been removed.
Use /users with pagination instead.
```

Chore:
```
chore(deps): update dependency lodash to v4.17.21
```

Multiple footers:
```
fix(core): correct minor typos in code

Refs: #133
Reviewed-by: Z
```
