# Commventional — Commit & Comment Conventions

These rules apply to ALL commits, PRs, and review feedback in this session.
Project-level CLAUDE.md instructions take precedence if they define their own conventions.

## 1. Conventional Commits

All commits MUST follow the Conventional Commits specification:

```
<type>[(scope)]: <description>

[optional body]

[optional footer(s)]
```

**Types:** feat, fix, docs, style, refactor, perf, test, build, ci, chore

**Rules:**
- Use imperative mood ("add feature" not "added feature")
- Lowercase type and description
- No trailing period on the description line
- Breaking changes: append `!` after type/scope OR add `BREAKING CHANGE:` footer
- Scope is optional and should be a noun describing the section of the codebase

**Examples:**
- `feat(auth): add OAuth2 login flow`
- `fix: resolve null pointer in user lookup`
- `refactor!: drop support for Node 14`

**NEVER add Co-Authored-By, AI attribution, or any automated attribution lines to commits.**

## 2. PR Conventions

**PR titles** follow conventional commit format: `<type>[(scope)]: <description>`

**PR descriptions** use this structure:

```markdown
## Summary
<1-3 sentences describing the change>

## Changes
- <bullet list of notable changes>

## Test plan
- [ ] <checklist of verification steps>
```

**NEVER add AI attribution footers to PR descriptions.**

## 3. Conventional Comments

When providing code review feedback — both in-session discussion and when posting comments to PRs — use the Conventional Comments format:

```
<label> [decorations]: <subject>

[discussion]
```

**Labels:**
- **praise:** Highlight something positive
- **nitpick:** Trivial, preference-based suggestion
- **suggestion:** Propose an improvement to the current approach
- **issue:** Identify a problem that needs to be addressed
- **todo:** A small, necessary change
- **question:** Ask for clarification or more information
- **thought:** Share an observation that doesn't require action
- **chore:** Maintenance task (formatting, cleanup)
- **note:** Provide context or information

**Decorations** (in parentheses after label):
- **(non-blocking):** Does not prevent merging
- **(blocking):** Must be resolved before merging
- **(if-minor):** Only address if the change is small

**Examples:**
- `suggestion (non-blocking): Consider extracting this into a helper`
- `issue (blocking): This query is vulnerable to SQL injection`
- `praise: Clean separation of concerns here`
- `nitpick (non-blocking): Prefer const over let for immutable bindings`

Labels make feedback actionable and set clear expectations for the author.
