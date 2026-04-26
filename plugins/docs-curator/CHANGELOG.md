# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Initial release: Stop hook + skill + slash command for documentation curation.
- Detects non-standard, duplicate, stale docs across project type (Claude marketplace/plugin, Node, Python, Rust, Go, generic).
- Generates README/ADR drafts when code exists but docs do not.
- 3-tier user memory (specific path / glob pattern / disabled rule) prevents repeated nagging.
- First-run baseline mode prevents flag flood in messy projects.
- Manual `/docs-curator` command with subcommands: `full`, `init`, `state`, `reset`.
