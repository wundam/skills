# Advanced mode — parallel subagents, multi-round debate

Invoked when the user passes `--advanced`. More expensive (one subagent per relevant member per round); more robust (genuine isolated-context positions).

## Preconditions

Same as basic mode (state loaded, `.lock` acquired).

## Team assembly — Phase 1

Same as basic: pick the relevant subset of members based on task + surfaces. Present proposal to user. Wait for approval.

## Round 1 — independent positions (parallel)

For each member in the approved subset, dispatch a subagent in parallel using Claude Code's Task tool. The subagent prompt template:

```
You are the <role> member of this project's review team.

## Shared project context

<inline contents of context.md>

## Your role

<inline contents of members/<slug>.md, including focus, surfaces, and past notes>

## Task under review

<the user's task>

## Your job

1. Read the affected code based on your surfaces and the task description. Use Read, Grep, and Glob. Do not edit anything.
2. From your role's perspective, form an initial position on the task.
3. Report back in this exact shape:

POSITION
  <2-4 sentences of your stance>

REASONING
  <why you believe this>

CODE REFERENCES
  - <file:line> — <what you found>

OPEN QUESTIONS
  - <any uncertainty you want to flag>

Do not synthesize. Do not address other members' views — you haven't seen them. Be opinionated and concise.
```

Dispatch all subagents in a single message (parallel). Collect all responses.

## Round N ≥ 2 — debate rounds

Main Claude (the moderator) reviews Round N-1 outputs and identifies open tensions: positions that directly conflict, or questions that another member's position makes answerable.

For each member whose position is challenged or newly relevant, dispatch a Round N subagent:

```
You are the <role> member. This is debate round <N>. Your previous position:

<Round N-1 POSITION + REASONING>

These are the other members' positions from round <N-1>:

  - <role>: <position>
  - <role>: <position>

## Your job

1. Reconsider your position in light of the other members' arguments. You MAY:
   - Hold your position (restate with refined reasoning).
   - Update your position (explain what changed your mind).
   - Narrow your position (concede part, keep part).
2. Report back in this exact shape:

STILL_AGREES: <true | false>
UPDATED_POSITION: <2-4 sentences — if unchanged, restate verbatim>
REASONING: <why>
RESPONDING_TO: <which member(s) you specifically engaged with>
```

## Convergence check (moderator, after each round)

A position is **compatible** with another if the two can coexist in a single plan without contradiction. After round N:

1. If all positions are compatible → converged. Stop.
2. If some positions conflict but the conflicts are tagged as out-of-scope / acceptable risk → converged with accepted dissent. Stop.
3. Otherwise → another round.

## Convergence integrity check

**Run this BEFORE emitting the synthesized plan. If any rule below fires, the team has not converged — route to the [Escalation block](#escalation-block) immediately, regardless of how many rounds have run.**

### Structural rule (primary)

A converged plan describes **exactly one path of action at every decision point**. If the plan asks the user to choose between alternatives, the team has not converged — even if the tripwire below does not fire.

**Compatible** means: positions A and B are compatible iff their proposed actions can both happen in the same executed plan. Mutually-exclusive options are not compatible; they are deferred convergence.

**Accepted dissent** applies only to noted *out-of-scope* concerns where the in-scope action is agreed. It is NOT an escape hatch for in-scope action disputes. If members disagree on what to do for the same scope, that is in-scope — not accepted dissent.

### Tripwire (secondary)

If the synthesized plan contains any of the following, treat as non-converged:

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
| "The disagreement is small — I'll let the user decide." | Letting the user decide between two member-advocated actions IS non-convergence. Either resolve (continue rounds) or escalate (route to the block below). |

### Red flags — STOP and escalate

- About to write "(Pick one ...)" inside the synthesized plan.
- About to write "Decision needed from you" at the end of the plan.
- About to write "Option A: ... / Option B: ..." in the plan body.
- About to write "Your call" or "Up to you" anywhere in the plan.

**All of these mean: the team has not converged. Do NOT emit the synthesized plan with the choice embedded. Route to the [Escalation block](#escalation-block) instead.**

## Escalation block

Used by both the safety cap (after 5 rounds) and the convergence integrity check (pre-emit, any round). Output:

```
The team has not converged. Open positions:
  - <Role A>: <position>
  - <Role B>: <position>

Pick:
  1. Adopt <Role A>'s position.
  2. Adopt <Role B>'s position.
  3. Synthesize (you write the solution).
```

The caller adds a one-line preamble to indicate which path triggered it:
- Safety-cap caller: `Advanced-mode debate did not converge after 5 rounds.`
- Pre-emit integrity caller: `The plan being drafted contains a deferred-convergence pattern (see Convergence integrity check).`

## Safety cap

Maximum 5 rounds. After round 5, if open tensions remain, emit the [Escalation block](#escalation-block) above with the safety-cap preamble.

## Synthesis and output

**Before emitting the synthesized plan, run the [Convergence integrity check](#convergence-integrity-check) above. If any rule fires, route to the [Escalation block](#escalation-block) instead.**

On convergence, main Claude synthesizes the agreed plan using the same output template as basic mode (see `references/basic-mode.md`), with `mode: advanced` and `rounds: <N>`. The Debate transcript section has per-round entries with each member's `STILL_AGREES` + `UPDATED_POSITION`.

## State updates

Identical to basic mode on approval:

1. Write `reviews/<YYYY-MM-DD>-<task-slug>.md` (richer debate transcript in Advanced).
2. Update each participating member's `members/<slug>.md` notes.
3. Update `team.json` metadata.
4. Release `.lock`.

## Notes on cost

Advanced mode fans out N subagents × R rounds. Token cost scales roughly `N × R`. Use for high-stakes reviews (architecture decisions, breaking changes, security-sensitive work). For everyday reviews, basic is usually right.
