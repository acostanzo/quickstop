# Inkwell calibration fixtures

The three-fixture set (`low`, `mid`, `high`) calibrates the
`code-documentation` translation rules in
`plugins/pronto/references/rubric.md`. Each fixture is a static
blueprint plus a locked v2 envelope captured by running
`bin/build-envelope.sh` against the materialised fixture.

## Why a build script

The staleness scorer
(`plugins/inkwell/scorers/score-doc-staleness.sh`) reads
`git log --format=%ct` for source and docs files; the
filesystem mtime is *not* used. So each fixture has to be a
real git repository with controlled commit timestamps to
produce a deterministic `stale_files` count.

Nesting a `.git/` tree inside the parent quickstop repo would
either tangle the parent's index (forcing submodule semantics)
or pollute `git status` output. Instead, the fixture files live
under `<slug>/` as a static blueprint, and `build-fixture.sh`
materialises them into a temp dir at test time, synthesising
git history with timestamps hard-coded per slug. The
calibration table below pins the resulting observation values.

## Fixtures

| Fixture | README arrival | Docs coverage | Stale src | Broken links | Composite | Letter |
|---|---|---|---|---|---|---|
| `low`  | 1/5 = 0.2000  | 0/60 = 0.0000  | 18 / 30 | 4 | **45** | F  |
| `mid`  | 4/5 = 0.8000  | 36/50 = 0.7200 |  6 / 25 | 1 | **81** | B  |
| `high` | 5/5 = 1.0000  | 38/40 = 0.9500 |  0 / 20 | 0 | **100** | A+ |

Per-observation band hits under the rubric stanza:

| Fixture | readme-arrival | docs-coverage | docs-staleness | broken-links |
|---|---|---|---|---|
| `low`  | else → 30           | else → 30       | gte 10 → 60      | gte 2 → 60      |
| `mid`  | gte 0.80 → 85       | gte 0.60 → 70   | gte 3 → 85       | gte 1 → 85      |
| `high` | gte 1.00 → 100      | gte 0.95 → 100  | else → 100       | else → 100      |

Equal-share mean across the four observations:

- low:  (30 + 30 + 60 + 60)/4 = 45
- mid:  (85 + 70 + 85 + 85)/4 = 81.25 → 81
- high: (100 + 100 + 100 + 100)/4 = 100

## Layout

```
plugins/inkwell/tests/fixtures/
├── README.md           (this file)
├── build-fixture.sh    (materialises a fixture into a temp dir with git history)
├── snapshots.test.sh   (invariant B regression — triple-run + locked envelope diff)
├── low/
│   ├── README.md       (12 lines, 1/5 arrival questions answered)
│   ├── docs/           (1 file)
│   ├── src/            (30 .py files, 0 documented)
│   └── envelope.json   (locked v2 envelope, predicted composite=45)
├── mid/
│   ├── README.md       (60 lines, 4/5 arrival)
│   ├── docs/           (5 files)
│   ├── src/            (25 .py files, 11 with function docstrings + 25 module docstrings)
│   └── envelope.json   (locked, predicted composite=81)
└── high/
    ├── README.md       (40 lines, 5/5 arrival)
    ├── docs/           (8 files)
    ├── src/            (20 .py files, 18 with function docstrings + 20 module docstrings)
    └── envelope.json   (locked, predicted composite=100)
```

## Build a fixture by hand

```bash
TMP=$(mktemp -d -t inkwell-fix.XXXXXX)
bash plugins/inkwell/tests/fixtures/build-fixture.sh mid "$TMP"
bash plugins/inkwell/bin/build-envelope.sh "$TMP"
```

The output should byte-for-byte match `plugins/inkwell/tests/fixtures/mid/envelope.json`.

## Tool dependencies

The fixtures only exercise the python branch of
`score-docs-coverage.sh`. They require:

- `git` — for the staleness scorer's commit-time pin.
- `interrogate` — for the docs-coverage scorer's python
  dispatch. Install via `pipx install interrogate` (1.7.0+).
- `lychee` — for the link-health scorer's offline link check.
  Install via `cargo install lychee` or grab a binary release.
- `jq` — used everywhere.

If `interrogate` or `lychee` is missing the affected
observation is omitted from the envelope, which would break
the locked-envelope byte-equivalence assertion. The snapshots
test errors out early on missing tooling rather than emitting
a misleading pass.
