# API Reference

The full public API of `sample-project`. See
[overview](overview.md) for orientation.

## `mean(values)`

Compute the arithmetic mean of a sequence of numbers.

**Parameters:**

- `values` (Iterable[float | int]) — the input sequence.

**Returns:**

- `float` — the arithmetic mean.

**Raises:**

- `ValueError` — when `values` is empty.

## `Aggregator` (class)

A reusable accumulator for streaming inputs. See
[tutorial](tutorial.md) for an example.
