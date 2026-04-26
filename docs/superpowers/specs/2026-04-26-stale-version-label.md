# docs-curator — `stale_version_label` rule

**Status:** Draft, awaiting human review (spec only — no implementation)
**Date:** 2026-04-26
**Target:** new rule in `plugins/docs-curator` (skill: `docs-curator`)
**Source:** v0.1.1 dogfood incident (commit [`ce97771`](../../../../../commit/ce97771))

---

## 1. Problem

The root `README.md` carried a stale plugin version label after the v0.1.1 release of `docs-curator` shipped:

```diff
- ### `docs-curator` — v0.1.0
+ ### `docs-curator` — v0.1.1
```

The fix landed in commit `ce97771`:

> docs: bump docs-curator version label to v0.1.1 in root README
>
> Caught manually during dogfood; the audit missed it because README.md
> is in memory.specific (baselined). Surfaces the need for a future
> stale_version_label rule that compares version strings in docs against
> plugin.json/CHANGELOG.

A `/docs-curator full` audit run during the v0.1.1 release did not flag this. The root cause is structural, not a missed heuristic:

- Root `README.md` was added to `state.memory.specific` when it was baselined on first run.
- Step 6 of the 8-step flow (`SKILL.md` §Step 6) drops findings whose path is in `memory.specific`.
- Therefore the file the version label lives in was unreachable to any rule.

This is the wrong default for version-drift detection specifically. **Baselined docs are exactly where version drift accumulates** — they were correct on day 1 and gradually fall behind ground truth. The longer a doc has been baselined, the higher the prior probability that its version labels are stale.

`stale_code_reference` (already in `references/default-policy.md`) does not catch this case: a string like `v0.1.0` is not a referenced symbol or path, so grep against the codebase produces no signal.

## 2. Goals

Detect, in tracked docs, version strings that lag behind an authoritative source — and propose a string-replace fix as a `[low]`-tier batch-approvable action.

## 3. Non-Goals

- Implementing the rule. **This document is a spec; code changes are explicitly out of scope.** Implementation requires a separate, approved plan.
- Multi-version migration support (e.g., propagating breaking-change notices when a major bumps).
- Auto-fixing CHANGELOG entries. Released CHANGELOG entries are immutable per `references/type-rules.md`; this rule never touches them.
- Markdown-content quality (typos, broken links). Out of scope across docs-curator v1, including this rule.
- Detecting *missing* version labels. The rule fires on existing labels that are stale; it does not propose adding labels where none exist.

## 4. Detection

### 4.1 Regex patterns

Scan tracked markdown files for the following candidate forms (case-insensitive where relevant):

| Pattern | Example match | Notes |
|---|---|---|
| `\bv\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?\b` | `v0.1.0`, `v1.2.3-rc.1` | Leading `v`, semver-ish |
| `\bversion[:\s]+\d+\.\d+\.\d+\b` | `version: 0.1.0` | YAML/prose field form |
| `"version"\s*:\s*"\d+\.\d+\.\d+"` | `"version": "0.1.0"` | JSON-in-prose (rare in docs) |

The set is deliberately small in v1. Future patterns (date-based versions, `@x.y.z` package specifiers) can extend later.

### 4.2 Scope

- Files: tracked `*.md` / `*.MD` returned by `git ls-files` (same scope rule as Step 4 of the skill flow).
- Skip: ignored folders (`.claude/`, `.github/`, `.cursor/`, `node_modules/`, `vendor/`) per `references/default-policy.md`.
- Run: full mode, incremental mode, and first-run mode all evaluate this rule (subject to the memory carve-out in §6).

### 4.3 False-positive guards

The rule must suppress (not flag) these forms; treating them as drift would generate noise:

1. **CHANGELOG version headings.** Inside a `CHANGELOG.md`, a heading like `## [0.1.0] - 2026-04-20` is a historical record, not a label. Skip any version string that lives in a CHANGELOG version-section header (released or unreleased). Released entries are immutable per `references/type-rules.md` regardless.
2. **Placeholder/example version strings.** Strings inside fenced code blocks where the surrounding prose marks them as templates (e.g., `vX.Y.Z`, `v0.0.0`, `v?.?.?`). The token forms `vX.Y.Z` / `v?.?.?` are placeholders by construction; skip outright.
3. **Fork / contributor docs.** `CONTRIBUTING.md` and `docs/contributing/**` may legitimately reference older versions when describing migration history. If the version string sits in a code block whose surrounding text mentions "fork", "upgrade", "migration", or "previously", do not flag.
4. **Inline code spans.** `` `v0.1.0` `` inside flowing prose that describes the *previous* version (signaled by neighboring words: "before", "until", "prior to", "in v…") is not drift; it is a comparison. The model should suppress when the contextual reading is clearly historical.
5. **Code comments / source examples.** A version string inside a fenced ```code``` block of a non-markdown language (e.g., a Python snippet hardcoding `version = "0.1.0"`) is a source example, not a doc claim. Skip unless the surrounding prose explicitly asserts the doc-level claim.

