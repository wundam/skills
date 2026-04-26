# docs-curator — Plugin Design

**Status:** Draft, awaiting user approval
**Date:** 2026-04-26
**Target:** new plugin in `wundam-skills` marketplace
**Source:** brainstorming session (2026-04-26)

---

## 1. Goals

`docs-curator` is a Claude Code plugin that keeps a project's documentation healthy across four axes:

1. **Pruning** — remove non-standard, duplicate, or orphan markdown
2. **Reorganizing** — move, rename, merge, or stub docs to canonical locations
3. **Freshness** — detect docs that reference deleted code or have grown out of sync
4. **Generation** — propose drafts when code exists but docs do not

It runs as a hybrid trigger: a deterministic Stop hook plus a skill the model invokes, with a manual `/docs-curator` slash command. All actions require explicit user approval; nothing destructive happens without consent.

## 2. Non-Goals (v1)

- Markdown content quality (typos, broken links, formatting) — defer to `markdownlint` or similar
- Real-time blocking of file writes (PreToolUse hook) — see §13.1
- Cross-project policy sharing via global config — defer to v2
- Doc generation framework integration (Sphinx, mkdocs, etc.)

## 3. Architecture

Three components, one plugin:

```
┌─────────────────┐
│ Stop hook       │  Claude Code → every model turn end
└────────┬────────┘
         ↓ shell exec
┌─────────────────┐
│ stop-gate.sh    │  ~50ms; cheap deterministic check
│ - git status    │
│ - state hash    │
│ - relevant?     │
└────────┬────────┘
         ↓ YES → emit <system-reminder>; NO → silent exit
┌─────────────────┐
│ Claude (skill)  │  loads SKILL.md, runs 8-step audit
└─────────────────┘

┌─────────────────┐
│ /docs-curator   │  manual; bypasses hook gate
└─────────────────┘
```

## 4. Plugin Layout

Mirrors existing `team-review` plugin structure:

```
plugins/docs-curator/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── CHANGELOG.md
├── skills/
│   └── docs-curator/
│       ├── SKILL.md
│       ├── references/
│       │   ├── default-policy.md
│       │   ├── findings-format.md
│       │   ├── risk-tiers.md
│       │   ├── type-rules.md
│       │   ├── project-types.md
│       │   ├── generation.md
│       │   └── first-run.md
│       └── templates/
│           ├── docs-policy.md.tmpl
│           └── docs-state.json.tmpl
├── commands/
│   └── docs-curator.md
├── hooks/
│   └── stop-gate.sh
└── settings.json.example
```

## 5. Triggers

### 5.1 Stop hook — `hooks/stop-gate.sh`

Runs at every model turn end. Target p95 latency: <100ms.

```
1. Read .claude/docs-state.json
   (missing → first-run mode → emit reminder).
2. current_hash = sha256(git status -s) ⊕ sha256(git rev-parse HEAD)
3. If current_hash == state.last_audit_state_hash → exit 0 (silent dedup).
4. Trigger conditions (any one):
   a. New or modified .md file in `git status -s`
   b. HEAD advanced beyond state.last_audit_head AND code files changed since
   c. New folder (working tree or any commit since last_audit_head) with ≥3 source files but no README at any level above
5. If any condition met:
     stdout:
     <system-reminder>
     docs-curator: doc audit needed
     (changed: <N> .md, stale risk: <yes/no>, gen candidates: <N>).
     Invoke skill: docs-curator.
     </system-reminder>
6. exit 0.
```

The hook never blocks Claude. It only injects context.

### 5.2 Slash command — `commands/docs-curator.md`

```
/docs-curator              audit (default flow)
/docs-curator full         override baseline; full re-audit
/docs-curator init         copy docs-policy.md.tmpl to .claude/
/docs-curator state        show current state JSON
/docs-curator reset        reset baseline; rebuild
```

Loads `SKILL.md` with subcommand as parameter.

### 5.3 Hook installation

