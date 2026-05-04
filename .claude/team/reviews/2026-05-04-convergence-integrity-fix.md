---
task: Review the proposed fix that adds a Convergence Integrity Check to team-review's basic-mode.md and advanced-mode.md
mode: basic
participants:
  - architect
  - agent-protocol-designer
  - skill-author
  - red-team
  - ux
  - qa
consensus: true
rounds: 3
---

# Request

Review the proposed fix that adds a "Convergence Integrity Check" subsection to `plugins/team-review/skills/team-review/references/basic-mode.md` and `references/advanced-mode.md` (plus a small visibility hook in `SKILL.md`). The fix:

1. Bans embedded "Pick one / Option A vs B / Decision needed from you" patterns inside `CONSENSUS PLAN` output.
2. Redefines "compatible" — positions are compatible only if their actions can both happen in the same executed plan, not "both shown as options".
3. Closes the "accepted dissent" escape hatch for in-scope action disputes.
4. Routes to the existing safety-cap escalation pre-emit when red flags fire.
5. Adds rationalization-table and red-flags lists from the verbatim failure case.

The failure case (RED-phase artifact): a recent `/team-review` run on the orchex repo emitted a "Consensus plan (proposed for your approval)" containing `(Pick one — bundling decision is yours)` and ended with `Decision needed from you: Option A or Option B for #2 above?`. This is non-convergence dressed up as consensus.

# Team assembly

- architect — cross-file consistency (`basic-mode.md`, `advanced-mode.md`, `SKILL.md`); convergence rules are part of the skill's spec
- agent-protocol-designer — primary owner of debate/convergence semantics; the fix lives in their surface
- skill-author — writing-skills compliance (RED-GREEN-REFACTOR for docs, rationalization tables, red-flags lists, loophole-closing patterns)
- red-team — adversarial scrutiny: where will an agent rationalize past the new rule?
- ux — readability of the new wording; whether an agent under pressure recognizes "this applies to me"
- qa — verifiable test plan (must-fire negative + must-NOT-over-fire positive); persisted regression cases

Skipped: pm (ship-decision implicit), developer (architect covers cross-file shape), release-engineer (CHANGELOG concern raised inline), docs-engineer (no docs reorg).

# Debate transcript

## Pass 1 — independent positions

- architect: Two parallel files (`basic-mode.md`, `advanced-mode.md`) need the rule; lean toward DRY-ing into a shared reference + one-line nod in `SKILL.md`. Flag: this is a behavior change, not a pure bug fix — minor version bump (1.1.0).
- agent-protocol-designer: This is exactly the loophole I worried about when writing the convergence-check sections. Fix is correct. Concern: the existing safety-cap escalation block has "after 5 passes" framing baked in; pre-emit reroute would mis-fire if it lands on pass 2. Need a generalized block.
- skill-author: Fix uses the right writing-skills patterns. Strong concern: NO SKILL EDIT WITHOUT A FAILING TEST — RED is the user's pasted plan, GREEN-phase verification needed before commit. Keep the SKILL.md addition under one line; references files carry the full rule.
- red-team: Phrase-matching is a tripwire, not a rule. Three concrete bypasses I'd attempt: (1) sequenced framing "A now, B later"; (2) preference-not-choice re-framing; (3) re-classify in-scope as out-of-scope. The PRIMARY rule must be structural — exactly one path of action at every decision point — and phrase-matching is the secondary safety net.
- ux: Convergence-check section currently lives in the middle of `basic-mode.md`. The CONSENSUS PLAN output template is at the bottom. Agents drafting output look at the TEMPLATE, not back-scroll. Need a SECOND placement: "BEFORE EMITTING — verify integrity" reminder right above the template block.
- qa: Subagent verification needs two tests, not one — negative (must fire) and positive (must NOT over-fire). Persist both as regression cases in `references/edge-cases.md` so future fixes don't re-introduce the loophole.

## Pass 2 — tensions

- T1 (architect vs. agent-protocol-designer / skill-author): rule LOCATION — shared reference vs. cohabitation in both mode files.
- T2 (red-team vs. proposer): rule SHAPE — structural-first vs. phrase-match-first ordering.
- T3 (qa vs. proposer): test SCOPE — one verification run vs. positive + negative + persisted regression.
- T4 (architect): version bump — patch (1.0.1) vs. minor (1.1.0).
- T5 (ux vs. structural-only camp): rule PLACEMENT — single insertion vs. dual placement (rule + pre-emit tripwire above template).
- T6 (agent-protocol-designer): existing safety-cap escalation block has "after 5 passes" framing baked in; pre-emit reroute would mis-fire on pass 2.