Guards are applied after extraction, before comparison. When a guard fires, record the suppression in the model's reasoning so a future audit can sanity-check the heuristic.

### 4.4 What "stale" means

A flagged finding requires:

1. The extracted version string refers to a known package/plugin in this repo (resolved via §5).
2. The extracted version is *strictly less than* the authoritative version (semver compare). Equal → not stale. Greater → not flagged either; emit an informational warning ("doc claims a version newer than authoritative source") and let a human decide. Greater-than is rare and likely indicates a mid-release doc edit that landed before the manifest bump.

## 5. Authoritative source resolution

Per detected project type (from `references/project-types.md`):

| Project type | Authoritative source for plugin/package `<X>` |
|---|---|
| `claude-marketplace` | `plugins/<X>/.claude-plugin/plugin.json` → `version` |
| `claude-plugin` | `.claude-plugin/plugin.json` → `version` |
| `node` | `package.json` → `version` |
| `python` | `pyproject.toml` → `[project].version` if present, else `setup.py` (parsed conservatively) |
| `rust` | `Cargo.toml` → `[package].version` |
| `go` | (none — `go.mod` does not carry a project version; rule is a no-op for go projects unless a fallback applies) |
| _any of the above, on miss_ | Top non-`[Unreleased]` heading in the project's `CHANGELOG.md` |

### 5.1 Mapping doc-mentioned name → authoritative source

In a `claude-marketplace`, the same root `README.md` may reference multiple plugins. The rule must resolve which authoritative source to compare against:

1. Look for the plugin name as a token near the version string within ~3 lines (configurable). Tokens of interest: bare name (`docs-curator`), backticked (`` `docs-curator` ``), heading-form (`### docs-curator`).
2. If a name resolves to a `plugins/<X>/` directory, use that plugin's `plugin.json`.
3. If no name token resolves nearby, fall back to the project's own manifest (claude-plugin / node / etc.), or the top CHANGELOG entry.
4. If still ambiguous, do not flag. Better silent than wrong.

### 5.2 Fallback to CHANGELOG

When the manifest lookup fails (no `plugin.json`, no `package.json` field, etc.), use the top heading in the relevant `CHANGELOG.md` that is **not** `[Unreleased]`. Format: `## [X.Y.Z] - YYYY-MM-DD`. This matches Keep-a-Changelog as already assumed in `references/type-rules.md` §CHANGELOG.

## 6. Memory carve-out — explicit override of `memory.specific`

This is the load-bearing change.

The skill's Step 6 currently drops all findings whose path is in `state.memory.specific` or matches `state.memory.pattern`. For `stale_version_label` only, that filter is *partially inverted*:

- `memory.specific` does **not** suppress this rule. Baselined docs are precisely where version-label drift lives; the whole point of the rule is to look there.
- `memory.pattern` does **not** suppress this rule, for the same reason.
- `memory.rule_disabled` **does** still suppress it. If a user explicitly disables `stale_version_label` (or adds it to `disabled_rules` in `.claude/docs-policy.md`), the rule is off everywhere. This is the documented escape hatch.

Implementation will require touching the Step 6 filter to be rule-aware. The default behavior for every other rule is unchanged. Document the carve-out clearly in `references/default-policy.md` next to the rule entry, and in the rule's row in the rules table:

```
| stale_version_label | Doc-stated version lags authoritative source. Bypasses memory.specific/pattern; honors memory.rule_disabled. |
```

### 6.1 Why not pattern-suppress this?

Pattern suppression (e.g., `*-migration.md`) intentionally hides a class of file from review forever. Version-label drift is the opposite shape: the file is fine, one substring inside it has gone stale. A user who skipped a `[low]` `stale_version_label` finding should not be silently opted into pattern-suppressing the file from *all* future rules.

For this reason, the existing "3+ skips → propose pattern suppression" behavior in Step 7 must explicitly **not** apply to `stale_version_label` findings. Skips for this rule still go to `memory.specific` per the existing flow, but those entries are unread by §6 above. Net effect: a user can mute one specific finding without the rule going dark.