**Implementation step 1: verify Claude Code plugin spec supports declaring hooks via `.claude-plugin/plugin.json`.**

- If supported → plugin installs hooks transparently.
- If not supported → plugin ships `settings.json.example` and README documents manual hook installation. Plugin works in dormant mode (only `/docs-curator` triggers it) until hook is installed.

This is a hard prerequisite to validate before scaffolding.

## 6. Skill Flow (`SKILL.md`)

Eight steps. Same flow whether triggered by hook or slash command.

### Step 1: Load policy + state
- `.claude/docs-policy.md` if present → user override merges over defaults
- Else → `references/default-policy.md` (skill-bundled)
- `.claude/docs-state.json` → current state, baseline, memory

### Step 2: Determine scope
- No state → first-run baseline mode (§10)
- `full` parameter → full re-audit, ignore baseline
- Default → incremental (changed files since last audit)

### Step 3: Detect project type

Sequential check:

| Marker file | Project type |
|---|---|
| `.claude-plugin/marketplace.json` | claude-marketplace |
| `.claude-plugin/plugin.json` | claude-plugin |
| `package.json` | node |
| `pyproject.toml`, `setup.py` | python |
| `Cargo.toml` | rust |
| `go.mod` | go |
| (none) | generic |

Apply type-specific expectations from `references/project-types.md`.

### Step 4: Inventory
- `git ls-files '*.md'` — tracked markdown
- Plus working-tree changes from `git status -s`
- Skip ignored: `.claude/`, `.github/`, `.cursor/`, `node_modules/`, `vendor/`

Classify each file:
- **ALLOWED** — matches whitelist or sanctioned folder
- **FLAGGED** — root non-whitelist, ad-hoc subfolder, multi-README
- **SANCTIONED** — inside `docs/` or other sanctioned folder

### Step 5: Build findings (5 categories)

| Category | Detection method |
|---|---|
| Non-standard | Filename matches blacklist patterns |
| Duplicate | Model-judged content overlap (semantic) |
| Stale | Doc references (function names, paths) verified against codebase via grep/file-check; OR `git log` shows code change in last 10 commits (configurable via policy) without doc update |
| Missing standard | Project-type expectations: README in plugin folder, CHANGELOG, etc. |
| Generation candidate | New folder w/ code but no README; large architectural change without ADR; missing required files for project type |

### Step 6: Type-aware risk assignment

Per `references/risk-tiers.md` and `references/type-rules.md`:

| Doc type | Detection | Edit policy |
|---|---|---|
| README | Filename | Mid risk for any edit (user-facing) |
| CHANGELOG | Filename | Append-only; old entries immutable |
| ADR | `docs/adr/`, `docs/decisions/` | Append-only; never merge old entries |
| Spec | `docs/specs/`, `docs/superpowers/specs/` | Date-bound; archive after feature ships; never edit shipped specs |
| API doc | `docs/api/` | Code-derived; regenerate-friendly |
| Guide | `docs/guides/`, `docs/tutorials/` | Mid risk edit |

### Step 7: Present + approve

Findings rendered per `references/findings-format.md`:

```
## Audit Findings

### Non-standard files (3)
1. NOTES.md (root) — ad-hoc notes
2. REVIEW.md (root) — leftover AI output
3. src/SOMETHING.md — ad-hoc subfolder doc

### Duplicates (1)
4. README.md + docs/getting-started.md — install steps overlap

### Stale (2)
5. docs/api.md — references deleted oldFn()
6. README.md — Quick start outdated since auth refactor

### Missing standard (1)
7. plugins/docs-curator/CHANGELOG.md missing

### Generation candidates (1)
8. apps/billing/ added (5 files), no README — proposed draft below

### Proposed actions
[low]  1, 3: delete (transient/ad-hoc)
[low]  2: route-to-gitignore → .claude/scratch/
[low]  4: stub docs/getting-started.md → README link
[mid]  5: rewrite docs/api.md (diff to follow)
[mid]  6: rewrite README quickstart (diff to follow)
[low]  7: create CHANGELOG.md from template
[mid]  8: generate apps/billing/README.md (preview to follow)

Approve?
  → "all" (apply all, mid items still show diff)
  → "low" (apply only low-risk batch)
  → "1,3,4,7" (specific items)
  → "skip" (apply nothing; mark as accepted-as-is)
  → "cancel" (do nothing; re-prompt next audit)
```

