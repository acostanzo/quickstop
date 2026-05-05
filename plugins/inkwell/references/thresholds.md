# Inkwell thresholds

Single source of truth for the numeric knobs that the inkwell scorers and
the `/inkwell:tidy` skill read. Co-locating them in one file keeps the
scorer and the tidy surface from drifting apart.

The canonical values live in `thresholds.json` next to this file. Bash
helpers read it via `jq`; if `jq` is unavailable they fall back to the
defaults documented inline in each consumer.

## Fields

| Field | Default | Consumers |
|---|---|---|
| `staleness_days` | `90` | `score-doc-staleness.sh`, `inkwell-tidy.sh` |
| `tidy.duplicate_overlap_min` | `0.85` | `inkwell-tidy.sh` — minimum shingle Jaccard to flag a duplicate pair (read-only) |
| `tidy.duplicate_overlap_archive` | `0.95` | `inkwell-tidy.sh` — overlap at or above which `--apply` archives the older of the pair |
| `tidy.rename_lookback_commits` | `30` | `inkwell-tidy.sh` — `git log --diff-filter=R` window for inbound link rewriting |

## Why a JSON file rather than env vars or a shared shell file

- JSON is consumable by the bash scripts (`jq -r '.staleness_days'`) and by future tooling without a parser ad-hoc.
- A single-file source keeps the threshold legible and reviewable in PRs — no chasing constants across scripts.
- `references/` is the conventional plugin location for read-only data, parallel to `templates/`.

## Adding a new threshold

1. Add the field to `thresholds.json`.
2. Add a row to the table above naming the consumers.
3. Read it from the consumer with `jq -r` and a default-on-missing fallback so the script still runs in environments without `jq`.
