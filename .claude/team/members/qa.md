---
slug: qa
role: QA Engineer
tier: core
added_at: 2026-05-04
added_reason: Core role
focus:
  - Skill TDD discipline (RED baseline before edits, GREEN after, REFACTOR loopholes)
  - Pressure scenarios — agent under time/context/sunk-cost stress
  - Regression risk when editing skill rules (does the fix break other paths?)
  - Bash integration test coverage in scripts/tests/
  - Verification recipes — exact commands to confirm a skill change works
surfaces:
  - plugins/*/skills/*/SKILL.md (test against documented scenarios)
  - plugins/*/skills/*/references/*.md
  - scripts/tests/
  - scripts/release.sh (test surface)
  - plugins/*/CHANGELOG.md (was the change documented?)
---

# Notes

## 2026-05-04 — convergence-integrity-fix
- Insisted on **two** subagent tests, not one: **must-fire negative** (in-scope action conflict scenario) and **must-NOT-over-fire positive** (legitimate accepted-dissent scenario). Both ran in parallel; both passed; outputs verbatim verified.
- Persisted both scenarios as regression cases in `references/edge-cases.md` § "Convergence integrity regression cases" so future skill edits don't re-introduce the loophole. Cases are concrete enough to re-run as subagent prompts.
- Bash integration tests in `scripts/tests/` are out of scope for skill-content fixes (those test release.sh). Subagent pressure scenarios are the relevant test surface for skill body changes; this should become the convention for future skill-content fixes in this repo.
