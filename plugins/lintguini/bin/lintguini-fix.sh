#!/usr/bin/env bash
# lintguini-fix.sh — wrap each language's auto-fix mode behind a uniform
# read-only / --apply / --apply-semantic surface, mirroring the
# mechanical-vs-semantic split established by /inkwell:tidy.
#
# Three modes:
#
#   default (findings)  Run the linter's safe-fix mode in PREVIEW form;
#                       surface a unified diff of what would change.
#                       Working tree untouched. Exit 1 if any diff
#                       emitted (CI-friendly: "this branch has unfixed
#                       issues"). Exit 0 if nothing to fix.
#
#   --apply             Run the linter's safe-fix mode for real; mutate
#                       files in place. Emit one `fixed <path>` line per
#                       touched file on stdout. Exit 0 on success.
#
#   --apply-semantic    Run the linter's UNSAFE-fix mode in PREVIEW form
#                       — surface the diff but never write. The user
#                       reviews the diff and applies it themselves
#                       (e.g. `lintguini fix --apply-semantic | git apply`).
#                       Exit 1 if any diff emitted. Exit 0 if nothing.
#
# `--apply` and `--apply-semantic` are mutually exclusive (exit 2).
#
# Determinism contract: this is the deterministic half of /lintguini:fix.
# The skill body (skills/fix/SKILL.md) is the LLM-shaped half. Same
# REPO_ROOT state + same flags + same tool versions on PATH ->
# byte-equivalent stdout across runs of the read-only and
# --apply-semantic paths. (--apply mutates state, so its second run is
# obviously not byte-equivalent to its first; the test plan triple-runs
# only the read-only and --apply-semantic paths.)
#
# ADR-006 §2: lint, format, and fix are all capability surfaces invoked
# by the consumer, never hooks. Read-only and --apply-semantic write
# nothing; --apply mutates the working tree but only because the
# consumer asked. The mutation is bounded to source files the linter
# recognises.
#
# ADR-008: the rubric pins canonical tool per language. Fix dispatches
# exactly that tool — no fallback to a "second-best" auto-fixer —
# because falling back would mean fixing a repo against a different
# rubric than the one /lintguini:configure wrote it for.
#
# Per-language tool dispatch:
#
#   Language    Read-only preview                                     Apply                                         Semantic preview
#   --------    ---------------------------------------------------    ------------------------------------------    ---------------------------------------------
#   python      ruff check --fix --diff .                              ruff check --fix .                            ruff check --fix --unsafe-fixes --diff .
#   javascript  copy-and-diff [biome check --write .]                  biome check --write .                         copy-and-diff [biome check --write --unsafe .]
#   typescript  same as javascript                                     same as javascript                            same as javascript
#   rust        copy-and-diff [cargo clippy --fix --allow-dirty]       cargo clippy --fix --allow-dirty              empty-scope (no safe/unsafe split)
#   ruby (rb)   copy-and-diff [rubocop -a .]                           rubocop -a .                                  copy-and-diff [rubocop -A .]
#   ruby (sr)   copy-and-diff [standardrb --fix .]                     standardrb --fix .                            empty-scope (standardrb has no safe/unsafe split)
#   go          gofmt -d .                                             gofmt -w .                                    empty-scope (gofmt is formatter-only;
#                                                                                                                    golangci-lint --fix dry-run support is patchy)
#
# Copy-and-diff fallback. Tools without a native preview / unsafe-diff
# mode (biome 2.x, rubocop's autocorrect-all, standardrb across
# versions) get the same preview shape via the copy_and_diff helper:
#
#   1. Snapshot REPO_ROOT into a tempdir, skipping bulk dirs (.git,
#      node_modules, vendor, target, dist, build).
#   2. Run the fix command against the copy.
#   3. `diff -u --label "a/<path>" --label "b/<path>"` each file in the
#      original against the copy.
#   4. Discard the tempdir.
#
# The fallback's contract is identical to native diff modes — unified
# diff on stdout, working tree untouched. A future contributor adding a
# new language reaches for copy_and_diff when (a) the tool can't preview
# without writing or (b) the tool's preview mode is too version-fragile
# to depend on.
#
# Output shape:
#
#   findings / --apply-semantic — unified diff to stdout, multi-file:
#       --- a/<path>
#       +++ b/<path>
#       @@ ...
#
#       The a//b/ prefix is normalised so consumers can pipe straight
#       into `git apply` regardless of which underlying tool emitted
#       the diff. Tools that already emit a/ b/ (the copy_and_diff
#       helper) are left alone; tools that emit bare paths (ruff) get
#       the prefix added.
#
#   --apply — one line per touched file:
#       fixed <path>
#
#   Polyglot output:
#       # python — N file[s] with fixes available
#       <python diffs>
#       # javascript — N file[s] with semantic fixes available
#       <js diffs>
#
#   Section headers begin with `# ` (which doubles as a unified-diff
#   no-op when piped into git apply). Single-language runs (one
#   configured language or --language scoped) emit no header.
#
# Empty-scope and tool-missing diagnostics go to stderr, never stdout:
#
#   <language>: not configured (run /lintguini:configure --language <lang>)
#   <language>: <tool> not on PATH (install <tool>)
#   <language>: --apply-semantic empty-scope (<tool> has no safe/unsafe split)
#
# Usage:
#   lintguini-fix.sh [--language <lang>] [--apply | --apply-semantic] <REPO_ROOT>
#
# Flags:
#   --language <lang>   Scope to a single language (one of:
#                       python, javascript, typescript, rust, ruby, go).
#                       Without it, fix every detected + configured
#                       language.
#   --apply             Apply safe fixes in place. Mutually exclusive
#                       with --apply-semantic.
#   --apply-semantic    Preview unsafe fixes as a diff. Mutually
#                       exclusive with --apply.
#   -h | --help         Show this help.
#
# Exit codes:
#   0  read-only / --apply-semantic emitted nothing; or --apply succeeded
#   1  read-only / --apply-semantic emitted at least one diff
#   2  argument errors (mutually-exclusive flags, unknown language,
#      missing REPO_ROOT, unsupported --language value)
#   3  required tooling missing on PATH for an in-scope language
#   4  fix execution failure (apply tool crashed unexpectedly, or
#      the copy-and-diff snapshot failed)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
DETECT_BIN="$PLUGIN_ROOT/bin/lintguini-detect-language.sh"

