#!/usr/bin/env bash
# inkwell-query-retrieve.test.sh — exercise bin/inkwell-query-retrieve.sh
# against the bin-docs fixture. The deterministic half of /inkwell:query
# is what this test pins; the synthesis paragraph that the skill body
# produces lives in the LLM and is intentionally untested here.
#
# Verifies the M3-locked / M5-populated response contract:
#   1. A grounded query against the fixture returns at least one
#      citation matching the locked `path#anchor` shape.
#   2. Every emitted citation resolves: the path is a real file under
#      docs/ and the anchor matches a real heading slug in that file.
#   3. The **Corroboration:** block is present and carries one bullet
#      per claim. With the subagent disabled (see SUBAGENT_OFF) only
#      Tier 1 + Tier 3 contribute, so the test pins:
#        - the block header literal `**Corroboration:**`
#        - at least one citation appears as a bullet
#        - every bullet ends with one of the three locked verdicts
#          (`verified` / `drift detected` / `could not corroborate`).
#      Tier 2 is intentionally pinned off — the subagent path is
#      non-deterministic by design (ADR-007).
#   4. Empty docs/ returns the no-match sentinel, exit 0, no crash.
#   5. No-match query returns the no-match sentinel, exit 0.
#   6. Triple-run determinism on the citation-resolution and
#      corroboration-block paths (with Tier 2 disabled).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
RETRIEVER="$PLUGIN_ROOT/bin/inkwell-query-retrieve.sh"
FIXTURE_BLUEPRINT="$HERE/fixtures/bin-docs/docs"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL [$label]: expected to contain '$needle'" >&2
    echo "  actual: $haystack" >&2
    fail=1
  fi
}

assert_match() {
  local label="$1" pattern="$2" haystack="$3"
  if ! printf '%s\n' "$haystack" | grep -Eq "$pattern"; then
    echo "FAIL [$label]: expected pattern '$pattern' to match" >&2
    echo "  actual: $haystack" >&2
    fail=1
  fi
}

