# docs-curator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that audits, reorganizes, freshens, and generates project documentation via a Stop hook + skill + slash command.

**Architecture:** Three-piece plugin (hook for deterministic trigger, skill for intelligent audit, slash command for manual run). Hook auto-registers via `hooks/hooks.json`. All actions require explicit user approval; "engelleme" is reactive (audit catches bad docs within seconds of creation).

**Tech Stack:** Bash 3.2+ (hook + tests), JSON (state + manifests), Markdown (skill + commands + docs). No external dependencies beyond `git` and `jq` (already required by repo).

**Spec:** [docs/superpowers/specs/2026-04-26-docs-curator-design.md](../specs/2026-04-26-docs-curator-design.md)

---

## File Structure

Files to create (under `plugins/docs-curator/`):

```
.claude-plugin/plugin.json                  # plugin manifest
README.md                                   # user-facing intro
CHANGELOG.md                                # keep-a-changelog, [Unreleased] populated
hooks/
  hooks.json                                # Stop hook registration
  stop-gate.sh                              # the gate script
skills/docs-curator/
  SKILL.md                                  # 8-step audit flow
  references/
    default-policy.md                       # immutable rule set
    findings-format.md                      # report template
    risk-tiers.md                           # action → risk mapping
    type-rules.md                           # README/CHANGELOG/ADR/spec rules
    project-types.md                        # detection + per-type expectations
    generation.md                           # generation triggers
    first-run.md                            # baseline behavior
  templates/
    docs-policy.md.tmpl                     # user override template
    docs-state.json.tmpl                    # state file template
commands/docs-curator.md                    # slash command + subcommands
tests/
  test-stop-gate.sh                         # bash integration tests
```

Files to modify:

- `.claude-plugin/marketplace.json` — register new plugin
- `README.md` (root) — document new plugin

---

## Task 1: Scaffold plugin layout + manifest

**Files:**
- Create: `plugins/docs-curator/.claude-plugin/plugin.json`
- Create: `plugins/docs-curator/CHANGELOG.md`
- Create: `plugins/docs-curator/README.md` (placeholder; final content in Task 17)

- [ ] **Step 1: Create plugin directory tree**

```bash
mkdir -p plugins/docs-curator/.claude-plugin
mkdir -p plugins/docs-curator/hooks
mkdir -p plugins/docs-curator/skills/docs-curator/references
mkdir -p plugins/docs-curator/skills/docs-curator/templates
mkdir -p plugins/docs-curator/commands
mkdir -p plugins/docs-curator/tests
```

- [ ] **Step 2: Write plugin.json**

Path: `plugins/docs-curator/.claude-plugin/plugin.json`

```json
{
  "name": "docs-curator",
  "version": "0.1.0",
  "description": "Audit, reorganize, freshen, and generate project documentation. Triggers on Stop with a smart gate; manual /docs-curator command also available.",
  "author": {
    "name": "Ozan Öke"
  },
  "license": "MIT"
}
```

- [ ] **Step 3: Write CHANGELOG.md with populated [Unreleased]**

Path: `plugins/docs-curator/CHANGELOG.md`

```markdown
# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Initial release: Stop hook + skill + slash command for documentation curation.
- Detects non-standard, duplicate, stale docs across project type (Claude marketplace/plugin, Node, Python, Rust, Go, generic).
- Generates README/ADR drafts when code exists but docs do not.
- 3-tier user memory (specific path / glob pattern / disabled rule) prevents repeated nagging.
- First-run baseline mode prevents flag flood in messy projects.
- Manual `/docs-curator` command with subcommands: `full`, `init`, `state`, `reset`.
```

- [ ] **Step 4: Write placeholder README.md**

Path: `plugins/docs-curator/README.md`

```markdown
# docs-curator

Documentation curator plugin for the `wundam-skills` marketplace. Final README written in Task 17.
```

- [ ] **Step 5: Verify directory structure**

Run: `find plugins/docs-curator -type d | sort`

Expected output:
```
plugins/docs-curator
plugins/docs-curator/.claude-plugin
plugins/docs-curator/commands
plugins/docs-curator/hooks
plugins/docs-curator/skills
plugins/docs-curator/skills/docs-curator
plugins/docs-curator/skills/docs-curator/references
plugins/docs-curator/skills/docs-curator/templates
plugins/docs-curator/tests
```

- [ ] **Step 6: Commit**

```bash
git add plugins/docs-curator/
git commit -m "feat(docs-curator): scaffold plugin layout"
```

---

## Task 2: Write default policy reference

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/references/default-policy.md`

This is the immutable rule set the skill loads when no `.claude/docs-policy.md` override exists.

- [ ] **Step 1: Write default-policy.md**

Path: `plugins/docs-curator/skills/docs-curator/references/default-policy.md`

```markdown
# Default Policy

This file is the source of truth for `docs-curator` rules when no project override exists. The skill loads this file at start, then merges any `.claude/docs-policy.md` override on top.

## Allowed root files (whitelist)

These markdown files are accepted at the project root with no flag:

- `README.md`
- `LICENSE`, `LICENSE.md`, `LICENSE.txt`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `AUTHORS.md`, `MAINTAINERS.md`, `GOVERNANCE.md`
- `ROADMAP.md`
- `ARCHITECTURE.md`
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`

## Sanctioned folders

These folders are recognized; their contents may be audited but their existence is never flagged:

- `docs/` — long-form documentation
- `docs/adr/`, `docs/decisions/` — Architecture Decision Records (append-only; old entries never edited)
- `docs/specs/`, `docs/plans/` — design specs and implementation plans
- `docs/superpowers/specs/`, `docs/superpowers/plans/` — superpowers ecosystem convention
- `docs/api/` — code-derived API documentation
- `docs/guides/`, `docs/tutorials/` — long-form guides

## Fully ignored folders

Skipped entirely; never audited:

- `.claude/`
- `.github/`
- `.cursor/`
- `node_modules/`
- `vendor/`

## Strict blacklist (always flag)

Filename stems (case-insensitive) at any level outside sanctioned folders:

- `NOTES`
- `TODO`
- `IDEAS`
- `SCRATCH`
- `DRAFT`
- `REVIEW`
- `ANALYSIS`
- `REPORT`
- `PLAN`
- `THOUGHTS`
- `RESEARCH`
- `MEMO`
- `WORKLOG`
- `LOG`

Glob patterns:

- `*-notes.md`
- `*-todo.md`
- `*-scratch.md`

## Rules (toggleable via policy override)

Each rule has an internal name. Users can disable individual rules via `disabled_rules` in `.claude/docs-policy.md`.

| Rule name | Description |
|---|---|
| `root_blacklist` | Strict blacklist matches at root |
| `ad_hoc_subfolder_readme` | README in trivial subfolder (no sibling sources, or <3 source files) |
| `multi_readme_same_level` | Multiple README files in the same directory |
| `duplicate_content` | Two or more docs explain the same topic from scratch |
| `stale_code_reference` | Doc references symbols/paths that no longer exist |
| `stale_untouched_doc` | Code in last 10 commits changed; nearby doc untouched |
| `missing_required_for_type` | Project-type expectation (e.g., plugin missing CHANGELOG) |
| `generation_candidate` | New folder/feature with code but no doc |

## Stale window

Default: last 10 commits. Override via `.claude/docs-policy.md`:

```
## stale_window
20
```
```

