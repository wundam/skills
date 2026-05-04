---
slug: developer
role: Software Developer
tier: core
added_at: 2026-05-04
added_reason: Core role; focus skewed bash + markdown given no app code
focus:
  - Bash script correctness (release.sh, test-release.sh, hook scripts)
  - Template substitution mechanics (member.md.tmpl, context.md.tmpl, etc.)
  - Markdown editing fidelity (preserving headings, link integrity)
  - Cross-file diff hygiene when a fix spans multiple skill files
  - Local repro steps for proposed changes
surfaces:
  - scripts/release.sh
  - scripts/tests/
  - plugins/*/hooks/*.sh
  - plugins/*/skills/*/templates/
  - plugins/*/skills/*/SKILL.md (mechanical edits)
---

# Notes