## 7. Action and tier

| Action | Description | Tier |
|---|---|---|
| `replace-version-label` | String-replace the stale version with the authoritative version, in-place | `[low]` |

Reasoning:

- Edit is a single substring substitution. The diff is one line, fully reviewable in the batch approval.
- `risk-tiers.md` already classifies bounded `stub`/`rename`/`delete` as `[low]` for the same reason: small blast radius, git-reversible.
- README is normally `mid` per `type-rules.md` §README, but that rule scopes to **content edits**. A version-string substitution is not a content rewrite; it is a label update. The tier override is justified and should be documented in the rule entry.

Actions are batch-approvable via the standard `[low]` flow in `references/findings-format.md`. The findings report renders one entry per stale label:

```
### Stale (1)
N. README.md:48 — docs-curator version label `v0.1.0` lags `plugins/docs-curator/.claude-plugin/plugin.json` (`v0.1.1`)

### Proposed actions
[low]  N: replace `v0.1.0` → `v0.1.1` in README.md:48
```

Line-number granularity is required: a single doc may contain multiple labels for different plugins.

## 8. Edge cases

1. **Multiple plugins per marketplace, multiple labels per doc.** Each label resolves independently per §5.1; each produces its own finding. No cross-finding deduping.
2. **Same plugin labeled twice in one doc.** Two findings, two replacements. They share an authoritative source but are distinct edits.
3. **Pre-release / build metadata** (`v0.1.0-rc.1`, `v0.1.0+build.5`). Compare via semver including prerelease ordering. A `v0.1.0` label is *not* stale relative to a `v0.1.0-rc.1` manifest — release > prerelease. A `v0.1.0-rc.1` label *is* stale relative to a `v0.1.0` manifest.
4. **Doc references a plugin not in this repo.** Resolution fails at §5.1 step 4. Do not flag.
5. **Manifest version is non-semver** (e.g., `2026.04`). Out of scope for v1; skip and emit a debug note. Future extension.
6. **Race condition: manifest bumped, doc bumped, audit run mid-edit.** Working-tree changes are included in the inventory (per Step 4 of the skill flow); compare against the in-tree manifest, not HEAD. Edits in flight are reflected.
7. **CONTRIBUTING.md "this plugin requires Claude Code v0.x+".** Tooling-version requirements are not plugin/package versions in this repo. Guard §4.3.3 (fork/migration context) covers many cases; remaining false positives can be silenced by the user via `memory.rule_disabled`-as-skip-equivalent (see §6) or by adding the file to `disabled_rules` in policy. Document this in the user-facing rule description.
8. **Version label inside a `LICENSE`/`SECURITY.md`.** These rarely carry plugin version labels; if they do, they are typically tooling versions and fall under #7. No special handling needed in v1.
9. **Dangling refs after a rename.** If `plugins/<old-name>/` was renamed to `plugins/<new-name>/`, doc references to `<old-name>` cannot resolve. Per §5.1 step 4, do not flag. Renames are a separate concern (a future `stale_plugin_reference` rule could address them).

## 9. Open questions

1. **Locality window for name token resolution.** §5.1 currently says "~3 lines". Is heading-scope (everything until the next heading of equal-or-shallower depth) a more robust unit? Probably yes for `README.md`-style docs. Worth exploring during implementation.
2. **Should a version string greater than the manifest be a finding or not?** §4.4 currently says emit an informational warning. The implementation may choose to suppress entirely if the warning channel is noisy in practice.
3. **Does the rule need a separate config knob for "minimum delta to flag" (e.g., only flag when a minor or major lags, not patches)?** Default: flag any lag. Configurable in `.claude/docs-policy.md` if friction emerges.

## 10. Implementation order (deferred)

Not part of this spec. When a separate implementation plan is approved, the natural order is:

1. Add `stale_version_label` row to `references/default-policy.md` rules table, with the bypass note from §6.
2. Update `SKILL.md` Step 6 to be rule-aware (carve-out).
3. Implement the detection regex + guards in the skill flow per §4.
4. Implement authoritative-source resolution per §5.
5. Implement the `replace-version-label` action and tier classification per §7.
6. Add tests / dogfood on this marketplace repo (root `README.md` is the canonical fixture).
7. Update `CHANGELOG.md` `[Unreleased]` for `docs-curator`; ship in next release.

Do not start any of the above without explicit human approval of this spec.