PROVENANCE_MARK='Generated by lintguini'

usage() {
  sed -n '/^# Usage:/,/^# Exit codes:/p' "$0" | sed 's/^# \{0,1\}//' >&2
}

die() {
  local msg="$1" rc="${2:-2}"
  echo "lintguini-fix: $msg" >&2
  exit "$rc"
}

# -- argument parsing ----------------------------------------------------

LANGUAGE=""
APPLY_FLAG=0
SEMANTIC_FLAG=0
REPO_ROOT_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --language)
      [[ $# -ge 2 ]] || die "--language requires a value"
      LANGUAGE="$2"; shift 2 ;;
    --language=*)
      LANGUAGE="${1#--language=}"; shift ;;
    --apply)
      APPLY_FLAG=1; shift ;;
    --apply-semantic)
      SEMANTIC_FLAG=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        [[ -n "$REPO_ROOT_ARG" ]] && die "unexpected positional '$1'"
        REPO_ROOT_ARG="$1"; shift
      done ;;
    --*)
      die "unknown flag '$1'" ;;
    *)
      [[ -n "$REPO_ROOT_ARG" ]] && die "unexpected positional '$1'"
      REPO_ROOT_ARG="$1"; shift ;;
  esac
done

if (( APPLY_FLAG == 1 && SEMANTIC_FLAG == 1 )); then
  die "--apply and --apply-semantic are mutually exclusive"
fi

if (( APPLY_FLAG == 1 )); then
  MODE="apply"
elif (( SEMANTIC_FLAG == 1 )); then
  MODE="semantic"
else
  MODE="findings"
fi

if [[ -n "$LANGUAGE" ]]; then
  case "$LANGUAGE" in
    python|javascript|typescript|rust|ruby|go) ;;
    *) die "--language must be one of: python javascript typescript rust ruby go (got '$LANGUAGE')" ;;
  esac
fi

