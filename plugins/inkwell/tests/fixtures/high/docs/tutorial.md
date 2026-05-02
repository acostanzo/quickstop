# Tutorial

This page walks through computing a mean step by step. See
[overview](overview.md) for the high-level orientation and
[api](api.md) for the formal reference.

## Basic usage

```python
from sample_project import mean
result = mean([1, 2, 3, 4, 5])
print(result)  # 3.0
```

## Working with floats

`mean` accepts any iterable of numeric values. It returns a
`float`. For an empty input, it raises `ValueError`.

```python
mean([1.5, 2.5, 3.5])  # 2.5
```

## Next steps

Read the [api reference](api.md) for the formal contract and
[changelog](changelog.md) for the version history.
