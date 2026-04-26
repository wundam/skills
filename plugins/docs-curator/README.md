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

The first time you run `docs-curator` in a project, it does *not* flood you with findings. It establishes a baseline: only critical violations (strict blacklist matches at root, multi-README clashes, project-type required files missing) are reported. Everything else is accepted as-is and added to `memory.specific`.

**Baseline is sticky.** Once a file is baselined, future audits skip it for *all* rules — even if it later changes. `/docs-curator full` runs every rule but still respects `memory.specific`, so it only deeply audits files added or changed *after* baseline. To force re-evaluation of a baselined file, delete its entry from `.claude/docs-state.json`. To wipe baseline entirely, run `/docs-curator reset`.

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
