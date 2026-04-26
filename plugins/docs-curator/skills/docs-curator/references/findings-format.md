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

## Approval handling

- `all` → apply all listed actions; for mid/high, prompt with diff/plan one at a time.
- `low` → apply only the `[low]`-tagged batch.
- Specific list (e.g., `1,3,5`) → apply those item indices; for mid/high among them, diff per item.
- `skip` → apply nothing, but add each finding's path to `state.memory.specific` so it isn't re-flagged.
- `cancel` → apply nothing, do not update memory; re-prompt next audit.

If the user gives an unexpected response, ask once: "Sorry, I didn't understand. Please reply with one of: all / low / numbered list / skip / cancel."
