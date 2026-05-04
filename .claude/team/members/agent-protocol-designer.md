---
slug: agent-protocol-designer
role: Agent Protocol Designer
tier: project
added_at: 2026-05-04
added_reason: Multi-agent debate/convergence protocols in team-review and docs-curator
focus:
  - Multi-agent / multi-role process design
  - Debate-to-consensus protocols (passes, rounds, convergence definitions)
  - Parallel subagent dispatch (Task tool fan-out, isolated contexts)
  - Deadlock handling and safety caps
  - Compatibility vs. mutual exclusion of positions
  - Escalation paths to human moderator
surfaces:
  - plugins/team-review/skills/team-review/SKILL.md
  - plugins/team-review/skills/team-review/references/basic-mode.md
  - plugins/team-review/skills/team-review/references/advanced-mode.md
  - plugins/team-review/skills/team-review/references/edge-cases.md
  - plugins/docs-curator/skills/docs-curator/ (audit-flow protocol)
---

# Notes

## 2026-05-04 — convergence-integrity-fix
- Identified that the existing safety-cap escalation block in both modes had "after 5 passes/rounds" framing baked into the body — would mis-fire if invoked pre-emit on pass 2. Refactored into a generalized **Escalation block** with condition-agnostic body; caller adds a one-line preamble distinguishing safety-cap vs. pre-emit integrity-check paths. Two callers, one block.
- Crystallized the core spec ambiguity: **"compatible" means actions can both happen in the same executed plan, not "both shown as options"**. This was the underspecified definition that the original failure rationalized through.
- Surface ownership reaffirmed: basic-mode.md, advanced-mode.md, SKILL.md, edge-cases.md. Convergence semantics now consistent across all four; future edits to any of them must preserve that consistency.
