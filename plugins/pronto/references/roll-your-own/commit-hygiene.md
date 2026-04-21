# Roll Your Own — Commit + Review Hygiene

How to achieve the `commit-hygiene` dimension's readiness without installing `commventional`.

The recommended path is `/plugin install commventional@quickstop`. This document covers the manual equivalent.

## What "good" looks like

- Commits follow [conventional commits](https://www.conventionalcommits.org): `<type>(<scope>)!: <subject>` where type is one of `feat|fix|chore|docs|refactor|test|perf|build|ci|style`.
- One logical change per commit. Small. Reviewable in under five minutes.
- No `wip`, `fix typo`, `address review`, or `actually fix it` commits on main.
- Review feedback uses [conventional comments](https://conventionalcommits.org/): labels like `suggestion:`, `issue:`, `question:`, `nitpick:`, `praise:` — blocking/non-blocking is a property of the label, not a free-text prefix.
- No automated `Co-Authored-By` trailers on work that's attributed to an individual. If a tool wrote the code, the human who pushed the PR owns it.

## Minimum viable setup

### Commit-message enforcement via Lefthook

```yaml
# .lefthook.yml
commit-msg:
  commands:
    conventional-commit:
      run: |
        if ! grep -qE '^(feat|fix|chore|docs|refactor|test|perf|build|ci|style)(\([a-z0-9-]+\))?!?: .+' "$1"; then
          echo "Commit message does not match conventional commit format."
          exit 1
        fi
```

Install with `lefthook install`. Every local commit is checked.

### Squash vs rebase-merge

- **Rebase-and-merge** is the default if the branch has atomic commits.
- **Squash** only if the branch is genuinely WIP-shaped and can't be rebased into atomic commits.
- **Never plain merge-commit** — it pollutes main with merge bubbles.

### PR description template

```markdown
## Summary
<what changed and why — 1-3 bullets>

## Test plan
- [ ] <how the change was verified>
```

Drop it in `.github/pull_request_template.md`.

## Periodic audit checklist

- Last 20 commits: ≥80% conventional-commit shaped?
- Any merge-commit bubbles on main in the past month?
- Any commits whose message is "fix" / "update" / "wip" with no scope?
- Any PRs merged with `--force` or `--admin` override in the past month? (Should be zero.)
- Reviews: feedback labeled (suggestion, issue, question, nitpick) or just free-text? Labels make blocking-status explicit.

## Common anti-patterns

- **Squash-and-merge by default.** Loses the atomic-commit story. Only squash when the branch history is genuinely unsalvageable.
- **Amending published commits.** Hurts reviewers who track the PR diff. New atomic commits instead.
- **`--no-verify`.** Skips the hook. If you need it, your hook is wrong; fix the hook, don't bypass it.
- **`Co-Authored-By: AI Tool`.** Muddy ownership. The human who pushes owns it.

## Presence check pronto uses

Pronto's kernel presence check for this dimension scans the last 20 commits for the conventional-commit regex and passes if ≥80% match. Presence-cap is 50 until `commventional` or an equivalent live audit kicks in.

## Concrete first step

Run this now:

```bash
git log --pretty=format:"%s" -20 | \
  grep -cE '^(feat|fix|chore|docs|refactor|test|perf|build|ci|style)(\([a-z0-9-]+\))?!?: .+'
```

Target: ≥16 of 20. If you're below, tighten up the next ten commits — the presence check will catch up on the next audit run.
