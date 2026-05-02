# Sample Project (Mid Fixture)

A small Python utility for numeric aggregation. The implementation
fits in a single module with one helper class.

This fixture intentionally answers four of the five README arrival
questions: project intent, audience, install, and where-to-go-next
are answered; the project status section is left out, so the
fifth question is unanswered.

## Overview

The library exposes a `mean` function and an `Aggregator` class.
The `mean` function takes a sequence of numbers and returns their
arithmetic mean. `Aggregator` is a streaming companion for cases
where the inputs arrive incrementally and you don't want to hold
the full sequence in memory.

The README's depth signals are intentionally medium: a real
installation section, a useful audience section, and a docs
pointer, but no status badge or status header. This is the kind
of README that lands in the C/B band on inkwell's rubric.

## Audience

This project is for Python developers building data-processing
utilities who want a tiny, well-tested aggregation library
without a heavy dependency footprint.

It's also for documentation-tooling tests — this fixture sits in
the middle of inkwell's calibration set.

## Install

```bash
pip install sample-project
```

Requires Python 3.10 or newer. No third-party dependencies at
runtime.

```bash
# Optional: install the dev extras for running the tests.
pip install sample-project[dev]
```

## Documentation

The full reference lives in [docs/overview](docs/overview.md);
the [tutorial](docs/tutorial.md) and the [api reference](docs/api.md)
are also available. A migration guide for v1 → v2 is at
[docs/migration](docs/migration.md), along with the
[non-existent CHANGELOG](docs/CHANGELOG.md) (intentional one
broken link to calibrate the fixture).

## License

MIT.
