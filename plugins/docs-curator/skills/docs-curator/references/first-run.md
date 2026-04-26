# First-Run Behavior

When `state.baseline_set` is `false` (no state file or fresh `reset`), enter first-run mode. Goal: avoid overwhelming the user when installing into a messy project.

## Rules

1. Detect project type (per `project-types.md`).
2. Run full inventory (per Step 4 of `SKILL.md`).
3. Build findings as usual but emit only **critical** findings:
   - Files matching the strict blacklist (`NOTES.md`, `TODO.md`, `REVIEW.md`, etc.) at root
   - Multiple READMEs at the same level
   - Missing required files for the detected project type (e.g., plugin missing CHANGELOG)
4. **Suppress** these categories on first run:
   - Duplicate detection
   - Stale detection (both code-reference and code-doc skew)
   - Generation candidates
   - Ad-hoc subfolder README
5. Mark all currently-existing markdown files (except those flagged in step 3) as accepted-as-is by adding their paths to `memory.specific`.
6. Set `state.baseline_set = true`.
7. Inform the user:

```
docs-curator: Baseline established for this project.
- Project type: <type>
- Markdown files inventoried: <count>
- Accepted as-is (added to memory): <count>
- Critical findings to address now: <count>

For a deep audit at any time: /docs-curator full
```

## Why this design

A fresh install into a project with 50+ markdown files would otherwise produce a 30-finding flood. Most users would dismiss it and uninstall. Baseline mode means the user only sees clear violations on first run. They can opt into the full audit when they're ready.

## Future audits

After first run, all subsequent audits run incrementally (only changed files since `last_audit_head`).

**Baseline is sticky.** The paths added to `memory.specific` during first run are suppressed from *all* rule checks (duplicate detection, stale detection, etc.) — even if those files later change. This is by design: "accepted as-is" means accepted, not "accepted until next edit". To re-evaluate a single baselined file, remove its path from `memory.specific` in `.claude/docs-state.json` and run `/docs-curator`. To wipe baseline entirely and treat the project as fresh, run `/docs-curator reset`. `/docs-curator full` lifts the first-run *rule suppressions* (so duplicate/stale/generation rules run) but it still respects `memory.specific`, so already-baselined files stay suppressed.

## Edge cases

- **Empty project:** No markdown files; `state.baseline_set = true`, no findings, inform user.
- **Single file project:** Same flow; inventory is small but baseline mode still applies.
- **Reset:** `/docs-curator reset` deletes the state file and re-enters first-run mode. Memory is wiped along with state.