[[ -z "$REPO_ROOT_ARG" ]] && { usage; die "REPO_ROOT positional argument required"; }
[[ -d "$REPO_ROOT_ARG" ]] || die "REPO_ROOT '$REPO_ROOT_ARG' is not a directory"
REPO_ROOT="$(cd "$REPO_ROOT_ARG" && pwd)"

# -- host tooling check (jq for is_configured biome.json check) ----------

command -v jq >/dev/null 2>&1 || die "jq is required" 3

# -- detection -----------------------------------------------------------

mapfile -t DETECTED < <("$DETECT_BIN" "$REPO_ROOT")

if [[ -n "$LANGUAGE" ]]; then
  found=0
  for l in "${DETECTED[@]}"; do
    [[ "$l" == "$LANGUAGE" ]] && { found=1; break; }
  done
  (( found == 1 )) || die "--language $LANGUAGE not detected in $REPO_ROOT (detected: ${DETECTED[*]:-none})"
  TARGET_LANGS=("$LANGUAGE")
else
  if [[ ${#DETECTED[@]} -eq 0 ]]; then
    echo "lintguini: no supported languages detected (need pyproject.toml/Cargo.toml/go.mod/Gemfile/.rubocop.yml/standard.yml/.standard.yml/tsconfig.json/package.json)" >&2
    exit 0
  fi
  TARGET_LANGS=("${DETECTED[@]}")
fi

# -- is_configured (mirrors lint.sh / format.sh) -------------------------

is_configured() {
  local lang="$1"
  case "$lang" in
    python)
      [[ -f "$REPO_ROOT/pyproject.toml" ]] \
        && grep -F -q "$PROVENANCE_MARK" "$REPO_ROOT/pyproject.toml"
      ;;
    javascript|typescript)
      [[ -f "$REPO_ROOT/biome.json" ]] \
        && jq -e --arg m "$PROVENANCE_MARK" \
            '(._provenance // "") | contains($m)' "$REPO_ROOT/biome.json" >/dev/null 2>&1
      ;;
    rust)
      [[ -f "$REPO_ROOT/rustfmt.toml" ]] \
        && grep -F -q "$PROVENANCE_MARK" "$REPO_ROOT/rustfmt.toml"
      ;;
    ruby)
      ( [[ -f "$REPO_ROOT/standard.yml" ]] && grep -F -q "$PROVENANCE_MARK" "$REPO_ROOT/standard.yml" ) \
        || ( [[ -f "$REPO_ROOT/.rubocop.yml" ]] && grep -F -q "$PROVENANCE_MARK" "$REPO_ROOT/.rubocop.yml" )
      ;;
    go)
      [[ -f "$REPO_ROOT/.golangci.yml" ]] \
        && grep -F -q "$PROVENANCE_MARK" "$REPO_ROOT/.golangci.yml"
      ;;
    *)
      return 1
      ;;
  esac
}

ruby_tool() {
  if [[ -f "$REPO_ROOT/standard.yml" ]] && grep -F -q "$PROVENANCE_MARK" "$REPO_ROOT/standard.yml"; then
    echo "standardrb"
  else
    echo "rubocop"
  fi
}

# -- shared helpers ------------------------------------------------------

tool_missing() {
  echo "$1: $2 not on PATH (install $2)" >&2
  exit 3
}

tool_failure() {
  echo "$1: $2 execution failed — $3" >&2
  exit 4
}

# normalize_diff
#   Read a unified diff blob on stdin and ensure each file marker carries
#   the standard a/ / b/ prefix expected by `git apply`. Tools that
#   already emit the prefix (the copy_and_diff helper) pass through
#   unchanged; tools that emit bare paths (ruff) get the prefix added.
normalize_diff() {
  awk '
    /^--- a\// { print; next }
    /^--- \/dev\/null/ { print; next }
    /^--- / { sub(/^--- /, "--- a/"); print; next }
    /^\+\+\+ b\// { print; next }
    /^\+\+\+ \/dev\/null/ { print; next }
    /^\+\+\+ / { sub(/^\+\+\+ /, "+++ b/"); print; next }
    { print }
  '
}

