#!/usr/bin/env bash
# inkwell-tidy.sh — surface (and optionally fix) doc-tree drift.
#
# Default invocation is read-only: print one finding per stdout line,
# `<path>  rule=<rule>  details: <text>`. Findings are sorted by path
# then rule for determinism. Clean tree → exit 0 with empty stdout.
#
# Modes:
#   (default)         read-only finding pass; no writes
#   --apply           mechanical fixes: link rewrites on renames,
#                     frontmatter `updated:` bumps, archive stale docs,
#                     near-identical dedup (overlap >= duplicate_overlap_archive)
#   --apply-semantic  emit unified diffs for dedup choices in the
#                     duplicate_overlap_min..duplicate_overlap_archive band;
#                     never writes to the working tree
#
# Rules detected (read-only and --apply paths re-detect to operate on
# the current tree state):
#   duplicate                — title + body shingle Jaccard overlap
#                              >= duplicate_overlap_min (pairs only)
#   dead-link                — link target does not resolve under the
#                              source file's dir (or repo root for `/`)
#   stale                    — git mtime drift > staleness_days
#   template-non-compliance  — frontmatter missing or invalid
#                              (template / title / updated)
#   missing-related          — terminal `## Related` block absent or
#                              contains only the bare `-` placeholder.
#                              A `<!-- inkwell:related -->` HTML comment
#                              counts as writer-acknowledged-empty: no
#                              finding fires. Real bullets short-circuit
#                              the rule the same way.
#
# Thresholds live in `references/thresholds.json` so the staleness
# scorer and tidy share one knob. `jq` absence falls back to inline
# defaults documented in references/thresholds.md.
#
# Usage:
#   inkwell-tidy.sh [--apply | --apply-semantic] [REPO_ROOT]
#
# Exit 0 in every documented case (read-only finding, no findings,
# applied fixes, semantic diff). Exit 2 on argument errors.

set -uo pipefail

usage() {
  cat <<'EOF' >&2
Usage: inkwell-tidy.sh [--apply | --apply-semantic] [REPO_ROOT]

Modes:
  (default)         read-only finding pass; one finding per stdout line
  --apply           apply mechanical fixes (link rewrites, updated: bumps,
                    archive stale docs, near-identical dedup)
  --apply-semantic  emit unified diffs for dedup choices in the
                    duplicate_overlap_min..duplicate_overlap_archive band;
                    never writes to the working tree
EOF
}

MODE="findings"
REPO_ROOT_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)          MODE="apply"; shift ;;
    --apply-semantic) MODE="semantic"; shift ;;
    -h|--help)        usage; exit 0 ;;
    --*)              echo "Unknown flag: $1" >&2; usage; exit 2 ;;
    *)
      if [[ -n "$REPO_ROOT_ARG" ]]; then
        echo "Unexpected positional: $1" >&2; usage; exit 2
      fi
      REPO_ROOT_ARG="$1"; shift ;;
  esac
done

REPO_ROOT="${REPO_ROOT_ARG:-$(pwd)}"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "inkwell-tidy.sh: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
DOCS_DIR="$REPO_ROOT/docs"

if [[ ! -d "$DOCS_DIR" ]]; then
  exit 0
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THRESHOLDS_JSON="$HERE/../references/thresholds.json"

# Source the shingle/Jaccard helpers (frontmatter parsing + bigram
# math) used by the `duplicate` rule. _common.sh ships with
# `set -euo pipefail`; tidy is intentionally fail-soft in many
# branches, so restore the looser option set after sourcing.
# shellcheck source=./_common.sh
. "$HERE/_common.sh"
set +e

STALENESS_DAYS=90
DUP_MIN="0.85"
DUP_ARCHIVE="0.95"
RENAME_LOOKBACK=30

