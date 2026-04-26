#!/usr/bin/env bash
# Integration tests for plugins/docs-curator/hooks/stop-gate.sh.
# Each test creates an isolated temp-dir git repo and runs the hook.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_SCRIPT="$PLUGIN_DIR/hooks/stop-gate.sh"

PASS=0
FAIL=0
CURRENT_TEST=""

assert_silent() {
  local output="$1" code="$2"
  if [ -z "$output" ] && [ "$code" -eq 0 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "  FAIL [$CURRENT_TEST]: expected silent exit 0"
    echo "    output: $output"
    echo "    code:   $code"
  fi
}

assert_emits_reminder() {
  local output="$1" code="$2"
  if [[ "$output" == *"<system-reminder>"* ]] && [[ "$output" == *"docs-curator"* ]] && [ "$code" -eq 0 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "  FAIL [$CURRENT_TEST]: expected system-reminder emission"
    echo "    output: $output"
    echo "    code:   $code"
  fi
}

setup_fixture() {
  FIXTURE_DIR=$(mktemp -d)
  cd "$FIXTURE_DIR"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test User"
  mkdir -p .claude
  echo "# README" > README.md
  echo "src content" > main.go
  git add -A
  git commit -qm "init"
}

teardown_fixture() {
  cd /
  rm -rf "$FIXTURE_DIR"
}

write_state() {
  # write a state file with given hash and head
  local hash="$1" head="$2"
  cat > .claude/docs-state.json <<JSON
{
  "version": 1,
  "project_type": "generic",
  "last_audit_at": "2026-04-26T00:00:00Z",
  "last_audit_state_hash": "$hash",
  "last_audit_head": "$head",
  "baseline_set": true,
  "memory": {"specific": [], "pattern": [], "rule_disabled": []},
  "pending_consolidations": []
}
JSON
}

# --- tests -----------------------------------------------------------------

test_first_run_emits_reminder() {
  CURRENT_TEST="first_run_emits_reminder"
  setup_fixture
  # No state file → first run
  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_emits_reminder "$output" "$code"
  teardown_fixture
}

test_silent_when_state_hash_matches() {
  CURRENT_TEST="silent_when_state_hash_matches"
  setup_fixture
  # Compute current hash and write to state. The hook should detect a match.
  local head
  head=$(git rev-parse HEAD)
  local current_hash
  current_hash=$(printf '%s\n%s\n' "$(git status -s)" "$head" | shasum -a 256 | awk '{print $1}')
  write_state "$current_hash" "$head"
  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_silent "$output" "$code"
  teardown_fixture
}

test_emits_when_md_added() {
  CURRENT_TEST="emits_when_md_added"
  setup_fixture
  local head
  head=$(git rev-parse HEAD)
  local clean_hash
  clean_hash=$(printf '%s\n%s\n' "$(git status -s)" "$head" | shasum -a 256 | awk '{print $1}')
  write_state "$clean_hash" "$head"
  # Add a new md file (working tree change)
  echo "# notes" > NOTES.md
  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_emits_reminder "$output" "$code"
  teardown_fixture
}

test_emits_when_md_modified() {
  CURRENT_TEST="emits_when_md_modified"
  setup_fixture
  local head
  head=$(git rev-parse HEAD)
  local clean_hash
  clean_hash=$(printf '%s\n%s\n' "$(git status -s)" "$head" | shasum -a 256 | awk '{print $1}')
  write_state "$clean_hash" "$head"
  echo "# README updated" > README.md
  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_emits_reminder "$output" "$code"
  teardown_fixture
}

test_silent_when_only_sanctioned_folders_changed() {
  CURRENT_TEST="silent_when_only_sanctioned_folders_changed"
  setup_fixture
  local head
  head=$(git rev-parse HEAD)
  local clean_hash
  clean_hash=$(printf '%s\n%s\n' "$(git status -s)" "$head" | shasum -a 256 | awk '{print $1}')
  write_state "$clean_hash" "$head"
  mkdir -p .github
  echo "x" > .github/foo.md
  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_silent "$output" "$code"
  teardown_fixture
}

test_emits_when_head_advanced_with_code_change() {
  CURRENT_TEST="emits_when_head_advanced_with_code_change"
  setup_fixture
  local old_head
  old_head=$(git rev-parse HEAD)
  local clean_hash
  clean_hash=$(printf '%s\n%s\n' "$(git status -s)" "$old_head" | shasum -a 256 | awk '{print $1}')
  write_state "$clean_hash" "$old_head"
  # Advance HEAD with a code change but no doc change
  echo "more code" >> main.go
  git add main.go
  git commit -qm "advance code"
  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_emits_reminder "$output" "$code"
  teardown_fixture
}

test_silent_when_not_in_git_repo() {
  CURRENT_TEST="silent_when_not_in_git_repo"
  FIXTURE_DIR=$(mktemp -d)
  cd "$FIXTURE_DIR"
  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_silent "$output" "$code"
  cd /
  rm -rf "$FIXTURE_DIR"
}

test_emits_via_new_folder_no_readme_root() {
  # Exercises trigger (c): a new folder with 3+ source files when no README exists
  # at any level above. Custom fixture omits the root README so (c) can fire, and
  # includes a doc change so trigger (b) is bypassed before (c) is reached.
  CURRENT_TEST="emits_via_new_folder_no_readme_root"
  FIXTURE_DIR=$(mktemp -d)
  cd "$FIXTURE_DIR"
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test User"
  mkdir -p .claude
  echo "main code" > main.go
  git add -A
  git commit -qm "init"

  local old_head
  old_head=$(git rev-parse HEAD)
  local clean_hash
  clean_hash=$(printf '%s\n%s\n' "$(git status -s)" "$old_head" | shasum -a 256 | awk '{print $1}')
  write_state "$clean_hash" "$old_head"

  mkdir -p src/lib docs
  echo "a" > src/lib/a.go
  echo "b" > src/lib/b.go
  echo "c" > src/lib/c.go
  echo "doc" > docs/intro.md
  git add -A
  git commit -qm "add src/lib + docs/intro"

  local output code
  output=$(bash "$HOOK_SCRIPT" 2>&1) || true
  code=$?
  assert_emits_reminder "$output" "$code"
  # Defensive: catch shell error pollution (e.g., bash 3.2 hitting `declare -A`).
  if [[ "$output" == *"declare:"* ]] || [[ "$output" == *"invalid option"* ]]; then
    FAIL=$((FAIL+1))
    echo "  FAIL [$CURRENT_TEST]: output contains shell error noise"
    echo "    output: $output"
  fi
  cd /
  rm -rf "$FIXTURE_DIR"
}

# --- runner ---------------------------------------------------------------

run() {
  test_first_run_emits_reminder
  test_silent_when_state_hash_matches
  test_emits_when_md_added
  test_emits_when_md_modified
  test_silent_when_only_sanctioned_folders_changed
  test_emits_when_head_advanced_with_code_change
  test_silent_when_not_in_git_repo
  test_emits_via_new_folder_no_readme_root
}

run

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
[ "$FAIL" -eq 0 ]
