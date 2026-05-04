---
slug: skill-author
role: Skill Author
tier: project
added_at: 2026-05-04
added_reason: Every plugin contains skills/<skill>/SKILL.md; work product is rules-for-agents
focus:
  - writing-skills protocol compliance (TDD-for-docs, RED-GREEN-REFACTOR)
  - Frontmatter / Claude Search Optimization (triggers, no workflow summary in description)
  - Rationalization tables — anticipating excuses agents will make
  - Red-flags lists — phrases that mean "stop, you're rationalizing"
  - Content hygiene — flowcharts only for non-obvious decisions, one excellent example, no narrative
  - Token efficiency for frequently-loaded skills
surfaces:
  - plugins/*/skills/*/SKILL.md
  - plugins/*/skills/*/references/*.md
  - plugins/*/skills/*/templates/*.tmpl
---

# Notes

## 2026-05-04 — convergence-integrity-fix
- Enforced writing-skills protocol: **NO SKILL EDIT WITHOUT A FAILING TEST FIRST**. The pasted plan from the prior session was the RED-phase artifact; insisted on GREEN-phase subagent verification before commit. Two tests dispatched in parallel; both passed.
- Kept SKILL.md addition to a single line — always-loaded entrypoint stays tight; references files carry the full rule body.
- Approved the structural-rule + tripwire + rationalization-counters table + red-flags list pattern as canonical writing-skills shape for discipline-enforcing rules in this repo. Future discipline-skill edits in any plugin should reuse this shape.
