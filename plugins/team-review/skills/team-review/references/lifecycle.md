# Team lifecycle operations

Covers `reinit`, `add`, `remove`, and the `team` inspection command.

## `/team-review reinit`

Re-runs deep analysis on the current project. Produces a new proposed roster. Lets the user approve the diff. Preserves notes where possible.

0. Acquire `.lock` (see `references/edge-cases.md`). Release on every exit path.
1. Load existing `team.json`. Build `CURRENT_SLUGS = set(members[].slug)`.
2. Run the procedure from `references/deep-analysis.md` (Steps A-D). Produce `PROPOSED_SLUGS`.
3. Compute:
   - `KEPT = CURRENT_SLUGS ∩ PROPOSED_SLUGS`
   - `ADDED = PROPOSED_SLUGS - CURRENT_SLUGS`
   - `REMOVED = CURRENT_SLUGS - PROPOSED_SLUGS`
4. Present the diff:

```
REINIT DIFF
════════════════════════════════════════════════════════════════

Kept (notes preserved):
  - pm, architect, ux, qa, developer, database-engineer

Added (new members, empty notes):
  - devops-engineer — Dockerfile + fly.toml detected
  - security-engineer — auth middleware detected

Removed (archived, notes preserved):
  - mobile-engineer — no mobile signals remain

Signals changed since last analysis:
  + docker, fly-io, security
  - react-native, expo

Proceed? (yes / edit / cancel)
```

5. On approval:
   - Update `team.json` (new members array, updated signals, `analyzed_at`).
   - Update `context.md` to reflect new signals / stack.
   - For each slug in `REMOVED`: `mv members/<slug>.md members/_archived/<slug>.md`.
   - For each slug in `ADDED`:
     - If `members/_archived/<slug>.md` exists (slug previously archived): ask user "`<slug>` was archived earlier — restore with preserved notes?". On yes: `mv members/_archived/<slug>.md members/<slug>.md` and update frontmatter. On no: create fresh from template.
     - Otherwise: create fresh from `templates/member.md.tmpl`.
   - For slugs in `KEPT`: leave `members/<slug>.md` untouched.

## `/team-review add <role description>`

Interprets a free-form role request, proposes metadata, waits for user approval, writes a new member file.

0. Acquire `.lock` (see `references/edge-cases.md`). Release on every exit path.
1. Read `team.json`. Build `EXISTING_SLUGS`.
2. Interpret the user's input (e.g., "someone who knows payments"). Propose:
   - `slug`: kebab-case (`payments-engineer`)
   - `role`: display name (`Payments Engineer`)
   - `tier`: `project` (unless user explicitly asks for core)
   - `focus`: three bullets based on the description
   - `surfaces`: three glob patterns that plausibly match the project
   - `reason`: one line citing the user's own words
3. Slug collision handling:
   - If `slug ∈ EXISTING_SLUGS`, offer two options:
     a. Append `-2` (or next available suffix). New distinct member.
     b. Extend the existing member's `focus` instead (no new file). Show the proposed extension.
   - Let the user pick.
4. Present proposal, wait for approval.
5. On approval:
   - Render `templates/member.md.tmpl` → `members/<slug>.md`.
   - Append member entry to `team.json.members[]` with `reason`.

## `/team-review remove <slug>`

0. Acquire `.lock` (see `references/edge-cases.md`). Release on every exit path.
1. Load `team.json`. If `slug` not found, exit with "no such member".
2. If `member.tier === "core"`, show a strong warning:

```
<Role> is a core team role. Removing it means future reviews won't have
this perspective by default. You can add it back with `/team-review add`
or restore it on the next `/team-review reinit`. Confirm removal?
```

3. On confirmation, `mv members/<slug>.md members/_archived/<slug>.md`.
4. Remove entry from `team.json.members[]`.

## `/team-review team`

Read-only inspection. No state change.

1. Load `team.json` and `context.md`.
2. Print:

```
TEAM OVERVIEW
════════════════════════════════════════════════════════════════

Project: <name>
Summary: <project.summary>
Analyzed: <project.analyzed_at>
Signals: <project.signals joined>

Core (always included):
  - <role> — <focus headline> — <notes count>
  - ...

Project-specific:
  - <role> — <focus headline> — <notes count> — <reason>
  - ...

Stats:
  Last review: <last_review_at> (<N> days ago)
  Total reviews: <review_count>

════════════════════════════════════════════════════════════════
```

Focus headline = first bullet from the member's `focus:` frontmatter. Notes count = number of `##` dated sections in the member's `# Notes` body.
