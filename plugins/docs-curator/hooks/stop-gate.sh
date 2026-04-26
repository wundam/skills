#!/usr/bin/env bash
# docs-curator Stop hook gate.
# Decides whether to invoke the docs-curator skill based on lightweight git inspection.
# Always exits 0 (never blocks Claude). Outputs a system-reminder to stdout when audit is needed.

set -uo pipefail

# Bail silently if not in a git repo.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

STATE_FILE=".claude/docs-state.json"
SANCTIONED_PREFIX_REGEX='^(\.github/|\.claude/|\.cursor/|node_modules/|vendor/)'

# Compute current hash: sha256 of (git status -s) ++ HEAD oid.
HEAD_OID=$(git rev-parse HEAD 2>/dev/null || echo "no-head")
STATUS_OUT=$(git status -s 2>/dev/null || echo "")
CURRENT_HASH=$(printf '%s\n%s\n' "$STATUS_OUT" "$HEAD_OID" | shasum -a 256 | awk '{print $1}')

# Helper: emit reminder and exit.
emit_reminder() {
  local reason="$1"
  cat <<REMINDER
<system-reminder>
docs-curator: doc audit needed ($reason). Invoke skill: docs-curator.
</system-reminder>
REMINDER
  exit 0
}

# First-run mode: no state file → emit immediately.
if [ ! -f "$STATE_FILE" ]; then
  emit_reminder "first run, no state"
fi

# Read previous hash and head from state.
LAST_HASH=$(jq -r '.last_audit_state_hash // empty' "$STATE_FILE" 2>/dev/null || echo "")
LAST_HEAD=$(jq -r '.last_audit_head // empty' "$STATE_FILE" 2>/dev/null || echo "")

# Dedup: if state hash unchanged, exit silent.
if [ -n "$LAST_HASH" ] && [ "$LAST_HASH" = "$CURRENT_HASH" ]; then
  exit 0
fi

# --- Trigger condition (a): any .md changed in working tree, outside sanctioned folders.
MD_CHANGED=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  # status -s lines look like " M path/to/file" or "?? path"
  path="${line:3}"
  # Strip rename-target portion (" R old -> new")
  path="${path##* -> }"
  # Skip sanctioned folders
  if [[ "$path" =~ $SANCTIONED_PREFIX_REGEX ]]; then
    continue
  fi
  case "$path" in
    *.md|*.MD)
      MD_CHANGED=1
      break
      ;;
  esac
done <<< "$STATUS_OUT"

if [ "$MD_CHANGED" -eq 1 ]; then
  emit_reminder "working tree .md change"
fi

# --- Trigger condition (b): HEAD advanced AND code (non-doc) changed since last_audit_head.
if [ -n "$LAST_HEAD" ] && [ "$LAST_HEAD" != "$HEAD_OID" ] && [ "$HEAD_OID" != "no-head" ]; then
  # Verify last_head is reachable (could be on a different branch / rebased away)
  if git cat-file -e "$LAST_HEAD" 2>/dev/null; then
    # Was there any non-doc change between last_head and HEAD?
    NONDOC_CHANGE=$(git diff --name-only "$LAST_HEAD..$HEAD_OID" -- ':(exclude)*.md' ':(exclude).github/**' ':(exclude).claude/**' ':(exclude).cursor/**' 2>/dev/null | head -1)
    if [ -n "$NONDOC_CHANGE" ]; then
      # Was there a corresponding doc update? If not, stale risk.
      DOC_CHANGE=$(git diff --name-only "$LAST_HEAD..$HEAD_OID" -- '*.md' 2>/dev/null | head -1)
      if [ -z "$DOC_CHANGE" ]; then
        emit_reminder "code advanced without doc update (stale risk)"
      fi
    fi
  fi
fi

# --- Trigger condition (c): new folder with ≥3 source files, no README at any level above.
# (Cheap heuristic: look for folders introduced since last_head.)
if [ -n "$LAST_HEAD" ] && [ "$LAST_HEAD" != "$HEAD_OID" ] && [ "$HEAD_OID" != "no-head" ]; then
  if git cat-file -e "$LAST_HEAD" 2>/dev/null; then
    NEW_FILES=$(git diff --name-only --diff-filter=A "$LAST_HEAD..$HEAD_OID" 2>/dev/null || true)
    # Group by top-level directory
    declare -A DIR_COUNT=()
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      dir=$(dirname "$f")
      [ "$dir" = "." ] && continue
      DIR_COUNT["$dir"]=$(( ${DIR_COUNT["$dir"]:-0} + 1 ))
    done <<< "$NEW_FILES"
    for dir in "${!DIR_COUNT[@]}"; do
      if [ "${DIR_COUNT[$dir]}" -ge 3 ]; then
        # Walk up checking for README
        d="$dir"
        has_readme=0
        while [ "$d" != "." ] && [ "$d" != "/" ]; do
          if [ -f "$d/README.md" ] || [ -f "$d/README" ]; then
            has_readme=1
            break
          fi
          d=$(dirname "$d")
        done
        if [ "$has_readme" -eq 0 ] && [ ! -f "README.md" ]; then
          emit_reminder "new folder $dir without README"
        fi
      fi
    done
  fi
fi

# Nothing relevant changed.
exit 0
