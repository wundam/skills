---
description: Run a documentation audit. Subcommands: full, init, state, reset.
argument-hint: [full|init|state|reset]
---

# /docs-curator

The user invoked `/docs-curator` with arguments: `$ARGUMENTS`.

## Validate the subcommand

Valid `$ARGUMENTS` values:

- `(empty)` — standard audit (incremental mode, baseline-aware)
- `full` — full re-audit, ignore baseline
- `init` — copy `.claude/docs-policy.md` template if missing
- `state` — show current `.claude/docs-state.json` (or "not initialized")
- `reset` — delete state, re-run audit from first-run mode

If `$ARGUMENTS` is anything else, tell the user the valid subcommands and stop.

## Run the audit

Read the skill file at `${CLAUDE_PLUGIN_ROOT}/skills/docs-curator/SKILL.md` using the `Read` tool, then follow its instructions, treating `$ARGUMENTS` as the subcommand input.

**Do not invoke the Skill tool with name `docs-curator:docs-curator`.** The plugin name and skill name match, so name resolution can pick up this slash command and re-invoke it, creating an infinite loop. Always load `SKILL.md` directly via `Read`.
