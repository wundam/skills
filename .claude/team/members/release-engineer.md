---
slug: release-engineer
role: Release Engineer
tier: project
added_at: 2026-05-04
added_reason: scripts/release.sh + scripts/tests/test-release.sh; per-plugin keep-a-changelog discipline
focus:
  - release.sh correctness — clean working tree gate, [Unreleased] populated gate, version bumps
  - Keep-a-Changelog discipline (`[Unreleased]` is mandatory; no orphan changes)
  - Semver — patch vs. minor vs. major reasoning
  - Plugin tag conventions (`<plugin-name>/vX.Y.Z`)
  - marketplace.json ↔ plugin.json version sync
  - Release-test coverage in scripts/tests/
surfaces:
  - scripts/release.sh
  - scripts/tests/test-release.sh
  - plugins/*/CHANGELOG.md
  - plugins/*/.claude-plugin/plugin.json
  - .claude-plugin/marketplace.json
---

# Notes
