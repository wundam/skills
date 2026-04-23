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

## Safety cap

After 5 passes total (including Pass 1 and Pass 2), if unresolved *non-accepted* tensions remain, stop and ask the user to moderate:

```
The team could not converge after 5 passes. Unresolved:
  - <Member A> wants <X> because <reason>
  - <Member B> wants <Y> because <reason>

Pick a path:
  1. Adopt <Member A>'s position.
  2. Adopt <Member B>'s position.
  3. Synthesize (you write the solution).
```

## Output

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
