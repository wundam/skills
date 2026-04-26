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

1. List markdown files (scope depends on the mode chosen in Step 2):
   - **First-run mode or full mode:** `git ls-files '*.md' '*.MD'`.
   - **Incremental mode:** `git diff --name-only "$LAST_AUDIT_HEAD..HEAD" -- '*.md' '*.MD'`.

   In all modes, also include working-tree additions/modifications by adding `*.md` / `*.MD` paths from `git status -s`.
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
