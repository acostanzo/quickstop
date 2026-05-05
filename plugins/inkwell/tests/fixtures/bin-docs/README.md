# bin-docs fixture

Static blueprint of a `docs/` tree used by the bash-script tests in
`plugins/inkwell/tests/`:

- `concepts/auth.md` — tags `[auth, security]`. Carries
  `SENTINEL_AUTH_FIXTURE_TOKEN` as a unique search-test marker.
- `concepts/tagless.md` — no `tags:` field. Suggest-links must return
  "no automatic suggestion".
- `auth/session.md` — tags `[auth, security, jwt]`. Maximum overlap
  with `concepts/auth.md`; the suggester's top hit for either of
  those targets is the other.
- `howtos/rate-limit.md` — tags `[api, security]`. Single-tag overlap
  with both auth docs.
- `howtos/orphan.md` — tags `[random, unrelated]`. No overlap with
  any other fixture doc; verifies negative-case filtering.

The blueprint is copied into a `$TMPDIR/docs/` at test time. The
indexer's `.inkwell.fts5.db` lands in that copy and is discarded
when the test finishes — fixtures never carry the index file.
