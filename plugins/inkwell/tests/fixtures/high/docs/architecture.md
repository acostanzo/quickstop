# Architecture

`sample-project` is a single-module library. The implementation
fits in one `mean.py` file plus an `aggregator.py` companion.

## Constraints

- Pure Python, no third-party dependencies at runtime.
- Stable contract per [api](api.md) — no breaking changes in
  v1.x.

See [overview](overview.md) for the user-facing summary.
