#!/usr/bin/env bash
# Verify that every `references/...md` and `templates/...tmpl` path mentioned
# in SKILL.md exists on disk. Run from the repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$SCRIPT_DIR/../skills/team-review"
SKILL_MD="$SKILL_ROOT/SKILL.md"

if [ ! -f "$SKILL_MD" ]; then
  echo "Error: $SKILL_MD not found" >&2
  exit 1
fi

# Extract every `references/...md` and `templates/...tmpl` token the skill
# mentions (including bare mentions and markdown code spans).
refs=$(grep -oE '(references|templates)/[a-zA-Z0-9._-]+\.(md|tmpl)' "$SKILL_MD" | sort -u)

if [ -z "$refs" ]; then
  echo "Warning: SKILL.md mentions no references/ or templates/ paths." >&2
  exit 0
fi

missing=0
checked=0

while IFS= read -r ref; do
  checked=$((checked + 1))
  target="$SKILL_ROOT/$ref"
  if [ ! -f "$target" ]; then
    echo "MISSING: $ref"
    missing=$((missing + 1))
  fi
done <<< "$refs"

echo ""
echo "Checked $checked path(s). Missing: $missing."

if [ "$missing" -gt 0 ]; then
  exit 1
fi