triple_run_retrieve() {
  local query="$1" repo="$2"
  local r1 r2 r3
  # Pin Tier 2 off so the corroboration block is deterministic
  # across runs. Subagent dispatch is non-deterministic by design
  # (see ADR-007 — that's a documented negative consequence) and
  # the deterministic-tail invariant the test pins applies only to
  # the Tier 1 + Tier 3 paths.
  r1=$(INKWELL_CORROBORATE_SUBAGENT=/bin/false "$RETRIEVER" "$query" "$repo" 2>/dev/null)
  r2=$(INKWELL_CORROBORATE_SUBAGENT=/bin/false "$RETRIEVER" "$query" "$repo" 2>/dev/null)
  r3=$(INKWELL_CORROBORATE_SUBAGENT=/bin/false "$RETRIEVER" "$query" "$repo" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [triple-run: $query]: stdout diverged across runs" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

# slugify_for_test — same rule as the script, used to recompute the
# expected anchor when verifying that a citation resolves.
slugify_for_test() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

# verify_citation_resolves <repo> <path#anchor>
# Pass if <repo>/<path> exists AND the file contains a heading whose
# slug equals <anchor>.
verify_citation_resolves() {
  local repo="$1" citation="$2"
  local path="${citation%%#*}"
  local anchor="${citation#*#}"
  local abs="$repo/$path"
  if [[ ! -f "$abs" ]]; then
    echo "FAIL [citation file missing]: $abs" >&2
    fail=1
    return
  fi
  local found="no"
  while IFS= read -r heading; do
    [[ -z "$heading" ]] && continue
    local text="${heading#"${heading%%[!#]*}"}"
    text="${text# }"
    text="${text%% #*}"
    local slug
    slug="$(slugify_for_test "$text")"
    if [[ "$slug" == "$anchor" ]]; then
      found="yes"
      break
    fi
  done < <(grep -E '^#+[[:space:]]' "$abs" || true)
  if [[ "$found" != "yes" ]]; then
    echo "FAIL [anchor missing]: $citation — no heading slugifies to '$anchor' in $abs" >&2
    fail=1
  fi
}

# -------------------------------------------------------------------
# Setup — copy the bin-docs fixture into a tempdir.
# -------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/docs"
cp -R "$FIXTURE_BLUEPRINT/." "$TMP/docs/"

# -------------------------------------------------------------------
# Case 1 — grounded query produces at least one path#anchor citation
# in the locked Sources block shape, plus the Corroboration stub.
# Triple-run pinned for determinism.
# -------------------------------------------------------------------
out=$(triple_run_retrieve "validateSession" "$TMP")

# The Sources block must contain at least one citation line of the
# shape `- [docs/X.md#anchor](docs/X.md#anchor) — snippet`.
assert_match "sources line shape" \
  '^- \[docs/.+\.md#[a-z0-9-]+\]\(docs/.+\.md#[a-z0-9-]+\) — ' "$out"

# Corroboration block header is present (M5 contract).
assert_contains "corroboration header" "**Corroboration:**" "$out"

# Every Corroboration bullet must end with one of the three locked
# verdicts. The block is everything below the `**Corroboration:**`
# header through end of stdout.
corro_block="$(printf '%s\n' "$out" | awk '/^\*\*Corroboration:\*\*/{p=1; next} p')"
if [[ -z "$corro_block" ]]; then
  echo "FAIL [corroboration block empty]: no bullets after **Corroboration:**" >&2
  echo "  actual: $out" >&2
  fail=1
fi
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  case "$line" in
    "- "*" — verified"|"- "*" — could not corroborate"|"- "*" — drift detected"*)
      ;;
    *)
      echo "FAIL [corroboration bullet shape]: '$line' does not match the locked verdict shape" >&2
      fail=1
      ;;
  esac
done <<<"$corro_block"

# Sentinel separating chunks payload from the contract tail must be
# present — the skill body relies on it.
assert_contains "end-of-chunks sentinel" "---END-OF-CHUNKS---" "$out"

# Specific grounded check: the validateSession query must cite session.md.
assert_contains "grounded citation" "docs/auth/session.md#sessions" "$out"

# -------------------------------------------------------------------
# Case 2 — every citation in the Sources block resolves to a real
# file and a real heading anchor in that file. Pulled from a
# multi-hit query so we exercise more than one citation.
# -------------------------------------------------------------------
out_multi=$(triple_run_retrieve "auth*" "$TMP")
assert_contains "multi-hit corroboration header" "**Corroboration:**" "$out_multi"

citations=()
while IFS= read -r citation; do
  [[ -n "$citation" ]] && citations+=("$citation")
done < <(printf '%s\n' "$out_multi" \
  | grep -oE '\[docs/[^]]+\.md#[a-z0-9-]+\]' \
  | sed -e 's/^\[//' -e 's/\]$//' \
  | sort -u)

if (( ${#citations[@]} == 0 )); then
  echo "FAIL [multi-hit citations]: expected ≥1 citation in Sources block" >&2
  echo "  actual: $out_multi" >&2
  fail=1
fi

for c in "${citations[@]}"; do
  verify_citation_resolves "$TMP" "$c"
done

# -------------------------------------------------------------------
# Case 3 — empty docs/: no-match sentinel, exit 0, no crash.
# -------------------------------------------------------------------
EMPTY="$(mktemp -d)"
mkdir -p "$EMPTY/docs"
out_empty=$("$RETRIEVER" "anything" "$EMPTY" 2>/dev/null)
assert_eq "empty docs → no-match sentinel" \
  "*No matching documentation found.*" "$out_empty"
"$RETRIEVER" "anything" "$EMPTY" >/dev/null 2>&1
assert_eq "empty docs exit code" "0" "$?"
rm -rf "$EMPTY"

# -------------------------------------------------------------------
# Case 4 — no-match query against a populated tree: same sentinel,
# exit 0. The empty-docs and no-hits branches share the response.
# -------------------------------------------------------------------
out_none=$("$RETRIEVER" "zzz_no_such_token_xyzzy" "$TMP" 2>/dev/null)
assert_eq "no-match → no-match sentinel" \
  "*No matching documentation found.*" "$out_none"
"$RETRIEVER" "zzz_no_such_token_xyzzy" "$TMP" >/dev/null 2>&1
assert_eq "no-match exit code" "0" "$?"

# -------------------------------------------------------------------
# Case 4b — natural-language sentence-shaped question with punctuation
# must produce real citations. FTS5's MATCH parser would reject the
# raw question (the implicit-AND of every token, plus punctuation
# parsed as syntax, drops it to zero hits); the script normalises to
# an OR-joined token list before searching. This is the regression
# test for the layer-2 smoke blocker.
# -------------------------------------------------------------------
out_nl=$(triple_run_retrieve \
  "What does validate_session do, and what's the default token prefix?" \
  "$TMP")
assert_match "natural-language citation shape" \
  '^- \[docs/.+\.md#[a-z0-9-]+\]\(docs/.+\.md#[a-z0-9-]+\) — ' "$out_nl"
assert_contains "natural-language corroboration header" \
  "**Corroboration:**" "$out_nl"

# -------------------------------------------------------------------
# Case 5 — frontmatter-only match: when the FTS5 hit's line falls
# in the YAML frontmatter (before any heading), the resolver must
# fall back to the doc's first heading rather than dropping the
# hit. Pinned via the SENTINEL token, which lives in the body of
# concepts/auth.md whose H1 is "# Authentication".
# -------------------------------------------------------------------
out_sentinel=$(triple_run_retrieve "SENTINEL_AUTH_FIXTURE_TOKEN" "$TMP")
assert_contains "sentinel citation" \
  "docs/concepts/auth.md#authentication" "$out_sentinel"

if (( fail == 0 )); then
  echo "inkwell-query-retrieve.test.sh: PASS"
  exit 0
else
  echo "inkwell-query-retrieve.test.sh: FAIL" >&2
  exit 1
fi
