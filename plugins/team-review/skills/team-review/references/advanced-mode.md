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

## Safety cap

Maximum 5 rounds. After round 5, if open tensions remain:

```
Advanced-mode debate did not converge after 5 rounds. Open positions:
  - <Role A>: <position>
  - <Role B>: <position>

Pick:
  1. Adopt <Role A>'s position.
  2. Adopt <Role B>'s position.
  3. Synthesize (you write the solution).
```

## Synthesis and output

On convergence, main Claude synthesizes the agreed plan using the same output template as basic mode (see `references/basic-mode.md`), with `mode: advanced` and `rounds: <N>`. The Debate transcript section has per-round entries with each member's `STILL_AGREES` + `UPDATED_POSITION`.

## State updates

Identical to basic mode on approval:

1. Write `reviews/<YYYY-MM-DD>-<task-slug>.md` (richer debate transcript in Advanced).
2. Update each participating member's `members/<slug>.md` notes.
3. Update `team.json` metadata.
4. Release `.lock`.

## Notes on cost

Advanced mode fans out N subagents × R rounds. Token cost scales roughly `N × R`. Use for high-stakes reviews (architecture decisions, breaking changes, security-sensitive work). For everyday reviews, basic is usually right.
