# Claudit pre-migration snapshots

These fixtures and snapshots capture `score-claudit.sh` behaviour on three
representative input shapes immediately before the M1 (observations[] emission)
migration. They exist as the regression target: post-migration, the
`envelope.json` for each fixture must diff to **zero against the existing
fields** (`plugin`, `dimension`, `categories`, `composite_score`,
`letter_grade`, `recommendations`). The migration is allowed to *add* an
`observations[]` array; everything else is locked.

## Provenance

Captured on the `survey/m1-claudit-observations` branch on 2026-04-27 by
running:

```
bash plugins/pronto/agents/parsers/scorers/score-claudit.sh <FIXTURE_DIR>
```

at the top of the H4 branch (`feat/h4-observations-aware-scorer`).

## Fixtures

| Slug | Description | Source |
|---|---|---|
| `mid` | quickstop at the H2d-closeout SHA — known mid-grade baseline used by `plugins/pronto/tests/fixtures.json` | `7650b49ec9828494f066ec56682a8b653791bfcc` worktree of this repo |
| `clean` | Synthetic minimal Claude-config repo: 10-line CLAUDE.md with arrival sections, narrow allow list, explicit `defaultMode`, two MCP servers | `inputs/clean/` (committed alongside the snapshot) |
| `noisy` | Synthetic noisy repo: 227-line CLAUDE.md with restated-builtin prose, broad `Bash(*)`/`Write(*)` allows, no `defaultMode`, 7 MCP servers | `inputs/noisy/` (committed alongside the snapshot) |

The mid fixture is reproducible from the pinned SHA via `git worktree add`.
The clean and noisy fixtures are committed as-is under `inputs/<slug>/`.

## Snapshot layout

```
snapshots/<fixture>/
  envelope.json     stdout — sibling-audit wire-contract JSON
  standalone.txt    stderr — empty for score-claudit (no human narrative;
                    the human narrative comes from the LLM-driven `/claudit`
                    skill which is out of scope for these snapshots)
  exit_code.txt     exit status (0 on success)
```

## Composite scores

| Fixture | claudit composite (v1) |
|---|---|
| `clean` | 100 |
| `mid` | 96 |
| `noisy` | 76 |

After M1 ships, re-running the same command against the same inputs must
produce envelopes whose **existing fields** diff to zero against these
files. The new `observations[]` field will be added; that's the only
permitted delta.

## What this does NOT cover

- The LLM-driven `/claudit` slash command is out of scope. That command
  drives subagents and prints a banner-style health report; its output
  is not byte-stable and is not part of the wire contract. Standalone
  byte-identity for `/claudit` means "no behavioural change to the
  command's prose / recommendations / exit codes", which is enforced by
  M1 not touching `plugins/claudit/skills/claudit/SKILL.md`.

- Pronto-side composite scoring on the harness is enforced separately in
  the eval harness on `mid` (composite=61, all-dim stddev=0). M1 must
  preserve that, which is automatic if the v1 fields stay byte-identical
  AND the rubric calibration reproduces today's claudit dimension score
  via observations.
