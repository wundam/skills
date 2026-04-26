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