if [[ -f "$THRESHOLDS_JSON" ]] && command -v jq >/dev/null 2>&1; then
  v="$(jq -r '.staleness_days // 90' <"$THRESHOLDS_JSON" 2>/dev/null || echo 90)"
  [[ "$v" =~ ^[0-9]+$ ]] && STALENESS_DAYS="$v"
  v="$(jq -r '.tidy.duplicate_overlap_min // 0.85' <"$THRESHOLDS_JSON" 2>/dev/null || echo 0.85)"
  DUP_MIN="$v"
  v="$(jq -r '.tidy.duplicate_overlap_archive // 0.95' <"$THRESHOLDS_JSON" 2>/dev/null || echo 0.95)"
  DUP_ARCHIVE="$v"
  v="$(jq -r '.tidy.rename_lookback_commits // 30' <"$THRESHOLDS_JSON" 2>/dev/null || echo 30)"
  [[ "$v" =~ ^[0-9]+$ ]] && RENAME_LOOKBACK="$v"
fi

NOW="$(date +%s)"
THRESHOLD_SECONDS=$((STALENESS_DAYS * 86400))
VALID_TEMPLATES="concept how-to reference tutorial"

# ---------------------------------------------------------------------
# Portable path helpers.
#
# `realpath -m` and `realpath --relative-to=` are GNU coreutils only;
# macOS / BSD ships `realpath` without those flags. The link-rewriter
# resolves possibly-nonexistent paths (the `-m` semantic) and computes
# relative paths against an anchor (the `--relative-to=` semantic), so
# both branches need a portable form. Mirror the GNU/BSD `stat`
# detection in inkwell-index.sh: probe once with the GNU invocation,
# fall back to a Python shim on failure (Python 3 ships on every
# supported macOS).
#
#   _path_canonical <path>          → absolute, with `.` / `..` / `//`
#                                     normalised; existence not required
#   _path_relative_to <anchor> <p>  → path of <p> relative to <anchor>
# ---------------------------------------------------------------------

if realpath -m --relative-to=/ / >/dev/null 2>&1; then
  _path_canonical()    { realpath -m "$1"; }
  _path_relative_to()  { realpath -m --relative-to="$1" "$2"; }
else
  _path_canonical() {
    python3 -c 'import os, sys; print(os.path.normpath(os.path.abspath(sys.argv[1])))' "$1"
  }
  _path_relative_to() {
    python3 -c 'import os, sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' "$1" "$2"
  }
fi

# ---------------------------------------------------------------------
# Common helpers (extract_frontmatter / extract_body / fm_field mirror
# the inkwell-index.sh implementations — kept inline rather than
# sourced to keep this script standalone).
# ---------------------------------------------------------------------

list_docs() {
  find "$DOCS_DIR" -type f -name '*.md' \
    ! -path "$DOCS_DIR/templates/*" \
    ! -path "$DOCS_DIR/archive/*" \
    ! -name '_*.md' 2>/dev/null | LC_ALL=C sort
}

extract_frontmatter() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { exit }
    in_fm { print }
  ' "$1"
}

extract_body() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { in_fm=0; next }
    in_fm { next }
    { print }
  ' "$1"
}

fm_field() {
  local key="$1" fm="$2"
  awk -v k="$key" '
    BEGIN { needle = "^" k ":[[:space:]]*" }
    $0 ~ needle {
      sub(needle, "")
      sub(/[[:space:]]+$/, "")
      gsub(/^"|"$/, "")
      gsub(/^'\''|'\''$/, "")
      print
      exit
    }
  ' <<<"$fm"
}

# ---------------------------------------------------------------------
# Findings buffer — TSV rows: <path>\trule=<rule>\tdetails: <text>.
# Sorted on stdout in the findings mode.
# ---------------------------------------------------------------------

FINDINGS_FILE="$(mktemp -t inkwell-tidy-find.XXXXXX)"
DUP_PAIRS_FILE="$(mktemp -t inkwell-tidy-pairs.XXXXXX)"
BIGRAM_DIR="$(mktemp -d -t inkwell-tidy-bigrams.XXXXXX)"
trap 'rm -rf "$FINDINGS_FILE" "$DUP_PAIRS_FILE" "$BIGRAM_DIR"' EXIT

emit_finding() {
  local path="$1" rule="$2" details="$3"
  printf '%s\trule=%s\tdetails: %s\n' "$path" "$rule" "$details" >>"$FINDINGS_FILE"
}