- [ ] **Step 2: Verify file**

Run: `wc -l plugins/docs-curator/skills/docs-curator/references/default-policy.md`

Expected: ~80 lines.

- [ ] **Step 3: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/references/default-policy.md
git commit -m "feat(docs-curator): write default policy reference"
```

---

## Task 3: Write state and policy templates

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/templates/docs-state.json.tmpl`
- Create: `plugins/docs-curator/skills/docs-curator/templates/docs-policy.md.tmpl`

- [ ] **Step 1: Write state template**

Path: `plugins/docs-curator/skills/docs-curator/templates/docs-state.json.tmpl`

```json
{
  "version": 1,
  "project_type": null,
  "last_audit_at": null,
  "last_audit_state_hash": null,
  "last_audit_head": null,
  "baseline_set": false,
  "memory": {
    "specific": [],
    "pattern": [],
    "rule_disabled": []
  },
  "pending_consolidations": []
}
```

- [ ] **Step 2: Verify template parses as JSON**

Run: `jq . plugins/docs-curator/skills/docs-curator/templates/docs-state.json.tmpl`

Expected: pretty-printed JSON output, no parse error.

- [ ] **Step 3: Write policy override template**

Path: `plugins/docs-curator/skills/docs-curator/templates/docs-policy.md.tmpl`

```markdown
# docs-curator policy override

This file overrides the default rules from `docs-curator`. Only sections present here are merged; missing sections inherit defaults. Lists are additive (extend defaults), except `disabled_rules` which removes rules.

## allowed_root_files

Add custom files allowed at the project root (in addition to defaults):

- HACKING.md

## sanctioned_folders

Add custom sanctioned folders (in addition to defaults):

- docs/research/

## blacklist_additions

Add stems to the strict blacklist:

- WORKLOG

## disabled_rules

Disable specific rules. Valid names: root_blacklist, ad_hoc_subfolder_readme, multi_readme_same_level, duplicate_content, stale_code_reference, stale_untouched_doc, missing_required_for_type, generation_candidate.

- ad_hoc_subfolder_readme

## stale_window

Override the default 10-commit window:

20
```

- [ ] **Step 4: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/templates/
git commit -m "feat(docs-curator): add state and policy override templates"
```

---

## Task 4: Write tests for stop-gate.sh

**Files:**
- Create: `plugins/docs-curator/tests/test-stop-gate.sh`

We write tests **before** the implementation (TDD). Tests will fail at this step (script doesn't exist yet); we run them in Task 5 step 1 to confirm failure, then implement in Task 5 step 2.

- [ ] **Step 1: Write the test script**

Path: `plugins/docs-curator/tests/test-stop-gate.sh`

```bash
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

# --- runner ---------------------------------------------------------------

run() {
  test_first_run_emits_reminder
  test_silent_when_state_hash_matches
  test_emits_when_md_added
  test_emits_when_md_modified
  test_silent_when_only_sanctioned_folders_changed
  test_emits_when_head_advanced_with_code_change
  test_silent_when_not_in_git_repo
}

run

echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Make test script executable**

```bash
chmod +x plugins/docs-curator/tests/test-stop-gate.sh
```

- [ ] **Step 3: Commit (test-only commit; implementation comes next)**

```bash
git add plugins/docs-curator/tests/test-stop-gate.sh
git commit -m "test(docs-curator): add tests for stop-gate hook"
```

---

## Task 5: Implement stop-gate.sh

**Files:**
- Create: `plugins/docs-curator/hooks/stop-gate.sh`

- [ ] **Step 1: Run tests to verify they fail (no script yet)**

Run: `bash plugins/docs-curator/tests/test-stop-gate.sh`

Expected: All 7 tests FAIL because `stop-gate.sh` doesn't exist (script not found error).

- [ ] **Step 2: Write the hook script**

Path: `plugins/docs-curator/hooks/stop-gate.sh`

```bash
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
```

- [ ] **Step 3: Make hook executable**

```bash
chmod +x plugins/docs-curator/hooks/stop-gate.sh
```

- [ ] **Step 4: Run shellcheck**

Run: `shellcheck plugins/docs-curator/hooks/stop-gate.sh`

Expected: No errors. Warnings are OK if they are not actionable; fix any error or `error`-level warning.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash plugins/docs-curator/tests/test-stop-gate.sh`

Expected output (last lines):
```
Passed: 7
Failed: 0
```

If any test fails, debug stop-gate.sh; do not move on until all 7 pass.

- [ ] **Step 6: Commit**

```bash
git add plugins/docs-curator/hooks/stop-gate.sh
git commit -m "feat(docs-curator): implement stop-gate hook script"
```

---

## Task 6: Register Stop hook via hooks.json

**Files:**
- Create: `plugins/docs-curator/hooks/hooks.json`

Per CONTRIBUTING.md, plugins register hooks via `hooks/hooks.json`.

- [ ] **Step 1: Write hooks.json**

Path: `plugins/docs-curator/hooks/hooks.json`

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-gate.sh"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

Run: `jq . plugins/docs-curator/hooks/hooks.json`

Expected: pretty-printed JSON, no parse error.

- [ ] **Step 3: Commit**

```bash
git add plugins/docs-curator/hooks/hooks.json
git commit -m "feat(docs-curator): register Stop hook via hooks.json"
```

---

## Task 7: Write SKILL.md (8-step audit flow)

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/SKILL.md`

This is the primary skill file. The model loads it on invocation.

- [ ] **Step 1: Write SKILL.md**

Path: `plugins/docs-curator/skills/docs-curator/SKILL.md`

