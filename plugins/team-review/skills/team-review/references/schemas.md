# State file schemas

The skill stores all state under `<project>/.claude/team/`. This file is the single source of truth for file shapes.

## `team.json`

Roster and project metadata. Read at the start of every review.

```json
{
  "schema_version": 1,
  "project": {
    "name": "<project name>",
    "summary": "<one-line description>",
    "analyzed_at": "YYYY-MM-DD",
    "signals": ["<stack-token>", "<stack-token>"]
  },
  "members": [
    { "slug": "<kebab-case-slug>", "role": "<display name>", "tier": "core" },
    { "slug": "<kebab-case-slug>", "role": "<display name>", "tier": "project", "reason": "<why added>" }
  ],
  "last_review_at": "ISO-8601 timestamp",
  "review_count": 0
}
```

Rules:
- `schema_version` is `1`. Bumped when file shape changes; the skill must migrate older versions on load.
- `project.signals` are freeform string tokens used only to justify the roster. Advisory.
- `members[].tier` is either `core` (always-present) or `project` (project-inferred).
- `members[].reason` is required when `tier === "project"`, optional for `core`.

## `context.md`

Shared project facts. Read at the start of every review. All members reference it; do not duplicate these facts in individual member notes.

```markdown
# Project context

## Summary

<one paragraph — product, domain, target users>

## Stack & tooling

- <bullet: runtime, framework, language>
- <bullet: database / storage>
- <bullet: deployment / infra>
- <bullet: notable libraries>

## Domain & audience

<one paragraph — who uses this, what problem it solves>

## Constraints & priorities

- <bullet: an explicit constraint, e.g. "offline-first", "HIPAA", "battery-aware">
```

## `members/<slug>.md`

One file per active member. Frontmatter holds stable role metadata; the `# Notes` body is append-prepend (newest-first) across reviews.

```markdown
---
slug: <kebab-case-slug>
role: <display name>
tier: core | project
added_at: YYYY-MM-DD
added_reason: <short explanation>
focus:
  - <concern 1>
  - <concern 2>
surfaces:
  - <path pattern 1>
  - <path pattern 2>
---

# Notes

## YYYY-MM-DD — <review slug>
- <finding 1>
- <finding 2>

## YYYY-MM-DD — <earlier review slug>
- <earlier finding>
```

Rules:
- `slug` in frontmatter matches the filename and the entry in `team.json`.
- `focus` captures what the member cares about.
- `surfaces` are glob-like hints pointing to where this member most often looks. Not enforced.
- Notes are dated markdown `##` headings; the skill prepends (newest first) on every review participation.

## `members/_archived/<slug>.md`

Identical shape to `members/<slug>.md`. Destination for members removed by `/team-review remove` or dropped by `/team-review reinit`. Moving preserves notes; the file is restored back to `members/` if the same slug is re-added later.

## `reviews/<YYYY-MM-DD>-<task-slug>.md`

One file per review. Chronological log — the durable history; member notes are per-member summaries distilled from these logs.

```markdown
---
task: <the user's task text, truncated to one line>
mode: basic | advanced
participants:
  - <member-slug>
  - <member-slug>
consensus: true | false
rounds: <integer>
---

# Request

<full task text>

# Team assembly

- <member-slug> — <one-line reason they were chosen>
- <member-slug> — <one-line reason>

# Debate transcript

## Round 1 — independent positions

- <member-slug>: <position summary>
- <member-slug>: <position summary>

## Round 2 — (repeat for each round)

- <member-slug>: <hold | update | reason>

# Consensus plan

<the agreed solution — numbered list or prose>

# Dissent (if any)

- <member-slug>: <accepted concern, tagged as out-of-scope or acceptable-risk>
```

## `.lock`

Empty file. Present while a review is executing. Absent otherwise. Contains no content. Stale-lock cutoff: 30 minutes (checked against file mtime).
