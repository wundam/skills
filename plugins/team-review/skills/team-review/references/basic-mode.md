# Basic mode — single LLM, simulated debate to consensus

Invoked when the user selects `basic` (default) or passes `--basic`.

Everything runs inside one Claude context — the model voices each relevant member in turn. The debate is sequential, not parallel, but it must still converge to consensus.

## Preconditions

- `team.json`, `context.md`, and every participating member's `members/<slug>.md` are loaded into context before the first pass.
- Acquire `.lock` (see `references/edge-cases.md`).

## Pass 1 — independent positions

Voice each relevant member in order of influence: PM first, Architect second, then roles most affected by the task (from their `surfaces`), ending with Developer and QA. For each:

```
<Role>: (position)
  <2-4 sentences stating what they see, grounded in code refs where possible>
```

Do not yet attempt to resolve disagreements.

## Pass 2 — tension identification

Summarize the tensions:

```
TENSIONS
- <Member A> vs <Member B>: <one-line framing of the disagreement>
- ...
```

If no tensions are surfaced, the debate converges immediately. Skip to **Consensus plan**.

## Pass N ≥ 3 — re-evaluation

For each member involved in an open tension, voice them again in light of the other positions:

```
<Role>: (re-evaluated)
  Holding / Updating. Reason: <...>
  Updated position: <...>
```

After each round of re-evaluation, re-check tensions. Three possibilities:

1. **Resolved** — all members now compatible. Proceed to consensus.
2. **Reduced** — fewer / different tensions remain. Continue to the next pass.
3. **Unchanged** — same tensions, nobody moved. Declare deadlock for that tension.

## Convergence

Convergence is one of:

- All tensions resolved. Full consensus.
- Remaining tensions are tagged as **accepted dissent** (out-of-scope, acceptable trade-off). Consensus on the action, disagreement preserved.

## Convergence integrity check

**Run this BEFORE emitting `CONSENSUS PLAN`. If any rule below fires, the team has not converged — route to the [Escalation block](#escalation-block) immediately, regardless of how many passes have run.**

### Structural rule (primary)

A converged plan describes **exactly one path of action at every decision point**. If the plan asks the user to choose between alternatives, the team has not converged — even if the tripwire below does not fire.

**Compatible** means: positions A and B are compatible iff their proposed actions can both happen in the same executed plan. Mutually-exclusive options are not compatible; they are deferred convergence.

**Accepted dissent** applies only to noted *out-of-scope* concerns where the in-scope action is agreed. It is NOT an escape hatch for in-scope action disputes. If members disagree on what to do for the same scope, that is in-scope — not accepted dissent.

### Tripwire (secondary)

If the consensus plan contains any of the following, treat as non-converged:

- "(Pick one ...)" / "Pick A or B"
- "Option A: ... / Option B: ..." presented as alternatives in the same plan section
- "Decision needed from you" / "Up to you" / "Bundling decision is yours"
- "Your call" / "Your preference" framed as a choice between options
- Two distinct courses of action presented for user selection

If any structural condition is met, the team has not converged — even if the tripwire above does not fire. The structural rule is primary; the tripwire is a backup, not a sufficient definition.

### Rationalization counters

| Excuse | Reality |
|--------|---------|
| "Both options are in the plan, so they're compatible." | Compatible means both *happen*, not user picks. Two options for selection = deferred convergence. |
| "Phasing them — A now, B later — both ship." | If both will happen in sequence, say so explicitly as a single ordered plan. If one excludes the other later, it's still deferred convergence. |
| "I'm not asking the user to pick, I'm asking their preference." | Asking the user to determine an action is choosing. Re-framing the verb does not change the structure. |
| "It's a scope disagreement, so it's accepted dissent." | If the proposed actions differ for the same scope, it's an in-scope dispute. Accepted dissent is for noted out-of-scope concerns where the in-scope action is agreed. |
| "The disagreement is small — I'll let the user decide." | Letting the user decide between two member-advocated actions IS non-convergence. Either resolve (continue passes) or escalate (route to the block below). |

### Red flags — STOP and escalate

- About to write "(Pick one ...)" inside a CONSENSUS PLAN section.
- About to write "Decision needed from you" at the end of the plan.
- About to write "Option A: ... / Option B: ..." in the plan body.
- About to write "Your call" or "Up to you" anywhere in the plan.

**All of these mean: the team has not converged. Do NOT emit a CONSENSUS PLAN with the choice embedded. Route to the [Escalation block](#escalation-block) instead.**

## Escalation block

Used by both the safety cap (after 5 passes) and the convergence integrity check (pre-emit, any pass). Output:

```
The team has not converged. Unresolved:
  - <Member A> wants <X> because <reason>
  - <Member B> wants <Y> because <reason>

Pick a path:
  1. Adopt <Member A>'s position.
  2. Adopt <Member B>'s position.
  3. Synthesize (you write the solution).
```

The caller adds a one-line preamble to indicate which path triggered it:
- Safety-cap caller: `Debate did not converge after 5 passes.`
- Pre-emit integrity caller: `The plan being drafted contains a deferred-convergence pattern (see Convergence integrity check).`

## Safety cap

After 5 passes total (including Pass 1 and Pass 2), if unresolved *non-accepted* tensions remain, stop and emit the [Escalation block](#escalation-block) above with the safety-cap preamble.

## Output

**Before emitting `CONSENSUS PLAN`, run the [Convergence integrity check](#convergence-integrity-check) above. If any rule fires, route to the [Escalation block](#escalation-block) instead.**

```
CONSENSUS PLAN
════════════════════════════════════════════════════════════════

Mode: basic
Participants: pm, architect, ux, mobile-engineer, qa, developer
Rounds: 3
Consensus: yes

Summary: <2-3 sentences>

Changes:
  1. <file> — <what changes and why>
  2. <file> — <what changes and why>

Test plan:
  - <what to test>

Risks & mitigations:
  - <risk> → <mitigation>

Debate summary:
  - Round 1 tension: <A> vs <B>. Resolved R2 after <X conceded Y>.
  - Round 2 tension: <...>.

Dissent (accepted):
  - <Member>: <concern tagged out-of-scope>

════════════════════════════════════════════════════════════════

Approve? (yes / modify / reject)
```

On user approval:

1. Write `<project>/.claude/team/reviews/<YYYY-MM-DD>-<task-slug>.md` using `review-log.md.tmpl`.
2. For each participating member, prepend a dated section to their `members/<slug>.md` `# Notes` body with the bullet findings attributed to them.
3. Update `team.json`: `last_review_at` = now (ISO-8601), `review_count` += 1.
4. Release `.lock`.