```markdown
---
name: docs-curator
description: Audit, reorganize, freshen, and generate project documentation. Detects non-standard files, duplicates, stale references, and missing docs across project type. All actions require explicit user approval. Use when the Stop hook reminds you, when the user runs /docs-curator, or when the user asks to clean up / consolidate / generate docs.
---

# docs-curator

You are running the `docs-curator` skill. Your job is to audit the project's documentation and propose actions, never destructively. The user approves every action.

## Setup

Read these references before acting:

- `references/default-policy.md` — the rule set (whitelist, sanctioned folders, blacklist, rules)
- `references/findings-format.md` — how to format the report
- `references/risk-tiers.md` — action → risk mapping
- `references/type-rules.md` — per-doc-type behavior (README/CHANGELOG/ADR/spec/api/guide)
- `references/project-types.md` — project-type detection and per-type expectations
- `references/generation.md` — when and how to generate doc drafts
- `references/first-run.md` — baseline behavior on first audit

State and policy live in the project being audited:

- `.claude/docs-state.json` — state file (committed; shared across team)
- `.claude/docs-policy.md` — optional user override

If a subcommand is provided (`full`, `init`, `state`, `reset`), see "Subcommand handling" below.

## The 8-step flow

Execute these steps in order. Do not skip steps.

### Step 1: Load policy and state

1. Read `.claude/docs-policy.md` if present. Otherwise use defaults from `references/default-policy.md`.
2. Read `.claude/docs-state.json` if present. If missing, initialize from `templates/docs-state.json.tmpl`.
3. Merge: project override extends defaults; `disabled_rules` removes default rules; `blacklist_additions` extends the blacklist; `stale_window` overrides the default 10-commit window.

### Step 2: Determine scope

- If `state.baseline_set` is `false` → **first-run mode** (see `references/first-run.md`).
- If subcommand is `full` → **full re-audit mode** (ignore baseline; consider every file).
- Otherwise → **incremental mode** (only files changed since `state.last_audit_head`, plus working-tree changes).

### Step 3: Detect project type

Check for these marker files in order; first hit wins:

| Marker | Type |
|---|---|
| `.claude-plugin/marketplace.json` | claude-marketplace |
| `.claude-plugin/plugin.json` | claude-plugin |
| `package.json` | node |
| `pyproject.toml` or `setup.py` | python |
| `Cargo.toml` | rust |
| `go.mod` | go |
| (none) | generic |

Apply expectations from `references/project-types.md`.

### Step 4: Inventory

1. List markdown files: `git ls-files '*.md' '*.MD'` plus working-tree additions from `git status -s`.
2. Skip ignored folders: `.claude/`, `.github/`, `.cursor/`, `node_modules/`, `vendor/`.
3. For each file, classify:
   - **ALLOWED** — root file in whitelist, or file in sanctioned folder
   - **FLAGGED** — root non-whitelist, or matches blacklist anywhere
   - **SANCTIONED** — inside `docs/`, `docs/adr/`, etc.

### Step 5: Build findings

Five categories. Apply only enabled rules (per merged policy).

#### Non-standard
For each FLAGGED file, record reason: `root_blacklist`, `ad_hoc_subfolder_readme`, or `multi_readme_same_level`.

#### Duplicate
Compare doc bodies pairwise. A duplicate is when two docs explain the same topic from scratch (significant content overlap, not just shared title). This requires reading the docs — use your judgment.

#### Stale
Two sub-detections:

1. **Code reference rot:** For each doc, extract referenced symbols (function names, file paths, class names). Verify each via grep / file-check on the current codebase. **Never flag based on memory alone — always grep first.**
2. **Code-doc skew:** Use `git log -<stale_window>` to find files changed in the last N commits. For each changed code file, find associated docs (same module, README in same folder, mention in any doc). If code changed but no doc was touched in the same window, flag.

#### Missing standard
Per detected project type (see `references/project-types.md`). Examples:
- `claude-marketplace`: each `plugins/<X>/` should have README and CHANGELOG.
- `claude-plugin`: should have README, CHANGELOG, and at least one skill.
- `node`: should have README and LICENSE.

#### Generation candidate
See `references/generation.md`. Triggers:
- New folder with ≥3 source files, no README at any level above.
- Last N commits have significant architectural change (modules added/renamed/deleted), no ADR added.
- Plugin/package missing README or CHANGELOG.

### Step 6: Filter by memory

Drop findings whose path matches `state.memory.specific` (exact) or `state.memory.pattern` (glob). Drop findings whose rule is in `state.memory.rule_disabled`.

### Step 7: Present report and get approval

Format report per `references/findings-format.md`. Group by category. Tag each proposed action with risk tier per `references/risk-tiers.md`.

Approval options:
- `all` — apply all approved (low batch immediately; mid/high still show diff/plan per item)
- `low` — apply only low batch
- `1,3,4,7` — apply specific items (read by index)
- `skip` — apply nothing; add findings to memory as accepted-as-is
- `cancel` — do nothing; re-prompt next audit

After 3+ "skip" decisions on the same pattern (e.g., same filename pattern flagged repeatedly), propose:

> "You've skipped `<pattern>`-type findings 3 times. Suppress this pattern globally? (y/n)"

If yes, add the pattern to `state.memory.pattern`.

### Step 8: Apply actions and update state

For each approved action:

1. Execute the file operation (move/rename/delete/edit/write per `references/risk-tiers.md`).
2. `git add <changed paths>` so the user sees a clean staging diff.
3. **Mid/High actions:** show the diff/plan, get explicit confirmation, then apply.

After all actions:

1. Compute new `last_audit_state_hash` from current `git status -s` and HEAD.
2. Update `last_audit_at` (ISO-8601 UTC), `last_audit_head` (current HEAD oid).
3. Move skipped findings to `memory.specific`. Detect repeated patterns; if any pattern has ≥3 entries in `memory.specific`, propose pattern suppression.
4. If first run, set `baseline_set: true` and inform the user.
5. Write `.claude/docs-state.json`.
6. **Do not commit** the state file in this run; let the user commit when ready.

## Subcommand handling

- `full` — Skip first-run-mode shortcut. Ignore baseline. Audit every file.
- `init` — Copy `templates/docs-policy.md.tmpl` to `.claude/docs-policy.md` if missing. Do not run audit.
- `state` — Read and pretty-print `.claude/docs-state.json` (or report missing).
- `reset` — Delete `.claude/docs-state.json` and re-run audit from first-run mode.

## Critical rules

- **Never apply an action without explicit user approval.** Even low-risk batched actions are explicitly approved.
- **Never flag stale based on memory alone.** Always grep / file-check.
- **Never modify shipped specs or old ADRs.** They are append-only / immutable per `references/type-rules.md`.
- **Never delete a sanctioned folder's contents en masse.** Each file decided individually.
- **Never silent-overwrite generated content.** Generation is mid-risk with preview.
- **Never commit on the user's behalf.** Stage with `git add`; let them commit.
```