# ---------------------------------------------------------------------
# Per-doc rule checks.
# ---------------------------------------------------------------------

check_template_compliance() {
  local file="$1" rel="$2" fm
  fm="$(extract_frontmatter "$file")"
  if [[ -z "$fm" ]]; then
    emit_finding "$rel" "template-non-compliance" "no frontmatter block"
    return
  fi
  local title updated template
  title="$(fm_field title "$fm")"
  updated="$(fm_field updated "$fm")"
  template="$(fm_field template "$fm")"

  if [[ -z "$title" ]]; then
    emit_finding "$rel" "template-non-compliance" "frontmatter missing required field: title"
  fi
  if [[ -z "$updated" ]]; then
    emit_finding "$rel" "template-non-compliance" "frontmatter missing required field: updated"
  fi
  if [[ -z "$template" ]]; then
    emit_finding "$rel" "template-non-compliance" "frontmatter missing required field: template"
    return
  fi
  local valid=0 t
  for t in $VALID_TEMPLATES; do
    [[ "$t" == "$template" ]] && valid=1 && break
  done
  if (( valid == 0 )); then
    emit_finding "$rel" "template-non-compliance" \
      "frontmatter template '$template' not in {concept, how-to, reference, tutorial}"
  fi
}

check_missing_related() {
  local file="$1" rel="$2"
  local related_lineno
  related_lineno="$(awk '/^##[[:space:]]+Related[[:space:]]*$/ { last = NR } END { if (last) print last }' "$file")"
  if [[ -z "$related_lineno" ]]; then
    emit_finding "$rel" "missing-related" "terminal \`## Related\` heading absent"
    return
  fi
  local meaningful
  meaningful="$(awk -v start="$related_lineno" '
    NR <= start { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*-[[:space:]]*$/ { next }
    { print; exit }
  ' "$file")"
  if [[ -z "$meaningful" ]]; then
    emit_finding "$rel" "missing-related" \
      "\`## Related\` block has no content (add bullets, or use \`<!-- inkwell:related -->\` to mark intentionally empty)"
  fi
}

check_dead_links() {
  local file="$1" rel="$2"
  local file_dir url path_part target_abs rel_target
  file_dir="$(dirname "$file")"
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    case "$url" in
      http://*|https://*|mailto:*|ftp://*|\#*) continue ;;
    esac
    path_part="${url%%#*}"
    [[ -z "$path_part" ]] && continue
    if [[ "$path_part" == /* ]]; then
      target_abs="$REPO_ROOT$path_part"
    else
      target_abs="$file_dir/$path_part"
    fi
    if [[ ! -e "$target_abs" ]]; then
      rel_target="${target_abs#$REPO_ROOT/}"
      emit_finding "$rel" "dead-link" "link target does not resolve: $rel_target"
    fi
  done < <(extract_body "$file" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//' | LC_ALL=C sort -u)
}

check_stale() {
  local file="$1" rel="$2" ct drift drift_days
  ct="$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$rel" 2>/dev/null || true)"
  ct="${ct:-0}"
  if [[ ! "$ct" =~ ^[0-9]+$ ]] || (( ct == 0 )); then
    return
  fi
  drift=$((NOW - ct))
  if (( drift > THRESHOLD_SECONDS )); then
    drift_days=$((drift / 86400))
    emit_finding "$rel" "stale" "git mtime drift ${drift_days}d > threshold ${STALENESS_DAYS}d"
  fi
}

# ---------------------------------------------------------------------
# Duplicate detection — title + body bigram Jaccard.
# Pairs only, no transitive merging. The alphabetic-earlier path is the
# finding's primary path; the partner path appears in `details:`.
#
# Math (bigrams_for_doc / jaccard_files) lives in bin/_common.sh.
# Tidy keeps only the pair-finding loop and the per-pair float
# comparison helpers below.
# ---------------------------------------------------------------------

# Float comparison via awk (locale-independent).
ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 >= b+0) }'; }
lt() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 <  b+0) }'; }

detect_duplicates() {
  local docs=("$@")
  local n=${#docs[@]} i j a b score bi_count bj_count
  if (( n < 2 )); then return; fi
  for ((i=0; i<n; i++)); do
    bigrams_for_doc "$REPO_ROOT/${docs[i]}" "$BIGRAM_DIR/$i"
  done
  for ((i=0; i<n; i++)); do
    bi_count="$(wc -l <"$BIGRAM_DIR/$i" | tr -d ' ')"
    if (( bi_count < 5 )); then continue; fi
    for ((j=i+1; j<n; j++)); do
      bj_count="$(wc -l <"$BIGRAM_DIR/$j" | tr -d ' ')"
      if (( bj_count < 5 )); then continue; fi
      score="$(jaccard_files "$BIGRAM_DIR/$i" "$BIGRAM_DIR/$j")"
      if ge "$score" "$DUP_MIN"; then
        a="${docs[i]}"; b="${docs[j]}"
        if [[ "$a" > "$b" ]]; then
          local tmp="$a"; a="$b"; b="$tmp"
        fi
        printf '%s\t%s\t%s\n' "$score" "$a" "$b" >>"$DUP_PAIRS_FILE"
        emit_finding "$a" "duplicate" "$score shingle overlap with $b"
      fi
    done
  done
}

# ---------------------------------------------------------------------
# Run all detection passes (always run; modes consume the buffers).
# ---------------------------------------------------------------------

mapfile -t ALL_DOC_ABS < <(list_docs)
ALL_DOC_RELS=()
for f in "${ALL_DOC_ABS[@]}"; do
  ALL_DOC_RELS+=("${f#$REPO_ROOT/}")
done

for f in "${ALL_DOC_ABS[@]}"; do
  rel="${f#$REPO_ROOT/}"
  check_template_compliance "$f" "$rel"
  check_missing_related "$f" "$rel"
  check_dead_links "$f" "$rel"
  check_stale "$f" "$rel"
done

if (( ${#ALL_DOC_RELS[@]} >= 2 )); then
  detect_duplicates "${ALL_DOC_RELS[@]}"
fi

# ---------------------------------------------------------------------
# Mode: read-only findings.
# ---------------------------------------------------------------------

if [[ "$MODE" == "findings" ]]; then
  if [[ -s "$FINDINGS_FILE" ]]; then
    LC_ALL=C sort "$FINDINGS_FILE" | awk -F'\t' '{ printf "%s  %s  %s\n", $1, $2, $3 }'
  fi
  exit 0
fi

# ---------------------------------------------------------------------
# Inbound link rewriter. Best-effort: scans every markdown file in
# docs/, finds (URL) link targets, resolves each relative to its source
# dir, rewrites those that resolve to OLD to a new relative path
# pointing at NEW. Skips http/https/mailto and intra-doc anchors.
# ---------------------------------------------------------------------

rewrite_inbound_links() {
  local old_rel="$1" new_rel="$2"
  local old_abs="$REPO_ROOT/$old_rel"
  local new_abs="$REPO_ROOT/$new_rel"
  local mdfile mdfile_dir url path_part frag target_abs new_relpath new_url
  while IFS= read -r mdfile; do
    [[ -z "$mdfile" ]] && continue
    [[ "$mdfile" == "$old_abs" ]] && continue
    [[ "$mdfile" == "$new_abs" ]] && continue
    mdfile_dir="$(dirname "$mdfile")"
    local content
    content="$(cat "$mdfile")"
    local changed=0
    while IFS= read -r url; do
      [[ -z "$url" ]] && continue
      case "$url" in
        http://*|https://*|mailto:*|ftp://*|\#*) continue ;;
      esac
      path_part="${url%%#*}"
      frag=""
      if [[ "$url" == *"#"* ]]; then frag="#${url#*#}"; fi
      [[ -z "$path_part" ]] && continue
      if [[ "$path_part" == /* ]]; then
        target_abs="$REPO_ROOT$path_part"
      else
        target_abs="$(_path_canonical "$mdfile_dir/$path_part" 2>/dev/null || true)"
      fi
      [[ -z "$target_abs" ]] && continue
      if [[ "$target_abs" == "$old_abs" ]]; then
        new_relpath="$(_path_relative_to "$mdfile_dir" "$new_abs" 2>/dev/null || true)"
        [[ -z "$new_relpath" ]] && continue
        new_url="${new_relpath}${frag}"
        # Replace literal `(URL)` with `(NEW_URL)` everywhere in the file.
        local pat="($url)" rep="($new_url)"
        content="${content//$pat/$rep}"
        changed=1
      fi
    done < <(printf '%s\n' "$content" | grep -oE '\([^)]+\)' | sed -E 's/^\(//; s/\)$//' | LC_ALL=C sort -u)
    if (( changed )); then
      printf '%s\n' "$content" >"$mdfile"
      printf 'applied  rule=link-rewrite  %s  → target %s\n' "${mdfile#$REPO_ROOT/}" "$new_rel"
    fi
  done < <(find "$DOCS_DIR" -type f -name '*.md' ! -path "$DOCS_DIR/templates/*")
}

# ---------------------------------------------------------------------
# `--apply` fix passes.
# ---------------------------------------------------------------------

apply_renames_link_rewrite() {
  # `git log --diff-filter=R --name-status -<N>` over the lookback window.
  # Lines: `R<score>\t<old>\t<new>`. Both old and new are repo-relative.
  if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    return
  fi
  while IFS=$'\t' read -r status old new; do
    [[ -z "$status" || -z "$old" || -z "$new" ]] && continue
    case "$status" in R*) ;; *) continue ;; esac
    case "$old" in docs/*) ;; *) continue ;; esac
    case "$new" in docs/*) ;; *) continue ;; esac
    # Only rewrite if the old path is gone and the new path exists.
    [[ -e "$REPO_ROOT/$old" ]] && continue
    [[ ! -e "$REPO_ROOT/$new" ]] && continue
    rewrite_inbound_links "$old" "$new"
  done < <(git -C "$REPO_ROOT" log --diff-filter=R --name-status -n "$RENAME_LOOKBACK" 2>/dev/null \
            | awk 'BEGIN { OFS="\t" } /^R[0-9]+\t/ { print $1, $2, $3 }')
}

apply_updated_bumps() {
  # For each doc, if git mtime date > frontmatter `updated:` date,
  # rewrite the `updated:` line to the git mtime date.
  local file rel ct ct_date fm updated
  for file in "${ALL_DOC_ABS[@]}"; do
    rel="${file#$REPO_ROOT/}"
    ct="$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$rel" 2>/dev/null || true)"
    ct="${ct:-0}"
    [[ ! "$ct" =~ ^[0-9]+$ ]] && continue
    (( ct == 0 )) && continue
    ct_date="$(date -u -d "@$ct" +%Y-%m-%d 2>/dev/null || date -u -r "$ct" +%Y-%m-%d 2>/dev/null || true)"
    [[ -z "$ct_date" ]] && continue
    fm="$(extract_frontmatter "$file")"
    [[ -z "$fm" ]] && continue
    updated="$(fm_field updated "$fm")"
    [[ -z "$updated" ]] && continue
    if [[ "$ct_date" > "$updated" ]]; then
      local tmp
      tmp="$(mktemp)"
      awk -v new="$ct_date" '
        BEGIN { in_fm=0; bumped=0 }
        NR==1 && $0=="---" { in_fm=1; print; next }
        in_fm && $0=="---" { in_fm=0; print; next }
        in_fm && !bumped && /^updated:[[:space:]]*/ {
          print "updated: " new
          bumped=1
          next
        }
        { print }
      ' "$file" >"$tmp"
      mv "$tmp" "$file"
      printf 'applied  rule=updated-stamp  %s  bumped updated: %s → %s\n' "$rel" "$updated" "$ct_date"
    fi
  done
}

apply_archive_stale() {
  # Re-derive stale findings from the buffer; for each, move to docs/archive/
  # preserving the under-docs subpath.
  local rel new_rel src_dir
  while IFS=$'\t' read -r rel rule_field _details; do
    [[ "$rule_field" != "rule=stale" ]] && continue
    [[ "$rel" != docs/* ]] && continue
    # docs/legacy/old.md → docs/archive/legacy/old.md
    new_rel="docs/archive/${rel#docs/}"
    [[ -e "$REPO_ROOT/$new_rel" ]] && continue
    src_dir="$(dirname "$REPO_ROOT/$new_rel")"
    mkdir -p "$src_dir"
    if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 \
       && git -C "$REPO_ROOT" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
      git -C "$REPO_ROOT" mv "$rel" "$new_rel" >/dev/null
    else
      mv "$REPO_ROOT/$rel" "$REPO_ROOT/$new_rel"
    fi
    printf 'applied  rule=archive-stale  %s → %s\n' "$rel" "$new_rel"
    rewrite_inbound_links "$rel" "$new_rel"
  done <"$FINDINGS_FILE"
}

apply_dedup_archive() {
  # For pairs with overlap >= duplicate_overlap_archive: keep the newer doc,
  # archive the older.
  local score a b a_ct b_ct older newer new_rel src_dir
  while IFS=$'\t' read -r score a b; do
    [[ -z "$score" ]] && continue
    if ! ge "$score" "$DUP_ARCHIVE"; then continue; fi
    [[ ! -e "$REPO_ROOT/$a" || ! -e "$REPO_ROOT/$b" ]] && continue
    a_ct="$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$a" 2>/dev/null || echo 0)"
    b_ct="$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$b" 2>/dev/null || echo 0)"
    a_ct="${a_ct:-0}"; b_ct="${b_ct:-0}"
    if (( a_ct < b_ct )); then older="$a"; newer="$b"
    else older="$b"; newer="$a"
    fi
    new_rel="docs/archive/${older#docs/}"
    [[ -e "$REPO_ROOT/$new_rel" ]] && continue
    src_dir="$(dirname "$REPO_ROOT/$new_rel")"
    mkdir -p "$src_dir"
    if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 \
       && git -C "$REPO_ROOT" ls-files --error-unmatch "$older" >/dev/null 2>&1; then
      git -C "$REPO_ROOT" mv "$older" "$new_rel" >/dev/null
    else
      mv "$REPO_ROOT/$older" "$REPO_ROOT/$new_rel"
    fi
    printf 'applied  rule=dedup-archive  %s → %s (kept %s, overlap %s)\n' \
      "$older" "$new_rel" "$newer" "$score"
    rewrite_inbound_links "$older" "$new_rel"
  done <"$DUP_PAIRS_FILE"
}

if [[ "$MODE" == "apply" ]]; then
  apply_renames_link_rewrite
  apply_updated_bumps
  apply_archive_stale
  apply_dedup_archive
  exit 0
fi

# ---------------------------------------------------------------------
# `--apply-semantic` — emit unified diffs for dedup choices in the
# duplicate_overlap_min..duplicate_overlap_archive band. Never writes.
#
# v1 scope: propose deletion of the older of each pair (the "proposed
# canonical" is the more recent doc). The diff is plain `diff -u`
# against /dev/null, suitable for `git apply`.
# ---------------------------------------------------------------------

if [[ "$MODE" == "semantic" ]]; then
  while IFS=$'\t' read -r score a b; do
    [[ -z "$score" ]] && continue
    if ! ge "$score" "$DUP_MIN"; then continue; fi
    if ! lt "$score" "$DUP_ARCHIVE"; then continue; fi
    [[ ! -e "$REPO_ROOT/$a" || ! -e "$REPO_ROOT/$b" ]] && continue
    local_a_ct="$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$a" 2>/dev/null || echo 0)"
    local_b_ct="$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$b" 2>/dev/null || echo 0)"
    local_a_ct="${local_a_ct:-0}"; local_b_ct="${local_b_ct:-0}"
    if (( local_a_ct < local_b_ct )); then older="$a"; newer="$b"
    else older="$b"; newer="$a"
    fi
    printf '# tidy: dedup choice for %s ↔ %s (overlap %s)\n' "$a" "$b" "$score"
    printf '# proposed canonical: %s (newer); diff below proposes deleting %s\n' "$newer" "$older"
    diff -u --label "a/$older" --label "/dev/null" "$REPO_ROOT/$older" /dev/null || true
  done <"$DUP_PAIRS_FILE"
  exit 0
fi

exit 0
