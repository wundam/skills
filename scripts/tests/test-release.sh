#!/usr/bin/env bash
# Integration tests for scripts/release.sh.
# Each test creates an isolated temp-dir git repo and runs release.sh against it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_SCRIPT="$REPO_ROOT/scripts/release.sh"

PASS=0
FAIL=0
CURRENT_TEST=""

assert_eq() {
  local actual="$1" expected="$2" msg="${3:-assertion}"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "  FAIL [$CURRENT_TEST]: $msg"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_nonzero_exit() {
  local code="$1" msg="${2:-should exit non-zero}"
  if [ "$code" -ne 0 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "  FAIL [$CURRENT_TEST]: $msg (got exit 0)"
  fi
}

setup_fixture() {
  FIXTURE_DIR=$(mktemp -d)
  export RELEASE_REPO_ROOT="$FIXTURE_DIR"
  cd "$FIXTURE_DIR"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test User"
  mkdir -p .claude-plugin plugins/foo/.claude-plugin
  cat > .claude-plugin/marketplace.json <<'JSON'
{
  "name": "test",
  "description": "test marketplace",
  "plugins": [
    {
      "name": "foo",
      "source": "./plugins/foo",
      "description": "Foo plugin",
      "version": "0.1.0"
    }
  ]
}
JSON
  cat > plugins/foo/.claude-plugin/plugin.json <<'JSON'
{
  "name": "foo",
  "version": "0.1.0",
  "description": "Foo plugin"
}
JSON
  cat > plugins/foo/CHANGELOG.md <<'MD'
# Changelog

## [Unreleased]

- Added initial feature
MD
  git add -A
  git commit -qm "init"
}

teardown_fixture() {
  unset RELEASE_REPO_ROOT
  cd "$REPO_ROOT"
  rm -rf "$FIXTURE_DIR"
}

# --- tests -----------------------------------------------------------------

test_missing_args_fails() {
  CURRENT_TEST="missing_args_fails"
  setup_fixture
  local code=0
  bash "$RELEASE_SCRIPT" > /dev/null 2>&1 || code=$?
  assert_nonzero_exit "$code" "no args should fail"
  teardown_fixture
}

test_invalid_bump_type_fails() {
  CURRENT_TEST="invalid_bump_type_fails"
  setup_fixture
  local code=0
  bash "$RELEASE_SCRIPT" foo banana > /dev/null 2>&1 || code=$?
  assert_nonzero_exit "$code" "invalid bump type should fail"
  teardown_fixture
}

test_missing_plugin_fails() {
  CURRENT_TEST="missing_plugin_fails"
  setup_fixture
  local code=0
  bash "$RELEASE_SCRIPT" does-not-exist patch > /dev/null 2>&1 || code=$?
  assert_nonzero_exit "$code" "missing plugin should fail"
  teardown_fixture
}

test_dirty_tree_fails() {
  CURRENT_TEST="dirty_tree_fails"
  setup_fixture
  echo "dirty" > plugins/foo/dirty.txt
  local code=0
  bash "$RELEASE_SCRIPT" foo patch > /dev/null 2>&1 || code=$?
  assert_nonzero_exit "$code" "dirty tree should fail"
  teardown_fixture
}

test_missing_unreleased_section_fails() {
  CURRENT_TEST="missing_unreleased_section_fails"
  setup_fixture
  cat > plugins/foo/CHANGELOG.md <<'MD'
# Changelog

## [0.1.0] - 2026-01-01

- initial
MD
  git add -A && git commit -qm "drop unreleased"
  local code=0
  bash "$RELEASE_SCRIPT" foo patch > /dev/null 2>&1 || code=$?
  assert_nonzero_exit "$code" "missing [Unreleased] should fail"
  teardown_fixture
}

test_empty_unreleased_section_fails() {
  CURRENT_TEST="empty_unreleased_section_fails"
  setup_fixture
  cat > plugins/foo/CHANGELOG.md <<'MD'
# Changelog

## [Unreleased]

## [0.1.0] - 2026-01-01

- initial
MD
  git add -A && git commit -qm "empty unreleased"
  local code=0
  bash "$RELEASE_SCRIPT" foo patch > /dev/null 2>&1 || code=$?
  assert_nonzero_exit "$code" "empty [Unreleased] should fail"
  teardown_fixture
}

_read_plugin_version() {
  jq -r '.version' plugins/foo/.claude-plugin/plugin.json
}

_read_marketplace_version() {
  jq -r '.plugins[] | select(.name=="foo") | .version' .claude-plugin/marketplace.json
}

test_patch_bump_updates_jsons() {
  CURRENT_TEST="patch_bump_updates_jsons"
  setup_fixture
  bash "$RELEASE_SCRIPT" foo patch > /dev/null 2>&1 || true
  assert_eq "$(_read_plugin_version)" "0.1.1" "plugin.json bumped to 0.1.1"
  assert_eq "$(_read_marketplace_version)" "0.1.1" "marketplace.json bumped to 0.1.1"
  teardown_fixture
}

test_minor_bump_updates_jsons() {
  CURRENT_TEST="minor_bump_updates_jsons"
  setup_fixture
  bash "$RELEASE_SCRIPT" foo minor > /dev/null 2>&1 || true
  assert_eq "$(_read_plugin_version)" "0.2.0" "plugin.json bumped to 0.2.0"
  assert_eq "$(_read_marketplace_version)" "0.2.0" "marketplace.json bumped to 0.2.0"
  teardown_fixture
}

test_major_bump_updates_jsons() {
  CURRENT_TEST="major_bump_updates_jsons"
  setup_fixture
  bash "$RELEASE_SCRIPT" foo major > /dev/null 2>&1 || true
  assert_eq "$(_read_plugin_version)" "1.0.0" "plugin.json bumped to 1.0.0"
  assert_eq "$(_read_marketplace_version)" "1.0.0" "marketplace.json bumped to 1.0.0"
  teardown_fixture
}

test_changelog_rewrite() {
  CURRENT_TEST="changelog_rewrite"
  setup_fixture
  bash "$RELEASE_SCRIPT" foo patch > /dev/null 2>&1 || true

  # There should be exactly one [Unreleased] heading, and it should be empty.
  local unreleased_count
  unreleased_count=$(grep -c '^## \[Unreleased\]' plugins/foo/CHANGELOG.md || true)
  assert_eq "$unreleased_count" "1" "exactly one [Unreleased] heading"

  # The new version heading should exist with today's date.
  local today
  today=$(date +%Y-%m-%d)
  local has_version
  if grep -q "^## \[0.1.1\] - $today" plugins/foo/CHANGELOG.md; then
    has_version="yes"
  else
    has_version="no"
  fi
  assert_eq "$has_version" "yes" "new version heading '[0.1.1] - $today' present"

  # The old Unreleased body ('- Added initial feature') should now live under 0.1.1.
  local body_under_new_version
  body_under_new_version=$(awk "
    /^## \\[0.1.1\\]/ { flag=1; next }
    /^## \\[/ { flag=0 }
    flag && /Added initial feature/ { found=1 }
    END { print (found ? \"yes\" : \"no\") }
  " plugins/foo/CHANGELOG.md)
  assert_eq "$body_under_new_version" "yes" "old Unreleased body moved under new version"

  teardown_fixture
}

test_creates_release_commit() {
  CURRENT_TEST="creates_release_commit"
  setup_fixture
  bash "$RELEASE_SCRIPT" foo patch > /dev/null 2>&1 || true
  local subject
  subject=$(git log -1 --pretty=%s)
  assert_eq "$subject" "release(foo): v0.1.1" "release commit subject"
  teardown_fixture
}

test_creates_tag() {
  CURRENT_TEST="creates_tag"
  setup_fixture
  bash "$RELEASE_SCRIPT" foo patch > /dev/null 2>&1 || true
  local tag
  tag=$(git tag -l 'foo/v0.1.1')
  assert_eq "$tag" "foo/v0.1.1" "tag foo/v0.1.1 exists"
  teardown_fixture
}

# --- runner ----------------------------------------------------------------

test_missing_args_fails
test_invalid_bump_type_fails
test_missing_plugin_fails
test_dirty_tree_fails
test_missing_unreleased_section_fails
test_empty_unreleased_section_fails
test_patch_bump_updates_jsons
test_minor_bump_updates_jsons
test_major_bump_updates_jsons
test_changelog_rewrite
test_creates_release_commit
test_creates_tag

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
