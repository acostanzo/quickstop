---
name: capture
description: Scan recent changes and extract durable knowledge into docs
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep, Write, Edit
---

# Capture

Scan recent git changes and extract durable knowledge into project documentation. This skill analyzes what changed, determines what documentation should exist, and creates or updates it.

## `/inkwell:capture $ARGUMENTS`

### Phase 1: Determine Scope

If `$ARGUMENTS` is provided, parse it as a commit range or count:
- A number (e.g., `5`) — scan the last N commits
- A range (e.g., `abc123..HEAD`) — scan that range
- Empty — scan since the last capture

To detect "since last capture," check for a `.inkwell-last-capture` file in the project root. If it exists, read the stored commit hash and use `<hash>..HEAD`. If it doesn't exist, default to scanning the last 5 commits.

### Phase 2: Analyze Changes

Run `git log --oneline <range>` to list commits in scope.

For each commit, run `git diff <commit>~1..<commit> --name-only` to see what files changed.

Categorize each change:

| File Pattern | Doc Type | Target |
|---|---|---|
| `src/**`, `lib/**`, `app/**` | api-reference | `docs/reference/` |
| New top-level directories, major restructuring | architecture | `docs/ARCHITECTURE.md` |
| Any `feat:` or `fix:` commit | changelog | `CHANGELOG.md` |
| Any file in `docs/` added or removed | index | `docs/INDEX.md` |

### Phase 3: Generate Documentation

For each category with changes:

**api-reference**: Read the changed source files. Identify public exports, route definitions, or API endpoints. Create or update a corresponding doc file in `docs/reference/`. Use the module or file name as the doc filename (e.g., `src/auth.ts` maps to `docs/reference/auth.md`).

**changelog**: Parse the conventional commit messages in range. Group by type (Added for `feat:`, Fixed for `fix:`, Changed for `refactor:`). Append a new version section to `CHANGELOG.md` following Keep a Changelog format. If `CHANGELOG.md` doesn't exist, create it with the standard header.

**architecture**: For new modules or major restructuring, append a section to `docs/ARCHITECTURE.md` describing the new component, its purpose, and how it fits into the system. If the file doesn't exist, create it with a basic template.

**index**: Run the same logic as `/inkwell:index` — glob all markdown files in `docs/` and rebuild `docs/INDEX.md`.

### Phase 4: Commit and Record

If any documentation was created or updated:

1. Stage all doc changes with `git add`
2. Commit with message: `docs: update documentation from recent changes`
3. Update `.inkwell-last-capture` with the current HEAD hash

### Error Handling

- If the git range is invalid, report the error and suggest a valid range
- If `docs/` directory doesn't exist, create it
- Never modify source code — only documentation files
