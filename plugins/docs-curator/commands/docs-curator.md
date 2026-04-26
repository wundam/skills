---
description: Run a documentation audit. Subcommands: full, init, state, reset.
argument-hint: [full|init|state|reset]
---

# /docs-curator

You are running the `docs-curator` slash command. Load the skill and execute it.

## Argument handling

The user may provide one of these subcommands as `$ARGUMENTS`:

- `(empty)` — run a standard audit (incremental mode, baseline-aware)
- `full` — full re-audit, ignore baseline
- `init` — copy `.claude/docs-policy.md` template if missing
- `state` — show current `.claude/docs-state.json` (or "not initialized")
- `reset` — delete state, re-run audit from first-run mode

## Steps

1. Use the Skill tool to invoke `docs-curator:docs-curator` with the subcommand passed in `$ARGUMENTS`.
2. The skill handles all behavior; this command is just the user-facing entry point.

If `$ARGUMENTS` contains anything not in the list above, tell the user the valid subcommands and stop.