Approval rules:
- **Low** — batch approval applies all approved low items at once
- **Mid** — each shows diff/preview before applying; per-item approval required
- **High** — each shows full plan before applying; per-item approval required
- **"skip"** — adds findings to memory (specific or pattern; see §8) so they aren't re-flagged

### Step 8: Apply + update state

For each approved action:
1. Execute file operation (move/rename/delete/edit/write)
2. `git add` the change so user sees a clean diff
3. Record in state

After all actions:
1. Update `state.last_audit_at`, `state.last_audit_state_hash`, `state.last_audit_head`
2. Update memory: skipped findings → `memory.specific` or pattern-detect → propose `memory.pattern`
3. Update baseline: if first run, mark current state as baseline
4. Write `.claude/docs-state.json`

## 7. Action Vocabulary

| Action | Description | Risk |
|---|---|---|
| `move` | Move file to canonical location | low |
| `rename` | Rename to standard pattern | low |
| `delete` | Remove transient/duplicate/empty file | low |
| `route-to-gitignore` | Move to `.claude/scratch/` (gitignored) | low |
| `stub` | Replace duplicated content with pointer to canonical | low |
| `merge` | Combine two docs into one | **mid** (diff) |
| `generate` | Propose new doc from code analysis | **mid** (preview) |
| `consolidate` | Combine N docs into single canonical | **high** (plan) |

## 8. Memory Model

`.claude/docs-state.json` carries a 3-tier memory:

```json
"memory": {
  "specific": ["MIGRATION.md", "docs/legacy/old-arch.md"],
  "pattern":  ["*-migration.md", "*-postmortem.md"],
  "rule_disabled": ["ad_hoc_subfolder_readme"]
}
```

- **specific** — exact path; never re-flag
- **pattern** — glob; never re-flag matching files
- **rule_disabled** — entire rule category disabled

After 3+ "skip" decisions on the same pattern, skill proposes:

> "You've skipped `MIGRATION.md`-pattern findings 3 times. Suppress this pattern?"

User confirms → pattern added.

## 9. Generation Flow

When step 5 detects a generation candidate:

1. Skill reads the relevant code (limited to candidate scope)
2. Drafts the doc using model judgment
3. Presents as **mid** risk action with full preview
4. On approval, writes file and stages with `git add`

Generation triggers (`references/generation.md`):
- New folder with ≥3 source files, no README at any level above
- Last N commits (default N=10) significantly changed architecture (modules added/renamed/deleted), no ADR added in same window
- Plugin/package folder missing README or CHANGELOG (project-type aware)

Generation never modifies existing docs. Updates to existing docs go through `merge` or explicit `rewrite` (a mid-risk variant of `generate`).

## 10. First-Run Behavior

`references/first-run.md`:

1. Detect project type
2. Run full inventory but emit only **critical** findings:
   - Files matching strict blacklist (NOTES.md, TODO.md, etc.)
   - Multiple READMEs at same level
   - Missing required files for detected project type
3. Mark all other current state as baseline (added to `memory.specific` as accepted-as-is)
4. Set `state.baseline_set = true`
5. Inform user:

```
Baseline established (N files marked as accepted-as-is).
Run `/docs-curator full` for deep audit at any time.
```

This prevents a 50-finding flood when installing into messy projects.

## 11. Default Policy (`references/default-policy.md`)

### Allowed root files (whitelist)
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

### Sanctioned folders (allowed; light rules apply)
- `docs/`
- `docs/adr/`, `docs/decisions/` — ADR convention
- `docs/specs/`, `docs/plans/`
- `docs/superpowers/specs/`, `docs/superpowers/plans/`
- `.claude/`, `.github/`, `.cursor/` — fully ignored

