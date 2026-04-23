# team-review

> A persistent, project-level senior team that gets smarter about your project over time.

Not a one-shot review panel — a long-lived collective (8–12 senior members) proposed from deep project analysis on first use, then reused for every review in that project. Each member accumulates memory across reviews, so the team's understanding of *your* codebase compounds.

## Install

```
/plugin marketplace add https://github.com/wundam/skills
/plugin install team-review@wundam-skills
```

Reload your Claude Code session afterward.

## First use

Run `/team-review` with any task in a fresh project:

```
/team-review we need CSV export on the dashboard — scope and shape it
```

The skill detects there's no team yet and runs **deep analysis**:

```
No team found. Running deep analysis to propose one.

TEAM PROPOSAL
═══════════════════════════════════════════════════════════════
Project: your-project
Summary: <one line inferred from README + manifests>

Core (always): PM, Architect, UX, QA, Developer
Project-specific:
  - Mobile Engineer  — React Native + Expo detected
  - Database Engineer — Supabase + migrations/ directory
  - DevOps Engineer   — Dockerfile + .github/workflows detected

Signals: typescript, react-native, expo, supabase, github-actions

Proceed with this team? (yes / edit / reinit later)
```

On `yes`, the skill writes `<your-project>/.claude/team/` — commit it so teammates share the same team.

From then on, every `/team-review` call reuses this team.

## Review modes — both produce consensus

Pick by flag (or the skill will prompt):

### `--basic` — fast, single LLM

```
/team-review --basic auth flow breaks after password reset
```

The model sequentially voices each relevant member's position, identifies tensions between them, and works through the tensions until everyone is compatible. Max 5 passes. Cheap; good for everyday reviews.

### `--advanced` — parallel subagents, genuine debate

```
/team-review --advanced should we migrate from REST to GraphQL?
```

Each relevant member runs as an **isolated-context subagent** in parallel. Round 1 produces independent positions. Rounds 2+ show each member the others' arguments and ask them to hold or update. Max 5 rounds. Slower, more expensive, much more robust for architecture and design decisions.

Both modes end with a **consensus plan** and a dated log under `reviews/`. Every participating member gets a new dated note appended to their `members/<slug>.md`.

## All commands

| Invocation | What it does |
|---|---|
| `/team-review <task>` | Run a review. Prompts for mode if no flag. |
| `/team-review --basic <task>` | Force basic mode. |
| `/team-review --advanced <task>` | Force advanced mode. |
| `/team-review team` | Print the current roster + stats (no state change). |
| `/team-review add <role description>` | Propose and add a new member. Slug collisions handled. |
| `/team-review remove <slug>` | Archive a member. Notes preserved in `members/_archived/`. |
| `/team-review reinit` | Re-run deep analysis, show a diff against the current team, confirm, update. Notes carry forward for kept members. |

## State on disk

Everything the team remembers lives here, in your project, committable to git:

```
<your-project>/.claude/team/
├── team.json                            # roster + project metadata
├── context.md                           # shared project facts (stack, domain, constraints)
├── members/
│   ├── pm.md                            # one file per member; frontmatter + accumulating notes
│   ├── architect.md
│   ├── mobile-engineer.md
│   └── <slug>.md
├── members/_archived/                   # removed members; notes preserved
├── reviews/
│   └── <YYYY-MM-DD>-<task-slug>.md      # per-review transcript + consensus plan
└── .lock                                # present while a review runs (concurrency guard)
```

Each `members/<slug>.md` has YAML frontmatter (role, focus, surfaces) and a `# Notes` body that grows over time. When you do your 20th review, the Mobile Engineer remembers that last quarter you picked offline-first, that the barcode scanner is flaky on Android 12, and that Product is dead-set on sub-300ms touch latency.

## When to reach for which mode

| Situation | Mode |
|---|---|
| Quick bug triage | `--basic` |
| Small feature spec | `--basic` |
| Everyday code review | `--basic` |
| Architecture decision | `--advanced` |
| Breaking change | `--advanced` |
| Security-sensitive area | `--advanced` |
| "Should we do X at all?" | `--advanced` |

## FAQ

**Does the team ever shrink?**
Not automatically. The skill defaults to a broad roster on purpose — diverse perspectives catch more. Per review, only the relevant 4–7 members engage. If you truly want a leaner team, use `remove`.

**What if the debate doesn't converge?**
After 5 passes (basic) or 5 rounds (advanced) with unresolved non-accepted tensions, the skill surfaces the deadlock and asks you to moderate — pick a position, synthesize your own, or reject and restart.

**Can two sessions run `/team-review` on the same project at once?**
No — the `.lock` file serializes them. Stale locks (>30 min mtime) are ignored.

**Will my team file keep growing forever?**
Yes, on purpose — project memory is the whole point. When growth becomes friction, `reinit` rebuilds cleanly; notes are preserved for members that survive the diff and archived for ones dropped.

**Is my team shareable with collaborators?**
Yes — commit `.claude/team/` to git. All teammates get the same roster, context, and accumulated memory. Reviews run locally; the log files land in the same repo.

## Details

- Full skill orchestration: [`skills/team-review/SKILL.md`](skills/team-review/SKILL.md)
- State-file schemas: [`skills/team-review/references/schemas.md`](skills/team-review/references/schemas.md)
- Role catalog & signal mapping: [`skills/team-review/references/role-catalog.md`](skills/team-review/references/role-catalog.md)
- Deep analysis procedure: [`skills/team-review/references/deep-analysis.md`](skills/team-review/references/deep-analysis.md)
- Basic mode: [`skills/team-review/references/basic-mode.md`](skills/team-review/references/basic-mode.md)
- Advanced mode: [`skills/team-review/references/advanced-mode.md`](skills/team-review/references/advanced-mode.md)
- Lifecycle (reinit / add / remove / team): [`skills/team-review/references/lifecycle.md`](skills/team-review/references/lifecycle.md)
- Edge cases: [`skills/team-review/references/edge-cases.md`](skills/team-review/references/edge-cases.md)

## Versioning

Per-plugin semver. Git tag format: `team-review/vX.Y.Z`. See [`CHANGELOG.md`](CHANGELOG.md).

## License

MIT — see the marketplace's [LICENSE](../../LICENSE).