## Pass 3 — re-evaluation

- architect: Updating on T1. agent-protocol-designer's framing right — modes are structurally parallel siblings; cohabit the rule + SKILL.md one-liner; skip the shared reference file. Holding on T4 (minor bump — output an agent produces visibly changes in the disagreement case).
- red-team: Holding on T2. Add wording: "If any structural condition is met, the team has not converged — even if the tripwire does not fire." Structural rule primary; tripwire backup.
- agent-protocol-designer: Updating on T6. Generalize the escalation block — factor "Unresolved positions" output shape so it can be invoked from both safety-cap and pre-emit integrity-check call sites. Wording becomes condition-agnostic; caller adds a one-line preamble.
- ux: Holding on T5. Two placements: full rule in convergence section, short pre-emit reminder right above the CONSENSUS PLAN template.
- qa: Holding on T3. Two tests + persisted regression cases in `references/edge-cases.md`.
- skill-author: Compatible with architect's update (SKILL.md stays tight) and qa's regression-cases addition.

All tensions resolved or compatible. No accepted dissent.

# Consensus plan

Mode: basic. Participants: architect, agent-protocol-designer, skill-author, red-team, ux, qa. Rounds: 3.

Summary: Add a Convergence Integrity Check as a structural rule (primary) + phrase-matching tripwire (secondary), placed in BOTH `basic-mode.md` and `advanced-mode.md` (no shared reference file), with a short pre-emit reminder co-located with the CONSENSUS PLAN output template. Generalize the existing safety-cap escalation block so it can be invoked from both the cap path and the pre-emit integrity-check path. Persist regression cases in `edge-cases.md`. Bump team-review to v1.1.0 (minor) on release. Verify with two subagent tests (must-fire + must-NOT-over-fire) before commit.

Changes shipped:
1. `plugins/team-review/skills/team-review/references/basic-mode.md` — added "## Convergence integrity check" subsection (structural rule + tripwire + rationalization counters + red flags); refactored existing safety-cap output into a generalized "## Escalation block" referenced by both call sites; added pre-emit reminder above the "## Output" CONSENSUS PLAN template.
2. `plugins/team-review/skills/team-review/references/advanced-mode.md` — same three insertions adapted to advanced-mode's structure (after "## Convergence check"; pre-emit reminder above "## Synthesis and output").
3. `plugins/team-review/skills/team-review/SKILL.md` — appended one-line nod to Phase 4 bullet pointing to the new check.
4. `plugins/team-review/skills/team-review/references/edge-cases.md` — added "## Convergence integrity regression cases" subsection with two scenarios (in-scope action conflict → escalation; out-of-scope concern → normal CONSENSUS PLAN).
5. `plugins/team-review/CHANGELOG.md` — `[Unreleased]` "Changed" entry describing the strengthened convergence rule and generalized escalation block; "Added" entry for regression cases.

Verification (both passed):
- Negative subagent test (must fire): contrived in-scope action disagreement (PR #102 bundle-vs-defer scenario). With the fix loaded, the agent correctly identified the deadlock pre-emit, did NOT produce "Option A vs B" inside CONSENSUS PLAN, and emitted the Escalation block with the pre-emit preamble. Verbatim output verified.
- Positive subagent test (must NOT over-fire): contrived legitimate accepted-dissent scenario (Microsoft Clarity onboarding-analytics with security raising an out-of-scope data-retention concern). With the fix loaded, the agent correctly identified the in-scope agreement, did NOT over-trigger the integrity check, and emitted a normal CONSENSUS PLAN with security's concern under "Dissent (accepted)". Verbatim output verified.

Risks & mitigations:
- Dual-file drift between `basic-mode.md` and `advanced-mode.md` — identical rule wording; CHANGELOG note pairs them; future edits review both as a unit.
- Subagent tests not in `scripts/tests/` (those test bash) — scenarios persisted in `edge-cases.md` so a future agent re-running tests has a checklist.
- Agent paraphrases past the tripwire — structural rule is primary and stated first; tripwire is the backup, not the definition.
- Minor bump surprises consumers with output-shape change — CHANGELOG "Changed" entry describes the new escalation output verbatim.

Release: `scripts/release.sh team-review minor` → v1.1.0 once user is ready to ship.

# Dissent (if any)

None.
