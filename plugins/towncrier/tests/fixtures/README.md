# Towncrier event-emission calibration fixtures

Three single-language python fixtures (`python-low`, `python-mid`, `python-high`) drive towncrier's event-emission rubric calibration. Each fixture is a static blueprint — no git history, no shell-driven materialisation — because none of the four scorers (structured-logging-ratio, metrics-presence, trace-propagation, event-schema-consistency) consume temporal signals.

Each fixture ships with a locked `envelope.json` captured by running `bin/build-envelope.sh` against the fixture directory and committing the output verbatim. The `snapshots.test.sh` driver runs the orchestrator three times per fixture and asserts byte-equivalence with the locked envelope plus the translator-derived dimension score from `plugins/pronto/agents/parsers/scorers/observations-to-score.sh event-emission`.

## Calibration table (from `phase-2-2c3-towncrier-contract-fixtures.md`)

| Fixture     | Struct ratio | Metrics count | Trace ratio | Schema ratio | Bands hit         | Composite | Letter |
|---          |---           |---            |---          |---           |---                |---        |---     |
| python-low  | 0.20 (bait)  | 0 (cfg=1)     | 0.00        | 0.00         | 30, 50, 30, 30    | **35**    | F      |
| python-mid  | 0.83         | 5             | 0.67        | 0.80         | 85, 85, 70, 85    | **81**    | B      |
| python-high | 1.00         | 12            | 1.00        | 1.00         | 100, 100, 100, 100| **100**   | A+     |

`python-low` is the **bait-and-switch** case the plan-doc requires: the fixture's `pyproject.toml` and `src/log_helpers.py` import `structlog`, `prometheus_client`, and `opentelemetry`, so pronto's kernel presence check (grep for `structlog` / `opentelemetry` / `metric` / etc.) matches and would assign 50 capped. The structured-logging ratio scorer surfaces the actual emission shape — 2 structlog calls vs 8 free-form `print()` — and the rubric stanza lands the dimension at 35 (F). Surface-level presence does not silently inflate the composite when the actual emission shape is poor.

Fixture profiles (single language, three depth levels) mirror inkwell's 2a3 layout rather than lintguini's 2b3 nine-fixture (three-language × three-profile) layout. The plan-doc's required acceptance ("at least one bait case in the fixture set") is satisfied by python-low alone; multi-language extension is filed as follow-up if calibration shows python is insufficient (see the 2c3 ticket's "Out of scope" section).

## Running

```bash
./snapshots.test.sh
```

Triple-runs `bin/build-envelope.sh` against each fixture, asserts byte-equivalence with the locked envelope, observation-ID set, schema_version, composite_score=null, and translator-derived composite (35 / 81 / 100 within ±1).