- [ ] **Step 2: Verify SKILL.md frontmatter parses**

Run:
```bash
head -5 plugins/docs-curator/skills/docs-curator/SKILL.md
```

Expected: starts with `---`, has `name:` and `description:` fields, ends with `---`.

- [ ] **Step 3: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/SKILL.md
git commit -m "feat(docs-curator): write SKILL.md with 8-step audit flow"
```

---

## Task 8: Write findings-format reference

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/references/findings-format.md`

- [ ] **Step 1: Write the reference**

Path: `plugins/docs-curator/skills/docs-curator/references/findings-format.md`

```markdown
# Findings Report Format

Render the audit report in this exact structure. Always present numbered items so the user can refer to them as `1,3,4`.

## Template

```
## Audit Findings — <project_type>, <mode>

### Non-standard files (<count>)
1. <path> — <reason>
2. ...

### Duplicates (<count>)
3. <path-a> + <path-b> — <description of overlap>

### Stale (<count>)
4. <path> — <stale reason: dead reference / code-doc skew>

### Missing standard (<count>)
5. <path or expectation> — <what's missing>

### Generation candidates (<count>)
6. <path> — <why a doc would help>

### Proposed actions
[low]   1, 2: <action: e.g., delete>
[low]   3:    stub <path-a>, point to <path-b>
[mid]   4:    rewrite <path> (diff to follow)
[low]   5:    create <path> from template
[mid]   6:    generate <path> (preview to follow)

Approve?
  → "all" (apply all; mid/high still show diff/plan)
  → "low" (apply only low batch)
  → "1,3,5" (specific items)
  → "skip" (apply nothing; mark as accepted-as-is)
  → "cancel" (do nothing; re-prompt next audit)
```

## Rules

- Empty categories: omit the section entirely (don't show `Non-standard files (0)`).
- Always show item indices globally — `1, 2, 3` across all categories — so user can pick by number.
- Action tags: `[low]`, `[mid]`, `[high]` per `risk-tiers.md`.
- For mid/high: do not show the diff/plan in the report itself; promise it ("diff to follow") and present per-item during apply.
- After listing actions, always show the approval menu verbatim.

## Approval handling

- `all` → apply all listed actions; for mid/high, prompt with diff/plan one at a time.
- `low` → apply only the `[low]`-tagged batch.
- Specific list (e.g., `1,3,5`) → apply those item indices; for mid/high among them, diff per item.
- `skip` → apply nothing, but add each finding's path to `state.memory.specific` so it isn't re-flagged.
- `cancel` → apply nothing, do not update memory; re-prompt next audit.

If the user gives an unexpected response, ask once: "Sorry, I didn't understand. Please reply with one of: all / low / numbered list / skip / cancel."
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/references/findings-format.md
git commit -m "feat(docs-curator): add findings-format reference"
```

---

## Task 9: Write risk-tiers reference

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/references/risk-tiers.md`

- [ ] **Step 1: Write the reference**

Path: `plugins/docs-curator/skills/docs-curator/references/risk-tiers.md`

```markdown
# Risk Tiers and Actions

Every proposed action is tagged with a risk tier. The tier determines the approval flow.

## Action vocabulary

| Action | Description | Default tier |
|---|---|---|
| `move` | Move file to canonical location | low |
| `rename` | Rename to standard pattern | low |
| `delete` | Remove transient/duplicate/empty file | low |
| `route-to-gitignore` | Move into `.claude/scratch/` (gitignored) | low |
| `stub` | Replace duplicate content with pointer to canonical doc | low |
| `merge` | Combine two docs into one | mid |
| `generate` | Create new doc from code analysis | mid |
| `consolidate` | Combine N docs into single canonical | high |

## Tier semantics

### low — batch approval

The user can approve all `[low]` actions in one go (`all` or `low`). Each is independently safe:

- File operations (move/rename/delete) are git-reversible.
- Stub action replaces content but is bounded to one file.
- `route-to-gitignore` requires `.claude/scratch/` to exist and to be in `.gitignore`. If the project's `.gitignore` does not include `.claude/scratch/`, propose adding it as a separate low action and depend on its approval first.

### mid — per-item diff approval

Each `[mid]` action is presented one at a time:

