---
name: team-review
description: Assemble a persistent project-level senior team, stored under `.claude/team/`, that gets smarter over time. Use when the user runs `/team-review` or asks for team-based analysis, review, or implementation planning. On first use in a project the skill runs deep analysis and proposes a team; on subsequent uses it loads the existing team and runs a debate-to-consensus review (basic or advanced mode).
---

# Team Review

A project's team-review team is a **persistent, long-lived senior collective** stored under `<project>/.claude/team/`. The team is assembled once via deep project analysis, grows in understanding across reviews (per-member accumulated notes), and is reused for every subsequent review. Both review modes produce a consensus (agreed) solution.

## When to use

- User invokes `/team-review` with any arguments.
- User asks for team-based analysis, multi-role review, or structured discussion of a bug / feature / spec / decision.
- User asks "who should work on this" or requests implementation planning with multiple perspectives.

Do NOT use when:
- User wants a single-perspective opinion (pick the right skill / direct response).
- User is asking a narrow factual question that does not need deliberation.

## State location

All state lives under `<the current working directory's>/.claude/team/`.

```
.claude/team/
├── team.json                           # roster + project metadata
├── context.md                          # shared project facts
├── members/<slug>.md                   # per-member focus + accumulated notes
├── members/_archived/<slug>.md         # removed members (notes preserved)
├── reviews/<YYYY-MM-DD>-<task-slug>.md # per-review log
└── .lock                               # present while a review runs
```

Exact schemas: `references/schemas.md`.

## Command dispatch

The `/team-review` command dispatches based on the first argument and optional flags.

| Invocation | Action | Reference |
|---|---|---|
| `/team-review <task>` | Run a review. Prompts for mode (basic / advanced). | `references/basic-mode.md` or `references/advanced-mode.md` |
| `/team-review --basic <task>` | Review in basic mode. | `references/basic-mode.md` |
| `/team-review --advanced <task>` | Review in advanced mode (parallel subagents). | `references/advanced-mode.md` |
| `/team-review team` | Read-only team overview. | `references/lifecycle.md` § `/team-review team` |
| `/team-review add <role description>` | Propose and add a new member. | `references/lifecycle.md` § `/team-review add` |
| `/team-review remove <slug>` | Archive a member. | `references/lifecycle.md` § `/team-review remove` |
| `/team-review reinit` | Re-analyze project, propose new roster diff. | `references/lifecycle.md` § `/team-review reinit` |

## First-use flow

Whenever the skill activates for a review or lifecycle operation:

1. Check whether `<cwd>/.claude/team/team.json` exists and is valid (`references/edge-cases.md`).
2. If it does **not** exist, run deep analysis (`references/deep-analysis.md`) to propose and create the team. Then proceed to the requested operation.
3. If it does exist, validate `schema_version`. On mismatch, handle per `references/edge-cases.md`.

## Review flow (summary)

For `/team-review <task>`:

1. Acquire `.lock` (see `references/edge-cases.md`).
2. Load `team.json`, `context.md`, and the relevant `members/<slug>.md` files.
3. **Phase 1 — Team assembly:** pick the relevant member subset for this task (4-7 members typical). Present to user. Wait for approval.
4. **Phase 2 — Debate to consensus:**
   - **Basic mode:** follow `references/basic-mode.md`. Single LLM, sequential passes, max 5.
   - **Advanced mode:** follow `references/advanced-mode.md`. Parallel subagents per member, multi-round debate, max 5 rounds.
   - Both modes MUST produce a consensus plan. If they fail after 5 passes/rounds, escalate to the user as human moderator.
5. **Phase 3 — User approval:** present the consensus plan. User approves / modifies / rejects.
6. On approval:
   - Write `reviews/<YYYY-MM-DD>-<task-slug>.md` from `templates/review-log.md.tmpl`.
   - Prepend a dated `##` section to each participating member's `# Notes` body.
   - Update `team.json` metadata: `last_review_at`, `review_count`.
7. Release `.lock`.

## Composition rules

- **Core members** (`tier: core`) are always included in a team on first analysis: `pm`, `architect`, `ux`, `qa`, `developer`. See `references/role-catalog.md`.
- **Project members** (`tier: project`) are inferred from project signals per the mapping table in `references/role-catalog.md`. Analysis may propose roles outside the table when justified.
- **Team size target:** 8-12 members total for a typical project. Team is broad by design — never shrink to 3-4.
- **Per-review participation:** most reviews engage 4-7 members — the relevant subset, not the whole roster. Selection is based on task + member `surfaces`.

## Memory model

- Each member's `members/<slug>.md` contains an accumulating `# Notes` body (`##`-headed dated sections, newest first).
- Notes grow across reviews. The skill does not auto-compress. When growth becomes a problem, the user can edit the file directly or run `/team-review reinit`.
- Shared project facts live in `context.md` — do not duplicate in member notes.

## State file integrity

- Validate `team.json` on every load (`references/edge-cases.md`).
- Respect the lock file (`references/edge-cases.md`).
- Every state-mutating operation must acquire and release the lock.

## References

All detailed procedures live in these files (Claude loads them on demand):

- `references/schemas.md` — exact state-file shapes.
- `references/role-catalog.md` — core roles and signal → role mapping.
- `references/deep-analysis.md` — first-run project analysis.
- `references/basic-mode.md` — single-LLM debate-to-consensus procedure.
- `references/advanced-mode.md` — parallel-subagent debate protocol.
- `references/lifecycle.md` — reinit, add, remove, team inspection.
- `references/edge-cases.md` — lock, malformed state, non-convergence, etc.

Templates (skill writes them verbatim with placeholder substitution):

- `templates/team.json.tmpl`
- `templates/context.md.tmpl`
- `templates/member.md.tmpl`
- `templates/review-log.md.tmpl`
