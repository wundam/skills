# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed

- `/docs-curator` slash command no longer infinite-loops. The previous version invoked the Skill tool with name `docs-curator:docs-curator`, which collided with the slash command file (also named `docs-curator`); the slash command now `Read`s `SKILL.md` directly.

### Added

- Clean-audit confirmation message: when an audit completes with zero findings (incremental or full mode), the skill emits a one-line positive confirmation instead of empty section headers.

## [0.1.0] - 2026-04-26

### Added

- Initial release: Stop hook + skill + slash command for documentation curation.
- Detects non-standard, duplicate, stale docs across project type (Claude marketplace/plugin, Node, Python, Rust, Go, generic).
- Generates README/ADR drafts when code exists but docs do not.
- 3-tier user memory (specific path / glob pattern / disabled rule) prevents repeated nagging.
- First-run baseline mode prevents flag flood in messy projects.
- Manual `/docs-curator` command with subcommands: `full`, `init`, `state`, `reset`.