# extract_changed_paths
#   Read a unified diff blob on stdin and emit the unique file paths it
#   touches, one per line, sorted. Used by the apply path to enumerate
#   `fixed <path>` lines from a copy-and-diff or native diff output.
extract_changed_paths() {
  awk '
    /^--- a\// { sub(/^--- a\//, ""); print; next }
    /^--- / && !/^--- \/dev\/null/ { sub(/^--- /, ""); sub(/^a\//, ""); print; next }
  ' | LC_ALL=C sort -u
}

# copy_and_diff <command> [args...]
#
# Snapshot REPO_ROOT into a tempdir, run the command against the copy,
# then diff each file in the original against the copy. Emits a
# unified diff on stdout (one chunk per file that differs) with
# `--- a/<path>` / `+++ b/<path>` headers. Working tree untouched.
#
# Best-effort: the tool's exit code is ignored. The script reasons
# about whether files changed, not whether the tool said it succeeded
# (which is brittle across tool versions for "fix" semantics — most
# tools exit 1 to signal "had to change something" and that's not a
# failure here).
#
# Bulk dirs (.git, node_modules, vendor, target, dist, build) are
# pruned from the snapshot to keep tempdir size bounded for repos that
# carry vendored deps.
copy_and_diff() {
  local tmpdir
  tmpdir="$(mktemp -d -t lintguini-fix-cpy.XXXXXX)" || {
    echo "lintguini-fix: failed to create tempdir for copy-and-diff" >&2
    return 4
  }

  local files
  files="$(cd "$REPO_ROOT" && find . \
      \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist -o -name build \) -prune \) \
      -o -type f -print 2>/dev/null \
    | LC_ALL=C sort)"

  if [[ -z "$files" ]]; then
    rm -rf "$tmpdir"
    return 0
  fi

  while IFS= read -r f; do
    f="${f#./}"
    [[ -z "$f" ]] && continue
    local dest_dir="$tmpdir/$(dirname "$f")"
    mkdir -p "$dest_dir"
    cp "$REPO_ROOT/$f" "$tmpdir/$f"
  done <<< "$files"

  ( cd "$tmpdir" && "$@" >/dev/null 2>&1 ) || true

  while IFS= read -r f; do
    f="${f#./}"
    [[ -z "$f" ]] && continue
    [[ ! -f "$tmpdir/$f" ]] && continue
    if ! diff -q "$REPO_ROOT/$f" "$tmpdir/$f" >/dev/null 2>&1; then
      diff -u --label "a/$f" --label "b/$f" "$REPO_ROOT/$f" "$tmpdir/$f" || true
    fi
  done <<< "$files"

  rm -rf "$tmpdir"
}

# -- per-language fix functions ------------------------------------------
#
# Each fix_<lang> function:
#   - findings mode: emit a unified diff (or empty) to stdout.
#   - semantic mode: emit a unified diff (or empty) to stdout, OR write
#     an empty-scope explanation to stderr.
#   - apply mode: enumerate files-that-would-change (via the same diff
#     mechanism), run the apply command, emit `fixed <path>` per file.
#
# tool_missing is pre-flighted in the parent shell; the fix_<lang>
# functions never check command availability themselves.

fix_python() {
  case "$MODE" in
    findings)
      ( cd "$REPO_ROOT" && ruff check --fix --diff . 2>/dev/null ) | normalize_diff
      ;;
    apply)
      local diff_out
      diff_out="$(cd "$REPO_ROOT" && ruff check --fix --diff . 2>/dev/null)"
      ( cd "$REPO_ROOT" && ruff check --fix . >/dev/null 2>&1 )
      local rc=$?
      if (( rc != 0 && rc != 1 )); then
        tool_failure python ruff "exit $rc"
      fi
      [[ -z "$diff_out" ]] && return 0
      printf '%s\n' "$diff_out" | extract_changed_paths | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        printf 'fixed %s\n' "$f"
      done
      ;;
    semantic)
      ( cd "$REPO_ROOT" && ruff check --fix --unsafe-fixes --diff . 2>/dev/null ) | normalize_diff
      ;;
  esac
}

