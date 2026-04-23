# Contributing

## Prerequisites

- `git`
- `jq` (JSON processor — `brew install jq` on macOS)
- `bash` 3.2+ (works with the system bash on macOS)

## Repository layout

- `.claude-plugin/marketplace.json` — marketplace manifest
- `plugins/<name>/` — one plugin per directory
  - `.claude-plugin/plugin.json` — plugin metadata
  - `skills/<skill>/SKILL.md` — skill definitions
  - `commands/<cmd>.md` — slash commands
  - `agents/<agent>.md` — subagent definitions
  - `hooks/hooks.json` — event-driven hooks
  - `CHANGELOG.md` — Keep-a-Changelog style, per-plugin
  - `README.md` — plugin description + usage
- `scripts/release.sh` — release tooling
- `scripts/tests/` — integration tests for release tooling
- `docs/superpowers/specs/` — design documents
- `docs/superpowers/plans/` — implementation plans

## Development workflow

`<marketplace-name>` in the commands below refers to the `name` field in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json). `<repo-path>` is the absolute path to this repo on your machine.

1. Register the repo as a local marketplace once:

   ```
   /plugin marketplace add <repo-path>
   ```

2. Install plugins into a project:

   ```
   /plugin install <plugin-name>@<marketplace-name>
   ```

3. Edit files under `plugins/<plugin>/`. Reload Claude Code (restart the session or reload the window) to pick up changes.

## Releasing a plugin

Every change lands under the `[Unreleased]` section of the plugin's `CHANGELOG.md`. When it's time to ship:

```
./scripts/release.sh <plugin-name> <patch|minor|major>
```

The script will:
1. Verify the plugin exists and the working tree is clean.
2. Verify `plugins/<plugin>/CHANGELOG.md` has a populated `[Unreleased]` section (it will **fail** if the section is missing or empty).
3. Bump the version in `plugin.json` and `.claude-plugin/marketplace.json`.
4. Rewrite the changelog: rename `[Unreleased]` to the new version/date and insert a fresh empty `[Unreleased]` placeholder above it.
5. Commit the changes and create an annotated tag `<plugin-name>/vX.Y.Z`.

Push the commit and the tag manually after review:

```
git push origin main
git push origin <plugin-name>/vX.Y.Z
```

## Running release-script tests

```
./scripts/tests/test-release.sh
```
