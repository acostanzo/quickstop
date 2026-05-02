# Vendored-Broken Fixture

This README and the docs/ tree contain three deliberately-broken on-disk
links plus one deliberately-broken anchor reference. Used by
`link-health.test.sh` to verify the lychee-dispatch branch when lychee
is on PATH and to verify the tool-absent branch when it isn't.

## Targets

- [Working link to existing doc](docs/overview.md)
- [Broken link 1: missing file](docs/missing-one.md)
- [Broken link 2: bad path](does-not-exist.md)

See [the section that exists](#section-with-anchor) for the working
in-document anchor; see [a section that doesn't](#nonexistent-anchor)
for the broken anchor reference.

## Section with anchor

Anchor target. The link above points here.
