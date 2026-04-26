# Findings Report Format

Render the audit report in this exact structure. Always present numbered items so the user can refer to them as `1,3,4`.

## Template

```
## Audit Findings — <project_type>, <mode>

### Non-standard files (<count>)
1. <path> — <reason>
2. ...

### Duplicates (<count>)
3. <path-a> + <path-b> — <description of overlap>

### Stale (<count>)
4. <path> — <stale reason: dead reference / code-doc skew>

### Missing standard (<count>)
5. <path or expectation> — <what's missing>

### Generation candidates (<count>)
6. <path> — <why a doc would help>

### Proposed actions
[low]   1, 2: <action: e.g., delete>
[low]   3:    stub <path-a>, point to <path-b>
[mid]   4:    rewrite <path> (diff to follow)
[low]   5:    create <path> from template
[mid]   6:    generate <path> (preview to follow)

Approve?
  → "all" (apply all; mid/high still show diff/plan)
  → "low" (apply only low batch)
  → "1,3,5" (specific items)
  → "skip" (apply nothing; mark as accepted-as-is)
  → "cancel" (do nothing; re-prompt next audit)
```

## Rules

- Empty categories: omit the section entirely (don't show `Non-standard files (0)`).
- Always show item indices globally — `1, 2, 3` across all categories — so user can pick by number.
- Action tags: `[low]`, `[mid]`, `[high]` per `risk-tiers.md`.
- For mid/high: do not show the diff/plan in the report itself; promise it ("diff to follow") and present per-item during apply.
- After listing actions, always show the approval menu verbatim.

## Clean audit (zero findings)

If after Step 6 (memory filter) every category is empty, do not emit empty section headers and a hanging approval menu — that's confusing UX. Emit a single-line positive confirmation instead so the user knows the audit ran:

```
docs-curator: ✓ Clean audit — <project_type>, <mode> mode. <count> files inventoried, 0 findings.
```

Then proceed directly to Step 8 to refresh `last_audit_at`, `last_audit_state_hash`, and `last_audit_head` in `.claude/docs-state.json` — there are no actions to apply, but the bookkeeping update keeps the next incremental audit accurate.

For first-run mode with zero critical findings, use the baseline-establishment template in `references/first-run.md` instead — it's already a clean-audit confirmation tailored to that case.

## Approval handling

- `all` → apply all listed actions; for mid/high, prompt with diff/plan one at a time.
- `low` → apply only the `[low]`-tagged batch.
- Specific list (e.g., `1,3,5`) → apply those item indices; for mid/high among them, diff per item.
- `skip` → apply nothing, but add each finding's path to `state.memory.specific` so it isn't re-flagged.
- `cancel` → apply nothing, do not update memory; re-prompt next audit.

If the user gives an unexpected response, ask once: "Sorry, I didn't understand. Please reply with one of: all / low / numbered list / skip / cancel."
