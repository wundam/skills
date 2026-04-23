# Edge cases

Behaviors that do not fit the happy-path descriptions.

## Lock file (`.claude/team/.lock`)

The skill creates `.claude/team/.lock` (empty file) on the first file-writing step of a review or lifecycle operation. The lock is released on successful completion, on failure, or on user cancellation.

**Acquisition rule:** Before writing any state, check whether `.lock` exists.

- Does not exist → create it, proceed.
- Exists AND `mtime` < 30 minutes ago → another review is running; refuse with:

```
Another team-review operation is in progress (lock created <N minutes> ago).
Wait or, if you are sure no operation is running, delete:
  <project>/.claude/team/.lock
```

- Exists AND `mtime` ≥ 30 minutes ago → consider it stale. Delete and proceed; log a note on the next review.

**Release rule:** Delete `.lock` on every exit path from any state-mutating operation (review finished, user cancelled, error thrown). Use a try/finally pattern in the skill's prose.

## Malformed `team.json`

On load, validate:
- File exists and is non-empty.
- Parses as JSON.
- Contains `schema_version` (integer).
- Contains `project` (object) and `members` (array).

If any check fails:

```
Your team state appears corrupted:
  <path>/team.json
  <specific parse error>

Recovery options:
  1. Run `/team-review reinit` to rebuild from scratch (preserves members/_archived/).
  2. Restore from git: `git checkout HEAD -- .claude/team/team.json`.
  3. Edit the file manually if you know what's wrong.

team-review cannot proceed until this is fixed.
```

## Schema version mismatch

If `schema_version > 1` (future version), refuse with:

```
This team state was created by a newer version of team-review
(schema_version = <N>). Please upgrade the team-review plugin.
```

If `schema_version < 1` (older version), the skill migrates on load. Migrations are documented inline when introduced (none for v1.0.0).

## Empty `[Unreleased]` in plugin CHANGELOG at release time

Not a team-review runtime concern, but a release-time concern: the `scripts/release.sh` tool in this repo enforces a populated `[Unreleased]` section before cutting a tag. If it fails on release, update `plugins/team-review/CHANGELOG.md` with the entries and re-run.

## Core role removal

Allowed, but the skill shows a strong warning (see `references/lifecycle.md`). If the user removes all five core roles, the next review will have an undersized team. The skill will not block this, but it will warn at the start of the next review:

```
Your team has no core roles. Reviews will lack baseline product / architecture /
UX / QA / developer perspectives. Consider `/team-review reinit` or `add`.
```

## Slug collision on `add`

See `references/lifecycle.md` § `/team-review add`. The user is offered either `-2` suffixing or focus extension of the existing member.

## Debate non-convergence

After the safety cap (5 passes / rounds) in either mode, the skill surfaces the deadlock and asks the user to moderate (see basic-mode.md and advanced-mode.md for exact prompts).

## Concurrent sessions (same machine, different projects)

No conflict: state is per-project (under each project's `.claude/team/`). Two Claude Code sessions in two different projects do not collide.

## Concurrent sessions (same project)

Serialized via the `.lock` file (see above).

## Very small project (empty repo)

See `references/deep-analysis.md` § Empty-project fallback.

## `members/_archived/` grows unbounded

Archived members are never auto-deleted. This is intentional: notes carry project memory and users can restore at any time. If a user wants to reclaim space, they can `rm <project>/.claude/team/members/_archived/*.md` manually.