fix_biome() {
  local lang="$1"
  case "$MODE" in
    findings)
      copy_and_diff biome check --write .
      ;;
    apply)
      local diff_out
      diff_out="$(copy_and_diff biome check --write .)"
      ( cd "$REPO_ROOT" && biome check --write . >/dev/null 2>&1 )
      local rc=$?
      if (( rc != 0 && rc != 1 )); then
        tool_failure "$lang" biome "exit $rc"
      fi
      [[ -z "$diff_out" ]] && return 0
      printf '%s\n' "$diff_out" | extract_changed_paths | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        printf 'fixed %s\n' "$f"
      done
      ;;
    semantic)
      copy_and_diff biome check --write --unsafe .
      ;;
  esac
}

fix_javascript() { fix_biome javascript; }
fix_typescript() { fix_biome typescript; }

fix_rust() {
  case "$MODE" in
    findings)
      copy_and_diff cargo clippy --fix --allow-dirty --allow-staged
      ;;
    apply)
      local diff_out
      diff_out="$(copy_and_diff cargo clippy --fix --allow-dirty --allow-staged)"
      ( cd "$REPO_ROOT" && cargo clippy --fix --allow-dirty --allow-staged >/dev/null 2>&1 )
      local rc=$?
      # cargo clippy exits 0 on success, 1 on warnings, 101 on internal
      # errors that aren't actually fix failures. Treat 0/1/101 as
      # success — anything else is a real apply failure.
      if (( rc != 0 && rc != 1 && rc != 101 )); then
        tool_failure rust "cargo clippy" "exit $rc"
      fi
      [[ -z "$diff_out" ]] && return 0
      printf '%s\n' "$diff_out" | extract_changed_paths | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        printf 'fixed %s\n' "$f"
      done
      ;;
    semantic)
      echo "rust: --apply-semantic empty-scope (cargo clippy --fix has no safe/unsafe split)" >&2
      ;;
  esac
}

fix_ruby() {
  local tool; tool="$(ruby_tool)"
  case "$MODE" in
    findings)
      if [[ "$tool" == "standardrb" ]]; then
        copy_and_diff standardrb --fix .
      else
        copy_and_diff rubocop -a .
      fi
      ;;
    apply)
      local diff_out
      if [[ "$tool" == "standardrb" ]]; then
        diff_out="$(copy_and_diff standardrb --fix .)"
        ( cd "$REPO_ROOT" && standardrb --fix . >/dev/null 2>&1 )
      else
        diff_out="$(copy_and_diff rubocop -a .)"
        ( cd "$REPO_ROOT" && rubocop -a . >/dev/null 2>&1 )
      fi
      local rc=$?
      if (( rc != 0 && rc != 1 )); then
        tool_failure ruby "$tool" "exit $rc"
      fi
      [[ -z "$diff_out" ]] && return 0
      printf '%s\n' "$diff_out" | extract_changed_paths | while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        printf 'fixed %s\n' "$f"
      done
      ;;
    semantic)
      if [[ "$tool" == "standardrb" ]]; then
        echo "ruby: --apply-semantic empty-scope (standardrb has no safe/unsafe split)" >&2
      else
        copy_and_diff rubocop -A .
      fi
      ;;
  esac
}

fix_go() {
  case "$MODE" in
    findings)
      ( cd "$REPO_ROOT" && gofmt -d . 2>/dev/null ) | normalize_diff
      ;;
    apply)
      local file_list
      file_list="$(cd "$REPO_ROOT" && gofmt -l . 2>/dev/null | LC_ALL=C sort)"
      ( cd "$REPO_ROOT" && gofmt -w . 2>/dev/null )
      local rc=$?
      if (( rc != 0 )); then
        tool_failure go gofmt "exit $rc"
      fi
      [[ -z "$file_list" ]] && return 0
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        printf 'fixed %s\n' "$f"
      done <<< "$file_list"
      ;;
    semantic)
      echo "go: --apply-semantic empty-scope (gofmt is formatter-only; golangci-lint --fix dry-run support is patchy across versions)" >&2
      ;;
  esac
}

# -- main loop -----------------------------------------------------------

CONFIGURED_LANGS=()
for lang in "${TARGET_LANGS[@]}"; do
  if is_configured "$lang"; then
    CONFIGURED_LANGS+=("$lang")
  else
    echo "$lang: not configured (run /lintguini:configure --language $lang)" >&2
  fi
