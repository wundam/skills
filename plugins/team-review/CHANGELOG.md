# Changelog

All notable changes to `team-review` are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [semver](https://semver.org/).

## [Unreleased]

### Changed

- **Convergence rule strengthened.** Both `basic-mode.md` and `advanced-mode.md` now require a Convergence integrity check before emitting `CONSENSUS PLAN`. A converged plan must describe exactly **one** path of action at every decision point — mutually-exclusive options presented for user selection ("Pick one", "Option A vs Option B", "Decision needed from you", etc.) are non-convergence and route to the Escalation block, regardless of how many passes/rounds have run. This closes a loophole where partial-consensus plans were emitted with embedded user-choice prompts. Behaviorally visible: agents will produce different output in the disagreement case.
- **Escalation block generalized.** The previous safety-cap-only escalation output is now a shared block invoked from both the safety-cap (after 5 passes/rounds) and the new pre-emit integrity-check (any pass/round). Wording is condition-agnostic; the caller adds a one-line preamble distinguishing the two paths.

### Added

- `references/edge-cases.md` § "Convergence integrity regression cases" — two persisted scenarios (in-scope action conflict must escalate; out-of-scope concern must NOT over-fire) that future skill edits must continue to satisfy.

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
