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