done

if [[ ${#CONFIGURED_LANGS[@]} -eq 0 ]]; then
  exit 0
fi

# Pre-flight tool availability for each configured language. tool_missing
# below exits 3 from the parent shell (mirrors format.sh's pattern;
# burying these checks inside fix_<lang> would lose the rc to subshell
# isolation). Empty-scope semantic modes (rust, go, standardrb) skip
# the tool check since they never invoke the tool.
for lang in "${CONFIGURED_LANGS[@]}"; do
  case "$lang" in
    python)
      command -v ruff >/dev/null 2>&1 || tool_missing python ruff
      ;;
    javascript|typescript)
      command -v biome >/dev/null 2>&1 || tool_missing "$lang" biome
      ;;
    rust)
      [[ "$MODE" != "semantic" ]] && { command -v cargo >/dev/null 2>&1 || tool_missing rust cargo; }
      ;;
    ruby)
      _tool="$(ruby_tool)"
      if [[ "$MODE" == "semantic" && "$_tool" == "standardrb" ]]; then
        : # empty-scope; no tool needed
      else
        command -v "$_tool" >/dev/null 2>&1 || tool_missing ruby "$_tool"
      fi
      ;;
    go)
      [[ "$MODE" != "semantic" ]] && { command -v gofmt >/dev/null 2>&1 || tool_missing go gofmt; }
      ;;
  esac
done

EMIT_HEADERS=0
(( ${#CONFIGURED_LANGS[@]} > 1 )) && EMIT_HEADERS=1

# section_header <lang> <count>
#   Emit a polyglot section header. Verb varies by mode.
section_header() {
  local lang="$1" count="$2"
  case "$MODE" in
    findings)
      if (( count == 1 )); then
        printf '# %s — 1 file with fixes available\n' "$lang"
      else
        printf '# %s — %s files with fixes available\n' "$lang" "$count"
      fi
      ;;
    semantic)
      if (( count == 1 )); then
        printf '# %s — 1 file with semantic fixes available\n' "$lang"
      else
        printf '# %s — %s files with semantic fixes available\n' "$lang" "$count"
      fi
      ;;
    apply)
      if (( count == 1 )); then
        printf '# %s — 1 file fixed\n' "$lang"
      else
        printf '# %s — %s files fixed\n' "$lang" "$count"
      fi
      ;;
  esac
}

# Per-mode counter. Diff blobs count `--- ` headers (one per file).
# Apply mode counts `fixed ` lines.
count_changed() {
  local out="$1"
  if [[ "$MODE" == "apply" ]]; then
    printf '%s\n' "$out" | grep -c '^fixed ' 2>/dev/null || echo 0
  else
    printf '%s\n' "$out" | grep -c '^--- ' 2>/dev/null || echo 0
  fi
}

TOTAL_CHANGED=0
for lang in "${CONFIGURED_LANGS[@]}"; do
  case "$lang" in
    python)     out="$(fix_python)";     fix_rc=$? ;;
    javascript) out="$(fix_javascript)"; fix_rc=$? ;;
    typescript) out="$(fix_typescript)"; fix_rc=$? ;;
    rust)       out="$(fix_rust)";       fix_rc=$? ;;
    ruby)       out="$(fix_ruby)";       fix_rc=$? ;;
    go)         out="$(fix_go)";         fix_rc=$? ;;
    *)          continue ;;
  esac
  # Propagate tool_missing / tool_failure exits up.
  if (( fix_rc == 3 || fix_rc == 4 )); then
    exit "$fix_rc"
  fi

  if [[ -z "$out" ]]; then
    count=0
  else
    count="$(count_changed "$out")"
  fi

  if (( EMIT_HEADERS == 1 && count > 0 )); then
    section_header "$lang" "$count"
  fi
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  fi
  TOTAL_CHANGED=$((TOTAL_CHANGED + count))
done

# Exit logic:
#   - findings / semantic: exit 1 if anything to fix, else 0.
#   - apply: exit 0 (tool failures already exited 4 above).
if [[ "$MODE" != "apply" && $TOTAL_CHANGED -gt 0 ]]; then
  exit 1
fi
exit 0
