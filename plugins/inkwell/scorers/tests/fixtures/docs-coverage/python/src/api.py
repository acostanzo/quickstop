"""Module-level docstring is itself one of interrogate's coverage targets."""


def documented_one() -> int:
    """Return one."""
    return 1


def documented_two() -> int:
    """Return two."""
    return 2


def documented_three() -> int:
    """Return three."""
    return 3


def undocumented_four() -> int:
    return 4


def undocumented_five() -> int:
    return 5
