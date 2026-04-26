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
