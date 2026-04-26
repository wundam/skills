# Risk Tiers and Actions

Every proposed action is tagged with a risk tier. The tier determines the approval flow.

## Action vocabulary

| Action | Description | Default tier |
|---|---|---|
| `move` | Move file to canonical location | low |
| `rename` | Rename to standard pattern | low |
| `delete` | Remove transient/duplicate/empty file | low |
| `route-to-gitignore` | Move into `.claude/scratch/` (gitignored) | low |
| `stub` | Replace duplicate content with pointer to canonical doc | low |
| `merge` | Combine two docs into one | mid |
| `generate` | Create new doc from code analysis | mid |
| `consolidate` | Combine N docs into single canonical | high |

## Tier semantics

### low — batch approval

The user can approve all `[low]` actions in one go (`all` or `low`). Each is independently safe:

- File operations (move/rename/delete) are git-reversible.
- Stub action replaces content but is bounded to one file.
- `route-to-gitignore` requires `.claude/scratch/` to exist and to be in `.gitignore`. If the project's `.gitignore` does not include `.claude/scratch/`, propose adding it as a separate low action and depend on its approval first.

### mid — per-item diff approval

Each `[mid]` action is presented one at a time:

1. Show full file diff (or full new file content for generate).
2. Ask: "Apply this? (y/n/skip)".
3. Apply on `y`, leave alone on `n` (don't add to memory, may re-prompt later), add to memory on `skip`.

### high — per-item plan approval

Each `[high]` action is presented one at a time:

1. Show a numbered plan of the file operations involved (which files merged/moved/deleted, in what order).
2. Show the resulting canonical file's content.
3. Ask: "Apply this plan? (y/n/skip)".
4. Same outcome rules as mid.

## When to escalate tier

The default tier per action is the starting point. Escalate to a higher tier when:

- A `delete` would remove a file with substantial content (>50 lines) that the user might still want — escalate to `mid`, show the file content first.
- A `merge` would combine docs from different doc types (README + ADR) — escalate to `high`, this is structural.
- A `generate` would create a file in a sanctioned folder where one already exists nearby — verify the existing one isn't sufficient first.

## When to de-escalate

Never. If unsure, stay at the higher tier.

## Per-doc-type overrides

Some doc types have hard rules (see `type-rules.md`):

- ADR / shipped spec → never `merge`, never `delete`, never `consolidate`. Only `move`-as-archive is allowed (also low).
- CHANGELOG → never edit old released entries. Only edit `[Unreleased]` section.

If a proposed action conflicts with a per-doc-type rule, drop the action (don't propose it).