1. Show full file diff (or full new file content for generate).
2. Ask: "Apply this? (y/n/skip)".
3. Apply on `y`, leave alone on `n` (don't add to memory, may re-prompt later), add to memory on `skip`.

### high — per-item plan approval

Each `[high]` action is presented one at a time:

1. Show a numbered plan of the file operations involved (which files merged/moved/deleted, in what order).
2. Show the resulting canonical file's content.
3. Ask: "Apply this plan? (y/n/skip)".
4. Same outcome rules as mid.

## When to escalate tier

The default tier per action is the starting point. Escalate to a higher tier when:

- A `delete` would remove a file with substantial content (>50 lines) that the user might still want — escalate to `mid`, show the file content first.
- A `merge` would combine docs from different doc types (README + ADR) — escalate to `high`, this is structural.
- A `generate` would create a file in a sanctioned folder where one already exists nearby — verify the existing one isn't sufficient first.

## When to de-escalate

Never. If unsure, stay at the higher tier.

## Per-doc-type overrides

Some doc types have hard rules (see `type-rules.md`):

- ADR / shipped spec → never `merge`, never `delete`, never `consolidate`. Only `move`-as-archive is allowed (also low).
- CHANGELOG → never edit old released entries. Only edit `[Unreleased]` section.

If a proposed action conflicts with a per-doc-type rule, drop the action (don't propose it).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/references/risk-tiers.md
git commit -m "feat(docs-curator): add risk-tiers reference"
```

---

## Task 10: Write type-rules reference

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/references/type-rules.md`

- [ ] **Step 1: Write the reference**

Path: `plugins/docs-curator/skills/docs-curator/references/type-rules.md`

```markdown
# Doc Type Rules

Different doc types follow different conventions. Detect the type before proposing actions.

## Detection

| Doc type | Detection rule (first match wins) |
|---|---|
| README | Filename matches `README` (case-insensitive) at any level |
| CHANGELOG | Filename matches `CHANGELOG` (case-insensitive) |
| ADR | File is in `docs/adr/`, `docs/decisions/`, or matches `*-adr.md` |
| Spec | File is in `docs/specs/`, `docs/superpowers/specs/`, or matches `*-design.md` |
| Plan | File is in `docs/plans/`, `docs/superpowers/plans/` |
| API doc | File is in `docs/api/`, `api/docs/`, or matches `*-api.md` |
| Guide | File is in `docs/guides/`, `docs/tutorials/` |
| Other | Anything else under `docs/` |

## Per-type policies

### README

- User-facing — any edit is at least `mid` risk.
- Stale detection should run aggressively: outdated quickstart is a top complaint.
- Never delete a README without explicit confirmation, even if it appears empty (might be intentional placeholder).

### CHANGELOG

- Format follows [Keep a Changelog](https://keepachangelog.com/) — assume this even if not declared.
- **Released entries are immutable.** Never edit any version section that has a date.
- Only the `[Unreleased]` section is editable. Stale detection only applies to `[Unreleased]`.
- A missing CHANGELOG in a versioned project (has `version` field in any manifest) is a `missing_required_for_type` finding.

### ADR (Architecture Decision Records)

- **Append-only history.** Never `merge`, `delete`, or `consolidate` an ADR.
- Move-as-archive (e.g., to `docs/adr/superseded/`) is allowed when an ADR is explicitly superseded by a newer one — but only with user direction; do not propose this proactively.
- Numbering convention: ADRs typically named `NNNN-title.md`. Detect gaps (missing numbers) and report as informational, but never auto-renumber.

### Spec / Plan

- **Date-bound.** Filename `YYYY-MM-DD-<topic>-design.md` or similar.
- After the corresponding feature ships, propose `move` to `docs/specs/shipped/` (low) or `move` to `docs/specs/archive/<year>/` (low). Do not delete.
- `merge` between specs is forbidden — each spec is a historical record of a single design discussion.
- Stale detection applies but with a longer window (e.g., 30 commits) since specs are forward-looking.

### API doc

- Often code-derived. If the project has a doc generator (mkdocs, sphinx, jsdoc, rustdoc), `generate`/regenerate is preferred over manual edit.
- Stale code references are common but the fix is regeneration, not manual edit.
- Do not propose to delete API docs even if stale — the right action is `regenerate` (a mid-risk variant of `generate`).

### Guide

- Evergreen content; mid risk for any edit.
- Stale detection runs aggressively: outdated tutorials confuse users.
- `merge`/`consolidate` allowed when two guides cover the same path-of-learning.

### Other

- Default rules apply.

## Cross-type rules

- Never `merge` files of different types.
- Never `consolidate` across `docs/specs/` and `docs/adr/` — different purposes.
- A README at any level can `stub` to a deeper canonical doc, but a deeper doc cannot `stub` a README.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/references/type-rules.md
git commit -m "feat(docs-curator): add type-rules reference"
```

---

## Task 11: Write project-types reference

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/references/project-types.md`

- [ ] **Step 1: Write the reference**

Path: `plugins/docs-curator/skills/docs-curator/references/project-types.md`

```markdown
# Project Type Detection and Expectations

Detect once at audit start. Apply per-type expectations alongside generic rules.

## Detection order

Check marker files in order; first match wins. If no markers, type is `generic`.

| Order | Marker | Type |
|---|---|---|
| 1 | `.claude-plugin/marketplace.json` | claude-marketplace |
| 2 | `.claude-plugin/plugin.json` | claude-plugin |
| 3 | `package.json` | node |
| 4 | `pyproject.toml` | python |
| 5 | `setup.py` | python |
| 6 | `Cargo.toml` | rust |
| 7 | `go.mod` | go |
| 8 | (none) | generic |

## Per-type expectations

These add `missing_required_for_type` findings when not satisfied.

### claude-marketplace

- Root: `README.md`, `CONTRIBUTING.md`, `LICENSE`.
- Each `plugins/<X>/` directory: `README.md` and `CHANGELOG.md`.
- Each `plugins/<X>/.claude-plugin/plugin.json`: must exist and parse as JSON.
- `plugins/<X>/CHANGELOG.md`: must have a `## [Unreleased]` section.

### claude-plugin

- Root of plugin: `README.md`, `CHANGELOG.md`.
- `.claude-plugin/plugin.json` must exist.
- At least one `skills/<X>/SKILL.md` OR `commands/<X>.md` OR `agents/<X>.md` OR `hooks/hooks.json` (a plugin should provide something).
- Every `skills/<X>/SKILL.md` must have YAML frontmatter with `name` and `description`.

### node

- Root: `README.md`, `LICENSE` (or `LICENSE.md`).
- `package.json`: ensure `description` field is non-empty (note: do not modify; just flag).
- If `package.json` declares `main` or `bin`, expect a usage section in README.

### python

- Root: `README.md`, `LICENSE`.
- If `pyproject.toml` has `[project]` table, expect description to be non-empty.

### rust

- Root: `README.md`, `LICENSE` (or LICENSE-MIT/LICENSE-APACHE for dual).
- `Cargo.toml`: `description` field non-empty.

### go

- Root: `README.md`, `LICENSE`.
- `go.mod` is canonical; no extra expectations.

### generic

- Root: `README.md`, `LICENSE` (suggested but not flagged as missing if absent).

## Project-type-aware rules

- `claude-marketplace` → expect `plugins/` directory; treat `plugins/<X>/` as a sub-project for `missing_required_for_type` checks.
- `claude-plugin` → treat `skills/<X>/SKILL.md` as a special doc type (must have frontmatter).
- All types → CHANGELOG keep-a-changelog format expected if a CHANGELOG exists.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/references/project-types.md
git commit -m "feat(docs-curator): add project-types reference"
```

---

## Task 12: Write generation reference

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/references/generation.md`

- [ ] **Step 1: Write the reference**

Path: `plugins/docs-curator/skills/docs-curator/references/generation.md`

```markdown
# Generation Triggers and Process

`generate` is a mid-risk action that proposes a new doc draft based on code analysis. Always with preview; never silent.

## When to generate

Three trigger types:

### Trigger 1: New folder without README

A folder added (working tree or recent commit window) that contains ≥3 source files, with no README at the folder itself or any ancestor up to the project root.

What to generate: `<folder>/README.md` with:
- 1-2 sentence purpose (inferred from code)
- File listing with one-line descriptions
- Usage example if entry points are detected

### Trigger 2: Architectural change without ADR

In the last N commits (default 10, configurable via `stale_window`), there's a "significant architectural change" — defined as any of:
- A top-level directory added or removed
- A directory renamed (≥3 files moved together)
- A module's exports changed substantially (signatures, removed public symbols)

If `docs/adr/` exists and no ADR was added in the same commit window, propose generating an ADR.

What to generate: `docs/adr/NNNN-<topic>.md` using a standard ADR template:
```
# ADR-NNNN: <Title>

## Status
Proposed

## Context
<Why this change was needed, inferred from code+commits>

## Decision
<What was changed>

## Consequences
<Trade-offs, inferred from the diff>
```

Determine the next number by reading existing ADRs (highest existing number + 1).

### Trigger 3: Plugin/package missing required doc

When project type detection (per `project-types.md`) flags a missing required file, propose generating it.

For `README.md`: minimal scaffold with project name, one-line description (inferred from code/manifests), install/usage if obvious.

For `CHANGELOG.md`: minimal scaffold with `## [Unreleased]` section only.

## Process

For each generation candidate:

1. Read the relevant source files (limit scope: only the candidate's directory and direct neighbors).
2. Draft the doc using your judgment.
3. Present the full content as a `[mid]` action: "generate <path> (preview to follow)".
4. When the user reaches this in the approval flow, show the full file content.
5. Ask: "Apply (y/n/skip)?".
6. On `y`, write the file with `Write` tool, `git add` it, do not commit.

## Limits

- Never generate more than 3 docs per audit run. If more candidates exist, generate the top 3 (by relevance) and report the rest as "deferred — re-run audit after these are accepted".
- Never generate inside `docs/adr/` more than 1 ADR per audit run — ADRs deserve human framing.
- Never generate a doc that would shadow an existing one (duplicate path).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/references/generation.md
git commit -m "feat(docs-curator): add generation reference"
```

---

## Task 13: Write first-run reference

**Files:**
- Create: `plugins/docs-curator/skills/docs-curator/references/first-run.md`

- [ ] **Step 1: Write the reference**

Path: `plugins/docs-curator/skills/docs-curator/references/first-run.md`

```markdown
# First-Run Behavior

When `state.baseline_set` is `false` (no state file or fresh `reset`), enter first-run mode. Goal: avoid overwhelming the user when installing into a messy project.

## Rules

1. Detect project type (per `project-types.md`).
2. Run full inventory (per Step 4 of `SKILL.md`).
3. Build findings as usual but emit only **critical** findings:
   - Files matching the strict blacklist (`NOTES.md`, `TODO.md`, `REVIEW.md`, etc.) at root
   - Multiple READMEs at the same level
   - Missing required files for the detected project type (e.g., plugin missing CHANGELOG)
4. **Suppress** these categories on first run:
   - Duplicate detection
   - Stale detection (both code-reference and code-doc skew)
   - Generation candidates
   - Ad-hoc subfolder README
5. Mark all currently-existing markdown files (except those flagged in step 3) as accepted-as-is by adding their paths to `memory.specific`.
6. Set `state.baseline_set = true`.
7. Inform the user:

```
docs-curator: Baseline established for this project.
- Project type: <type>
- Markdown files inventoried: <count>
- Accepted as-is (added to memory): <count>
- Critical findings to address now: <count>

For a deep audit at any time: /docs-curator full
```

## Why this design

A fresh install into a project with 50+ markdown files would otherwise produce a 30-finding flood. Most users would dismiss it and uninstall. Baseline mode means the user only sees clear violations on first run. They can opt into the full audit when they're ready.

## Future audits

After first run, all subsequent audits run incrementally (only changed files since `last_audit_head`). The baseline established on first run persists in `memory.specific` until the user runs `/docs-curator reset`.

## Edge cases

- **Empty project:** No markdown files; `state.baseline_set = true`, no findings, inform user.
- **Single file project:** Same flow; inventory is small but baseline mode still applies.
- **Reset:** `/docs-curator reset` deletes the state file and re-enters first-run mode. Memory is wiped along with state.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/skills/docs-curator/references/first-run.md
git commit -m "feat(docs-curator): add first-run reference"
```

---

## Task 14: Write slash command

**Files:**
- Create: `plugins/docs-curator/commands/docs-curator.md`

- [ ] **Step 1: Write the command**

Path: `plugins/docs-curator/commands/docs-curator.md`

```markdown
---
description: Run a documentation audit. Subcommands: full, init, state, reset.
argument-hint: [full|init|state|reset]
---

# /docs-curator

You are running the `docs-curator` slash command. Load the skill and execute it.

## Argument handling

The user may provide one of these subcommands as `$ARGUMENTS`:

- `(empty)` — run a standard audit (incremental mode, baseline-aware)
- `full` — full re-audit, ignore baseline
- `init` — copy `.claude/docs-policy.md` template if missing
- `state` — show current `.claude/docs-state.json` (or "not initialized")
- `reset` — delete state, re-run audit from first-run mode

## Steps

1. Use the Skill tool to invoke `docs-curator:docs-curator` with the subcommand passed in `$ARGUMENTS`.
2. The skill handles all behavior; this command is just the user-facing entry point.

If `$ARGUMENTS` contains anything not in the list above, tell the user the valid subcommands and stop.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/commands/docs-curator.md
git commit -m "feat(docs-curator): add /docs-curator slash command"
```

---

## Task 15: Write plugin README

**Files:**
- Modify: `plugins/docs-curator/README.md` (replace placeholder)

- [ ] **Step 1: Replace placeholder README**

Path: `plugins/docs-curator/README.md`

Replace the entire content with:

```markdown
# docs-curator

A documentation curator that audits, reorganizes, freshens, and generates project documentation.

`docs-curator` watches your project's docs and proposes targeted actions: prune non-standard files, reorganize duplicates, freshen stale references, and generate drafts where code exists but docs don't. **Every action is presented for approval; nothing destructive happens silently.**

## What it does

Four jobs:

1. **Prune** — flags non-standard files (`NOTES.md`, `TODO.md`, ad-hoc `*-scratch.md`, etc.) at root and outside sanctioned folders.
2. **Reorganize** — proposes `move`, `rename`, `merge`, or `stub` for duplicate or misplaced docs.
3. **Freshen** — detects docs that reference deleted code, or code that changed without doc updates.
4. **Generate** — proposes README/ADR drafts when new code exists without documentation.

It runs reactively (Stop hook with smart gate) and on demand (`/docs-curator`).

## How it triggers

- **Automatic:** A Stop hook fires after every model turn, but a cheap gate script silently exits unless something actually changed (no churn for unrelated work).
- **Manual:** `/docs-curator` runs the audit on demand.

The hook is registered automatically when the plugin is installed.

## Install

```
/plugin install docs-curator@wundam-skills
```

Reload Claude Code afterward to pick up the hook and skill.

## Commands

| Command | Purpose |
|---|---|
| `/docs-curator` | Standard audit (incremental; baseline-aware) |
| `/docs-curator full` | Full re-audit, ignore baseline |
| `/docs-curator init` | Copy policy override template to `.claude/docs-policy.md` |
| `/docs-curator state` | Show current `.claude/docs-state.json` |
| `/docs-curator reset` | Delete state and re-run from first-run mode |

## What gets created in your project

Two files are written to your project's `.claude/` directory:

- `.claude/docs-state.json` — audit state and memory (what's been accepted as-is, what patterns to suppress). **Commit this** to share baseline across your team.
- `.claude/docs-policy.md` (optional) — your policy override. Created on demand via `/docs-curator init`.

## Default policy

Out of the box, `docs-curator` enforces a sane default:

**Allowed at root:** `README.md`, `LICENSE*`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `AUTHORS.md`, `MAINTAINERS.md`, `GOVERNANCE.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`.

**Sanctioned folders** (audited but never flagged for existing): `docs/`, `docs/adr/`, `docs/decisions/`, `docs/specs/`, `docs/plans/`, `docs/superpowers/specs/`, `docs/superpowers/plans/`, `docs/api/`, `docs/guides/`, `docs/tutorials/`.

**Fully ignored** (never audited): `.claude/`, `.github/`, `.cursor/`, `node_modules/`, `vendor/`.

**Strict blacklist** (always flagged): `NOTES`, `TODO`, `IDEAS`, `SCRATCH`, `DRAFT`, `REVIEW`, `ANALYSIS`, `REPORT`, `PLAN`, `THOUGHTS`, `RESEARCH`, `MEMO`, `WORKLOG`, `LOG`.

## First-run mode

The first time you run `docs-curator` in a project, it does *not* flood you with findings. It establishes a baseline: only critical violations (strict blacklist matches at root, multi-README clashes, project-type required files missing) are reported. Everything else is accepted as-is. Run `/docs-curator full` when you're ready for a deep audit.

## Risk-tier approval

| Tier | Examples | Approval |
|---|---|---|
| `low` | move, rename, delete, stub, route-to-gitignore | Batch — approve all `[low]` at once |
| `mid` | merge, generate, rewrite | Per-item — diff/preview shown, individual approval |
| `high` | consolidate (N→1) | Per-item — full plan shown, individual approval |

Nothing is ever applied without explicit user approval. Even `all` walks through `mid`/`high` items individually with a diff or plan.

## Memory and learning

Three-tier memory prevents re-nagging:

- **Specific path** — exact file path is accepted as-is.
- **Pattern (glob)** — after 3 skips on the same pattern, the plugin asks if it should suppress the pattern.
- **Rule disabled** — entire rule category off (e.g., `ad_hoc_subfolder_readme`).

All memory is stored in `.claude/docs-state.json` and committed with your project, so the team shares the same baseline.

## Project type awareness

`docs-curator` detects your project type and applies type-specific expectations:

| Marker | Type | Expects |
|---|---|---|
| `.claude-plugin/marketplace.json` | claude-marketplace | Each `plugins/<X>/` has README + CHANGELOG |
| `.claude-plugin/plugin.json` | claude-plugin | README + CHANGELOG + at least one skill/command/agent/hook |
| `package.json` | node | README + LICENSE |
| `pyproject.toml` / `setup.py` | python | README + LICENSE |
| `Cargo.toml` | rust | README + LICENSE |
| `go.mod` | go | README + LICENSE |
| (none) | generic | README suggested |

## Doc type rules

Different doc types follow different conventions:

- `README` — user-facing; any edit is mid risk.
- `CHANGELOG` — released entries are immutable; only `[Unreleased]` editable.
- `ADR` — append-only; never merged or deleted.
- `Spec` / `Plan` — date-bound; archived after feature ships.
- `API doc` — code-derived; regenerate over manual edit.
- `Guide` / `Tutorial` — evergreen; mid risk for any edit.

## Customizing

Run `/docs-curator init` to create `.claude/docs-policy.md` with the override template. Edit it to extend the whitelist, add sanctioned folders, disable rules, or adjust the stale window.

## Out of scope (v1)

- Markdown content quality (typos, broken links, formatting) — use `markdownlint` separately.
- Real-time write blocking — `docs-curator` is reactive; the Stop hook catches new violations within seconds.
- Cross-project policy sharing — defer to v2.

## License

MIT — see [LICENSE](../../LICENSE).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/docs-curator/README.md
git commit -m "docs(docs-curator): write user-facing README"
```

---

## Task 16: Register plugin in marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add docs-curator entry**

Read the current file:

```bash
cat .claude-plugin/marketplace.json
```

Append a new plugin entry to the `plugins` array. The final file should be:

```json
{
  "name": "wundam-skills",
  "description": "Personal Claude Code plugin marketplace",
  "owner": {
    "name": "Ozan Öke",
    "url": "https://wundam.com"
  },
  "plugins": [
    {
      "name": "team-review",
      "source": "./plugins/team-review",
      "description": "Assemble a virtual cross-functional team to analyze a request, deep-dive the code, and produce a consensus solution plan.",
      "version": "1.0.0"
    },
    {
      "name": "docs-curator",
      "source": "./plugins/docs-curator",
      "description": "Audit, reorganize, freshen, and generate project documentation. Triggers on Stop with a smart gate; manual /docs-curator command also available.",
      "version": "0.1.0"
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

Run: `jq . .claude-plugin/marketplace.json`

Expected: pretty-printed JSON, no parse error. Verify both plugins are present.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore: register docs-curator in marketplace manifest"
```

---

## Task 17: Update root README with new plugin entry

**Files:**
- Modify: `README.md` (root)

- [ ] **Step 1: Read current root README**

```bash
cat README.md
```

- [ ] **Step 2: Add `docs-curator` section**

Insert a new section under `## Plugins`, after the `team-review` section. The new section:

```markdown
### `docs-curator` — v0.1.0

Audit, reorganize, freshen, and generate project documentation. A Stop hook with a smart gate fires only when relevant changes occur; a `/docs-curator` slash command runs audits on demand.

**What it does:**

- **Prune** non-standard files (e.g., `NOTES.md`, `TODO.md`, ad-hoc `*-scratch.md`)
- **Reorganize** duplicates and misplaced docs (move/rename/merge/stub)
- **Freshen** docs that reference deleted code or grew out of sync
- **Generate** README/ADR drafts when code exists without documentation

**Risk-tier approval — nothing applied without explicit approval:**

- `low` (move/rename/delete/stub) — batch approval
- `mid` (merge/generate/rewrite) — per-item diff/preview
- `high` (consolidate N→1) — per-item plan

**Project-type aware:** detects Claude marketplace, Claude plugin, Node, Python, Rust, Go, generic — applies type-specific expectations (e.g., each plugin in a marketplace must have README + CHANGELOG).

**Lifecycle commands:**

| Command | Purpose |
|---|---|
| `/docs-curator` | Standard audit |
| `/docs-curator full` | Full re-audit, ignore baseline |
| `/docs-curator init` | Copy policy override template |
| `/docs-curator state` | Show current state |
| `/docs-curator reset` | Reset baseline; re-run first-run mode |

**Install:**

```
/plugin install docs-curator@wundam-skills
```

Full docs: [`plugins/docs-curator/README.md`](plugins/docs-curator/README.md).
```

Use the `Edit` tool to insert this section between the existing `team-review` section and the `## How it's organized` heading.

- [ ] **Step 3: Verify edit**

Run: `grep -c '^### ' README.md`

Expected: `2` (two plugin sections).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add docs-curator entry to root README"
```

---

## Task 18: Dogfood — install marketplace locally and run audit

**Files:** none modified in this task; this is a manual verification step.

- [ ] **Step 1: Reload Claude Code session if needed**

The marketplace is already registered locally (per CONTRIBUTING). Reload to pick up the new plugin.

- [ ] **Step 2: Install the plugin into this repo**

Run in Claude Code:
```
/plugin install docs-curator@wundam-skills
```

Reload again so the hook and skill register.

- [ ] **Step 3: Run a manual audit**

Run in Claude Code:
```
/docs-curator
```

Expected: skill activates, detects project type as `claude-marketplace`, runs first-run mode, reports any critical findings, establishes baseline. State file written to `.claude/docs-state.json`.

- [ ] **Step 4: Capture observations**

Note any of:
- The skill misclassifies a file
- A finding seems wrong
- A reference file is missing information the skill needed
- The hook's gate doesn't fire (or fires too aggressively)
- Performance is slow

If issues are found, fix them before Task 19. Common fixes:
- Adjust the default policy to handle a missed case
- Tighten the hook gate's filter
- Clarify a reference document that the skill misread

- [ ] **Step 5: Stage the state file (or gitignore'd if user prefers)**

If the state file at `.claude/docs-state.json` was created during dogfood, decide:

- Commit it as the marketplace's own baseline (consistent with the spec's "state file is committed" decision).
- Or delete it before commit if you want each user to start fresh.

For this marketplace, **commit it** to demonstrate the intended team-baseline pattern.

```bash
git add .claude/docs-state.json
git commit -m "chore: dogfood docs-curator on this marketplace; establish baseline"
```

---

## Task 19: Fix any issues from dogfood

**Files:** depend on what was found.

- [ ] **Step 1: For each issue noted in Task 18 step 4:**

Make a focused commit with the fix. Examples:

- Reference doc missing detail → edit the reference doc, commit `docs(docs-curator): clarify <topic> in <reference>.md`.
- Hook gate too noisy → edit `stop-gate.sh`, add corresponding test in `test-stop-gate.sh`, commit `fix(docs-curator): tighten gate to skip <case>`.
- Skill misclassification → edit `SKILL.md` or relevant reference, commit `fix(docs-curator): correct <case> classification`.

- [ ] **Step 2: Re-run dogfood**

Repeat Task 18 step 3. Confirm previously-broken cases now work.

- [ ] **Step 3: Update CHANGELOG.md if anything substantive changed during dogfood**

If the fix is meaningful, append a bullet to the `## [Unreleased]` section of `plugins/docs-curator/CHANGELOG.md`. Commit:

```bash
git add plugins/docs-curator/CHANGELOG.md
git commit -m "docs(docs-curator): document <fix> in [Unreleased]"
```

---

## Task 20: Release v0.1.0

**Files:**
- Modified by `scripts/release.sh`: `plugins/docs-curator/.claude-plugin/plugin.json`, `plugins/docs-curator/CHANGELOG.md`, `.claude-plugin/marketplace.json`.

- [ ] **Step 1: Verify clean working tree**

Run: `git status`

Expected: `nothing to commit, working tree clean`. If not, commit any pending changes first.

- [ ] **Step 2: Verify [Unreleased] is populated**

Run: `sed -n '/## \[Unreleased\]/,/^## /p' plugins/docs-curator/CHANGELOG.md | head -20`

Expected: at least one bullet point under `## [Unreleased]`.

- [ ] **Step 3: Pre-set plugin version to 0.0.0**

The release script bumps from the current version, so to land at `0.1.0` from a `minor` bump we must start at `0.0.0`. Edit both manifests:

`plugins/docs-curator/.claude-plugin/plugin.json` — change `"version": "0.1.0"` → `"version": "0.0.0"`.

`.claude-plugin/marketplace.json` — change the `docs-curator` entry's `"version": "0.1.0"` → `"version": "0.0.0"`.

```bash
git add plugins/docs-curator/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(docs-curator): set version baseline to 0.0.0 for first release"
```

- [ ] **Step 4: Run the release script**

```bash
./scripts/release.sh docs-curator minor
```

Expected behavior:
- Verifies clean working tree.
- Verifies `[Unreleased]` is populated.
- Bumps both manifests from `0.0.0` to `0.1.0`.
- Renames `[Unreleased]` → `[0.1.0] - YYYY-MM-DD` and inserts a fresh empty `[Unreleased]` placeholder.
- Commits the changes.
- Creates annotated tag `docs-curator/v0.1.0`.

- [ ] **Step 5: Verify tag created**

Run: `git tag --list 'docs-curator/*'`

Expected: `docs-curator/v0.1.0`.

- [ ] **Step 6: Inform user**

Do not push. Per CONTRIBUTING:

> Push the commit and the tag manually after review:
> ```
> git push origin main
> git push origin <plugin-name>/vX.Y.Z
> ```

Tell the user:

```
docs-curator v0.1.0 released locally. Review with:
  git log --oneline -5
  git show docs-curator/v0.1.0

When ready to publish:
  git push origin main
  git push origin docs-curator/v0.1.0
```

---

## Summary

After all 20 tasks:

- New plugin `docs-curator` in `plugins/docs-curator/` with manifest, hook, skill, command, README, CHANGELOG.
- Tested Stop hook (`tests/test-stop-gate.sh` — 7 passing tests).
- Marketplace and root README updated.
- Dogfooded on this repo with baseline state committed.
- Tagged `docs-curator/v0.1.0` ready to push.

The user pushes manually after final review.