### Strict blacklist (always flag at root)

Filename stems (case-insensitive): `NOTES`, `TODO`, `IDEAS`, `SCRATCH`, `DRAFT`, `REVIEW`, `ANALYSIS`, `REPORT`, `PLAN`, `THOUGHTS`, `RESEARCH`, `MEMO`, `WORKLOG`, `LOG`

Globs: `*-notes.md`, `*-todo.md`, `*-scratch.md`

## 12. Policy Override (`.claude/docs-policy.md`)

Users override defaults via simple markdown:

```markdown
# docs-curator policy

## allowed_root_files
- HACKING.md

## sanctioned_folders
- docs/research/

## disabled_rules
- ad_hoc_subfolder_readme

## blacklist_additions
- WORKLOG
```

Skill parses sections additively (these add to defaults, except `disabled_rules` which removes).

## 13. Design Decisions

### 13.1 No PreToolUse blocker
Considered: block bad writes at the tool boundary. Rejected because:
- Filename patterns can't catch novel ad-hoc names (`OBSERVATIONS.md`)
- Blocking writes mid-task frustrates Claude (loop risk)
- Manual user creation bypasses it
- Reactive Stop+skill is smarter: reads content, decides reorganization

### 13.2 No git pre-commit hook in v1
Considered: deterministic block at commit time. Rejected for v1 because:
- Skill cannot run in pre-commit (no model)
- Stop hook + skill catches issues before user commits
- Adds setup friction (per-project install)

May add `/docs-curator install-precommit` opt-in command in v2.

### 13.3 State file is committed (not gitignored)
Reason: shared baseline across team. Per-developer state means each contributor starts fresh and re-flags items others already accepted.

### 13.4 Generation as mid-risk only
Generated docs aren't free — wrong content is worse than no content. Always preview, always per-item approval.

### 13.5 Reactive over preventive
The "prevent bad doc creation" promise is met by:
- Stop hook fires fast (every turn end)
- Skill catches and offers to consolidate within seconds
- Net effect: bad docs don't accumulate

This is functionally equivalent to prevention from the user's perspective, without the brittleness of pre-write blocking.

## 14. Open Questions / Implementation Risks

1. **Plugin hook auto-registration** — does `.claude-plugin/plugin.json` support a `hooks` field? Verify before scaffolding. If unsupported, plugin ships dormant.

2. **Hash-based dedup edge cases** — `git status -s` hash isn't perfect (e.g., file mtime can change without content change). Verify in stress test; consider hashing file contents instead.

3. **Stale detection precision** — model-judged "code reference still exists" can hallucinate. Mitigation: skill MUST grep/file-check before flagging stale; never flag based on model recall alone.

4. **Performance ceiling** — repos with 500+ markdown files may make full audit slow. Mitigation: incremental mode is default; full mode opt-in.

5. **Generation quality** — generated drafts could be poor or off-target. Mitigation: always mid-risk with preview; user is final judge; no silent overwrites.

6. **Memory growth** — `memory.specific` could grow unbounded over years. Mitigation: prune entries when referenced files no longer exist.

## 15. Implementation Order

1. **Verify Claude Code plugin hook auto-registration** (hard blocker)
2. Scaffold plugin layout matching `team-review`
3. Write `references/default-policy.md` (the immutable rule set)
4. Write `SKILL.md` core flow (steps 1–8)
5. Write `hooks/stop-gate.sh` (gate)
6. Write `commands/docs-curator.md` (slash command + subcommands)
7. Write supporting `references/*` files (findings-format, risk-tiers, type-rules, project-types, generation, first-run)
8. Write `templates/*` files (docs-policy template, docs-state template)
9. Write plugin `README.md` and `CHANGELOG.md`
10. Update root `README.md` with new plugin entry
11. Dogfood on this marketplace repo
12. Run `scripts/release.sh docs-curator minor` (v0.1.0 release)
