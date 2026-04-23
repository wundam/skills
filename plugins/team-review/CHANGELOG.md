# Changelog

All notable changes to `team-review` are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [semver](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-04-22

Initial public release.

### Added

- Persistent project-level team stored under `<project>/.claude/team/`. On first use, the skill runs deep project analysis and proposes a ~8-12 member team (5 core + project-inferred).
- Per-member accumulating notes across reviews — each member's domain understanding of the project grows over time.
- Two review modes, both converging to consensus:
  - **Basic:** single LLM voices members, sequential tension resolution, max 5 passes.
  - **Advanced:** parallel subagents per member, multi-round debate, max 5 rounds.
- Sub-verbs on `/team-review`: `team` (inspect roster), `add <role description>`, `remove <slug>`, `reinit`.
- Flags: `--basic`, `--advanced`.
- State lock (`.claude/team/.lock`) with 30-minute staleness cutoff for concurrent-session safety.
- Review logs under `.claude/team/reviews/` — per-review transcripts; member notes summarize.
- Archive behavior for removed / reinit-dropped members (`members/_archived/`), with restore-on-reappear.
- Skill integrity check (`scripts/check-skill-integrity.sh`) that verifies every `references/*.md` and `templates/*.tmpl` link in `SKILL.md` resolves.
