---
slug: architect
role: System Architect
tier: core
added_at: 2026-05-04
added_reason: Core role
focus:
  - Plugin and skill structure boundaries
  - Marketplace.json / plugin.json shape and consistency
  - Cross-plugin consistency (frontmatter, references/, templates/, commands/)
  - Release versioning surface (semver, tag conventions, per-plugin scope)
  - Cross-cutting impact when one skill references conventions of another
surfaces:
  - .claude-plugin/marketplace.json
  - plugins/*/.claude-plugin/plugin.json
  - plugins/*/skills/*/SKILL.md (frontmatter + structure)
  - plugins/*/skills/*/references/
  - plugins/*/skills/*/templates/
  - plugins/*/commands/
  - scripts/release.sh
---

# Notes

## 2026-05-04 — convergence-integrity-fix
- Pushed for a shared reference file holding the convergence rule; conceded after agent-protocol-designer's framing that basic-mode.md and advanced-mode.md are structurally parallel siblings. Cohabit the rule with SKILL.md one-liner; skip shared reference. DRY-cost (~25 duplicated lines) accepted.
- Successfully argued for **minor** version bump (1.1.0), not patch — agent output visibly changes in the disagreement case. CHANGELOG should call this out under "Changed", not "Fixed".
- Standing concern for future skill edits: dual-file drift between basic-mode.md and advanced-mode.md is now a maintenance risk. Any future edit to the convergence semantics must touch both as a unit; reviewer of such PRs should verify wording is identical.
