# Project context

## Summary

wundam-skills is a public Claude Code plugin marketplace. The work product is **process-oriented skills** — markdown rules that shape how Claude (and other agents) approach tasks. Two plugins ship today: `team-review` (persistent project-level senior team with debate-to-consensus protocol) and `docs-curator` (documentation audit and reorganization). The repo is bash-tooled (release.sh) and follows a one-plugin-per-directory layout under `plugins/`, with per-plugin Keep-a-Changelog files.

## Stack & tooling

- bash 3.2+ (release tooling, hooks)
- markdown (the actual deliverable — SKILL.md files, CHANGELOGs, READMEs)
- jq for JSON manipulation in release.sh
- Claude Code plugin marketplace format (.claude-plugin/marketplace.json, plugin.json)
- Per-plugin layout: `skills/<skill>/SKILL.md` + optional `commands/`, `agents/`, `hooks/`, `templates/`, `references/`
- `scripts/release.sh` for per-plugin semver bumps and tagging (`<plugin>/vX.Y.Z`)
- `scripts/tests/test-release.sh` integration tests for release tooling

## Domain & audience

The audience is **other Claude instances** running inside Claude Code. A skill is consumed by an agent making decisions under pressure (time, context, sunk cost). Skills compete for attention in the agent's system prompt and must trigger reliably from a short description, then be navigable inside the body. Authoring uses TDD-for-docs: pressure scenarios with subagents drive RED-GREEN-REFACTOR on the skill text.

## Constraints & priorities

- **Skill clarity over surface coverage**: a skill that triggers on the right cases > a skill that lists every possible trigger.
- **Loophole-resistant rules**: agents will rationalize. Discipline-skills must close loopholes explicitly with red-flags tables and counter-arguments.
- **Per-plugin release discipline**: every change lands under `[Unreleased]` in the plugin's CHANGELOG; release.sh fails if `[Unreleased]` is empty at tag time.
- **No application code**: this is a docs/process repo. There is no app to test in a browser; tests are subagent pressure scenarios + bash integration tests for release tooling.
- **Marketplace stability**: published plugin versions are immutable (tagged); breaking changes need clear migration notes in CHANGELOG.
