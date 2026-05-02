# Tutorial

## Compute a mean

```python
from sample_project import mean
mean([1, 2, 3])
```

## Stream values through the Aggregator

```python
from sample_project import Aggregator
agg = Aggregator()
for value in stream:
    agg.add(value)
print(agg.mean())
```

See [api](api.md) for the full reference.
