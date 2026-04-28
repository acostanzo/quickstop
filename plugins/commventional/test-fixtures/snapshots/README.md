# Commventional pre-migration snapshots

These fixtures and snapshots capture `score-commventional.sh` behaviour on three
representative input shapes immediately before the M3 (observations[] emission)
migration. They are the regression target: post-migration, the `envelope.json`
for each fixture must diff to **zero against the existing fields** (`plugin`,
`dimension`, `categories`, `composite_score`, `letter_grade`,
`recommendations`). The migration is allowed to *add* an `observations[]`
array; everything else is locked.

## Provenance

Captured on the `survey/m3-commventional-observations` branch on 2026-04-28
by running:

```
bash plugins/pronto/agents/parsers/scorers/score-commventional.sh <FIXTURE_DIR>
```

with the scorer at the H4-shipped tip on `main`.

## Fixtures

| Slug | Description | Input source |
|---|---|---|
| `clean` | Synthetic 10-commit repo: every subject is a conventional-commit, no auto-trailers, no `Generated with Claude Code` markers. Ratio=1.0, trailers=0, markers=0. | `inputs/build-clean.sh` |
| `mid` | quickstop at the H2d-closeout SHA (`7650b49…`) — known mid-grade baseline used by `plugins/pronto/tests/fixtures.json`. Ratio=1.0, trailers=17, markers=0. | `git worktree add` of pinned SHA |
| `noisy` | Synthetic 15-commit repo: 4 conventional / 11 not (ratio ~0.286), 7 commits with auto Co-Authored-By trailers, 3 commits with `Generated with Claude Code` markers. | `inputs/build-noisy.sh` |

The clean and noisy fixtures are reproducible from the build scripts under
`inputs/`. They commit no `.git` directories — each test run materialises
the fixture into a tempdir, scores it, and discards it. The mid fixture is
the same pinned SHA pattern claudit / skillet use.

## Snapshot layout

```
snapshots/<fixture>/
  envelope.json     stdout — sibling-audit wire-contract JSON
  standalone.txt    stderr — score-commventional.sh emits no human narrative;
                    this file is empty per fixture
  exit_code.txt     exit status (0 on success)
inputs/
  build-clean.sh    materialise the clean fixture into a target dir
  build-noisy.sh    materialise the noisy fixture into a target dir
```

## Composite scores

| Fixture | commventional composite (v1) |
|---|---|
| `clean` | 100 |
| `mid` | 82 |
| `noisy` | 43 |

After M3 ships, re-running the same command against the same inputs must
produce envelopes whose **existing fields** diff to zero against these
files. The new `observations[]` field will be added; that is the only
permitted delta.

## What this does NOT cover

- The commventional plugin ships agents (`commit-crafter`, `review-formatter`)
  and a `PreToolUse` ownership-enforcement hook. None of those are on the
  pronto wire path — only `score-commventional.sh` is. M3 does not modify
  the agents or the hook; their behaviour is preserved automatically.

- Pronto-side composite scoring on the harness is enforced separately in
  the eval harness on `mid` (composite=61, all-dim stddev=0). M3 must
  preserve that, which is automatic if the v1 fields stay byte-identical
  AND the rubric calibration reproduces today commventional dimension
  score via observations.
