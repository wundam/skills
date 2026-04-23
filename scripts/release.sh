#!/usr/bin/env bash
# Release a plugin: validate, bump semver, rewrite changelog, commit, tag.

set -euo pipefail

# Ensure we run from the repo root so relative paths resolve correctly.
# RELEASE_REPO_ROOT can be overridden (e.g. by tests pointing at a fixture dir).
if [ -n "${RELEASE_REPO_ROOT:-}" ]; then
  cd "$RELEASE_REPO_ROOT"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$SCRIPT_DIR/.."
fi

usage() {
  cat >&2 <<EOF
Usage: $0 <plugin-name> <patch|minor|major>

Bumps the specified plugin's version, rewrites its CHANGELOG, commits, and tags.
Requires:
  - clean working tree
  - populated [Unreleased] section in plugins/<plugin>/CHANGELOG.md
EOF
  exit 1
}

PLUGIN="${1:-}"
BUMP="${2:-}"

if [ -z "$PLUGIN" ] || [ -z "$BUMP" ]; then
  usage
fi

case "$BUMP" in
  patch|minor|major) ;;
  *) echo "Error: bump type must be patch, minor, or major (got '$BUMP')" >&2; exit 1 ;;
esac

PLUGIN_DIR="plugins/$PLUGIN"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "Error: plugin '$PLUGIN' not found at $PLUGIN_DIR" >&2
  exit 1
fi

if [ ! -f "$PLUGIN_JSON" ]; then
  echo "Error: $PLUGIN_JSON not found" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree is not clean; commit or stash before releasing" >&2
  exit 1
fi

CHANGELOG="$PLUGIN_DIR/CHANGELOG.md"

if [ ! -f "$CHANGELOG" ]; then
  echo "Error: $CHANGELOG not found" >&2
  exit 1
fi

# Require a populated [Unreleased] section. "Populated" means at least one
# non-blank, non-heading line between the [Unreleased] heading and the next
# "## [" heading (or end of file).
UNRELEASED_BODY=$(awk '
  /^## \[Unreleased\]/ { flag=1; next }
  /^## \[/ { flag=0 }
  flag { print }
' "$CHANGELOG" | awk 'NF { found=1 } END { exit !found }' && echo "populated" || echo "empty")

if ! grep -q '^## \[Unreleased\]' "$CHANGELOG"; then
  echo "Error: $CHANGELOG has no [Unreleased] section" >&2
  exit 1
fi

if [ "$UNRELEASED_BODY" = "empty" ]; then
  echo "Error: [Unreleased] section in $CHANGELOG is empty; populate before releasing" >&2
  exit 1
fi

MARKETPLACE_JSON=".claude-plugin/marketplace.json"

if [ ! -f "$MARKETPLACE_JSON" ]; then
  echo "Error: $MARKETPLACE_JSON not found" >&2
  exit 1
fi

CURRENT_VERSION=$(jq -r '.version' "$PLUGIN_JSON")

if ! [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: current version '$CURRENT_VERSION' is not semver (X.Y.Z)" >&2
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

# Update plugin.json
tmp=$(mktemp)
jq --arg v "$NEW_VERSION" '.version = $v' "$PLUGIN_JSON" > "$tmp"
mv "$tmp" "$PLUGIN_JSON"

# Update marketplace.json entry
tmp=$(mktemp)
jq --arg n "$PLUGIN" --arg v "$NEW_VERSION" \
  '(.plugins[] | select(.name == $n) | .version) = $v' \
  "$MARKETPLACE_JSON" > "$tmp"
mv "$tmp" "$MARKETPLACE_JSON"

TODAY=$(date +%Y-%m-%d)

# Rewrite CHANGELOG: rename [Unreleased] → [NEW_VERSION] - TODAY, insert empty
# [Unreleased] above it.
tmp=$(mktemp)
awk -v new="$NEW_VERSION" -v today="$TODAY" '
  /^## \[Unreleased\]/ && !done {
    print "## [Unreleased]"
    print ""
    print "## [" new "] - " today
    done = 1
    next
  }
  { print }
' "$CHANGELOG" > "$tmp"
mv "$tmp" "$CHANGELOG"

# Commit
git add "$PLUGIN_JSON" "$MARKETPLACE_JSON" "$CHANGELOG"
git commit -q -m "release($PLUGIN): v$NEW_VERSION"

# Annotated tag
TAG="$PLUGIN/v$NEW_VERSION"
git tag -a "$TAG" -m "Release $PLUGIN v$NEW_VERSION"

cat <<EOF

Released $PLUGIN v$NEW_VERSION

Next steps:
  git push origin main
  git push origin $TAG
EOF
