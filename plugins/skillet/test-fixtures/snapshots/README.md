# Skillet pre-migration snapshots

These fixtures and snapshots capture `score-skillet.sh` behaviour on three
representative input shapes immediately before the M2 (observations[] emission)
migration. They exist as the regression target: post-migration, the
`envelope.json` for each fixture must diff to **zero against the existing
fields** (`plugin`, `dimension`, `categories`, `composite_score`,
`letter_grade`, `recommendations`). The migration is allowed to *add* an
`observations[]` array and a top-level `$schema_version`; everything else
is locked.

## Provenance

Captured on the `survey/m2-skillet-observations` branch on 2026-04-27 by
running:

```
bash plugins/pronto/agents/parsers/scorers/score-skillet.sh <FIXTURE_DIR>
```

against the H4-closeout `main` commit (post-PR-61 / M1 merged baseline).

## Fixtures

| Slug | Description | Source |
|---|---|---|
| `mid` | quickstop at the H2d-closeout SHA — the pinned harness baseline used by `plugins/pronto/tests/fixtures.json`; 22 SKILL.md files across `.claude/skills/` and several plugins | `7650b49ec9828494f066ec56682a8b653791bfcc` worktree of this repo |
| `clean` | Synthetic minimal: one well-formed SKILL.md with all four required frontmatter fields, structured Phase headings, no TODOs, no broken refs, no stray files | `inputs/clean/` (committed alongside the snapshot) |
| `noisy` | Synthetic noisy: three SKILL.md files mixing missing frontmatter, skeletal bodies, TODO markers, broken `references/` pointers, restated built-in tool prose, and stray `.DS_Store` / `.bak` files | `inputs/noisy/` (committed alongside the snapshot) |

The mid fixture is reproducible from the pinned SHA via `git worktree add`.
The clean and noisy fixtures are committed as-is under `inputs/<slug>/`.

## Snapshot layout

```
snapshots/<fixture>/
  envelope.json     stdout — sibling-audit wire-contract JSON
  standalone.txt    stderr — empty for score-skillet (no human narrative;
                    the human narrative comes from the LLM-driven
                    `/skillet:audit` skill which is out of scope for
                    these snapshots)
  exit_code.txt     exit status (0 on success)
```

## Composite scores

| Fixture | skillet composite (v1) |
|---|---|
| `clean` | 100 |
| `mid` | 97 |
| `noisy` | 76 |

After M2 ships, re-running the same command against the same inputs must
produce envelopes whose **existing fields** diff to zero against these
files. The new `observations[]` array and `"$schema_version": 2` field
will be added; that's the only permitted delta.

## What this does NOT cover

- The LLM-driven `/skillet:audit`, `/skillet:build`, and `/skillet:improve`
  slash commands are out of scope. Those commands drive subagents and
  print orchestrator-style reports; their output is not byte-stable and
  is not part of the wire contract. Standalone byte-identity for them
  means "no behavioural change to the commands' prose / recommendations
  / exit codes", which is enforced by M2 not touching
  `plugins/skillet/skills/**`.

- Pronto-side composite scoring on the harness is enforced separately in
  the eval harness on `mid` (composite=61, `skills-quality` mean=97
  stddev=0). M2 must preserve that, which requires both v1-field
  byte-identity AND the rubric stanza recalibration described in the
  M2 design doc to converge the rubric path on score-skillet's path.
