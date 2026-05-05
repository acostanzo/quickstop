---
name: tidy
description: Surface (and optionally fix) doc-tree drift — duplicates, dead links, stale docs, template non-compliance, missing `## Related` blocks. Read-only by default; `--apply` does mechanical fixes; `--apply-semantic` emits diffs for human review.
allowed-tools: Bash
argument-hint: [--apply | --apply-semantic]
---

# Inkwell:tidy

Thin wrapper over `bin/inkwell-tidy.sh`. Run the bash script with the
user's mode flag (if any) and pass stdout through unchanged.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/inkwell-tidy.sh" [--apply | --apply-semantic] "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically
the working directory when `/inkwell:tidy` was invoked. The mode flag
is omitted entirely on the default invocation.

## Modes

| Mode | What it does | Writes? |
|---|---|---|
| (default) | Read-only finding pass | No |
| `--apply` | Mechanical fixes | Yes (working tree) |
| `--apply-semantic` | Emit unified diffs for semantic rewrites | No |

The `--apply` / `--apply-semantic` split is the load-bearing contract.
Mechanical changes (link rewrites, frontmatter `updated:` stamps,
archive moves, near-identical dedup) are silent because they have a
single correct answer. Semantic operations (dedup choice in the
ambiguous overlap band, section reorganisation) always come with a
diff so they are reviewed, not trusted.

## Output shape

### Default (read-only)

One finding per stdout line, sorted by path then rule for determinism:

```
docs/auth/session.md  rule=stale  details: git mtime drift 142d > threshold 90d
docs/concepts/auth.md  rule=missing-related  details: terminal `## Related` heading absent
docs/howtos/orphan.md  rule=duplicate  details: 0.91 shingle overlap with docs/howtos/rate-limit.md
```

Clean tree → exit 0 with empty stdout. No findings, no spam.

Each finding cites the rule by name so authors can reason about which
fired:

| Rule | Detection |
|---|---|
| `duplicate` | Title + body bigram-Jaccard overlap ≥ `duplicate_overlap_min` (pairs only, no transitive merging). |
| `dead-link` | Internal link target does not resolve, relative to the source file's directory (or repo root for leading `/`). HTTP/mailto/anchor-only links are skipped. |
| `stale` | Git mtime drift > `staleness_days` (`git log -1 --format=%ct -- <file>`). |
| `template-non-compliance` | Frontmatter missing or `template:` value not in {`concept`, `how-to`, `reference`, `tutorial`}, or required fields (`title`, `updated`) absent. |
| `missing-related` | File doesn't terminate with a `## Related` block, or the block has no content (the bare `-` placeholder doesn't count). |

### `--apply` (mechanical fixes)

One line per applied fix on stdout:

```
applied  rule=link-rewrite  docs/auth/session.md  → target docs/concepts/auth-v2.md
applied  rule=updated-stamp  docs/auth/session.md  bumped updated: 2026-04-12 → 2026-05-04
applied  rule=archive-stale  docs/legacy/old.md → docs/archive/legacy/old.md
applied  rule=dedup-archive  docs/howtos/orphan.md → docs/archive/howtos/orphan.md (kept docs/howtos/rate-limit.md, overlap 0.9600)
```

Mechanical-only — never rewrites body prose, never collapses different
sections, never edits anything outside frontmatter / link targets /
file location. The mechanical/semantic split is the contract; trust
this path.

### `--apply-semantic` (diff-only, no writes)

Unified diffs to stdout, one per ambiguous-overlap pair. Working tree
is **not** touched. Pipe into `git apply` if the proposal is right:

```bash
/inkwell:tidy --apply-semantic > tidy.patch
git apply tidy.patch   # only if you reviewed and agreed
```

v1 emits dedup-choice diffs for pairs in the
`duplicate_overlap_min..duplicate_overlap_archive` band — the proposed
canonical is the more recent doc; the diff proposes deleting the
older. Section-reorganisation signals are deferred until they have a
clean detector that doesn't ship spurious diffs.

## Thresholds

The numeric knobs (`staleness_days`, `duplicate_overlap_min`,
`duplicate_overlap_archive`, `rename_lookback_commits`) live in
`references/thresholds.json` so the audit's staleness scorer and tidy
share one source of truth. Edit that file, not this skill, to retune.

## Empty-scope contract

If `<REPO_ROOT>/docs/` is missing, the script exits 0 with empty
stdout — tidy must never crash a writer's flow on a fresh repo.

## What this skill does not do

- Does not author or rewrite prose. Mechanical = no prose. Semantic
  rewrites only emit diffs, never write.
- Does not corroborate code claims. That's `/inkwell:query` (T3) at
  inference time per ADR-007.
- Does not dispatch a subagent. Tidy is deterministic shell + grep +
  awk + jq, like the rest of the audit-adjacent surface. Subagent
  corroboration is T5's scope.
- Does not modify files outside `docs/` (link rewrites, archive moves,
  `updated:` stamps). ADR-006 §2 holds: no silent mutation of consumer
  artefacts beyond the documented scope.
