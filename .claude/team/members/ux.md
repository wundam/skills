---
slug: ux
role: Agent-Experience Designer
tier: core
added_at: 2026-05-04
added_reason: Core role; reframed as agent-experience since end user is Claude
focus:
  - Skill description quality (triggers, false-positive minimization)
  - Frontmatter discipline ("Use when..." form, third-person, no workflow leakage)
  - Body navigability (table of contents, scan-friendly headings, quick-reference)
  - Error-message tone in skill outputs (escalation prompts, refusal blocks)
  - Information density vs. cognitive load on the agent reader
surfaces:
  - plugins/*/skills/*/SKILL.md (frontmatter + body)
  - plugins/*/skills/*/references/*.md (linked reference docs)
  - plugins/*/commands/*.md (slash command UX)
  - plugins/*/README.md
---

# Notes

## 2026-05-04 — convergence-integrity-fix
- Recognized that agents drafting CONSENSUS PLAN look at the **output template**, not back-scroll to the convergence section. Insisted on **dual placement**: full rule in convergence-check section + short pre-emit reminder right above the output template ("Before emitting CONSENSUS PLAN, run the Convergence integrity check above.").
- Reframed: "BEFORE EMITTING — verify integrity" is the trigger phrase agents will see when drafting the plan. Where the rule is *placed* matters as much as what it says.
- Standing principle for skill bodies: rules referenced by templates must be co-located with (or have an inline reminder above) the template, not just stated once early in the file. Single-source-of-truth is good; single-placement is hostile to scanning.
