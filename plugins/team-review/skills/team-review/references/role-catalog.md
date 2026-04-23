# Role catalog

Used by the skill to propose and maintain a project's team.

## Core roles (always included, `tier: core`)

The team always contains exactly these five members. They are added on first analysis and are never proposed for removal automatically (user can still remove with a strong warning).

### `pm` — Product Manager
- **Focus:** vision alignment, scope control, prioritization, trade-off between user value and engineering cost.
- **Surfaces:** roadmap documents, changelogs, release notes, user-facing documentation, feature-flag configuration.

### `architect` — System Architect
- **Focus:** module boundaries, cross-cutting impact, dependency direction, packaging surface, layer-defense parity, migration/compatibility.
- **Surfaces:** top-level entry points, package manifests, barrel files, migration scripts, build configuration, verification scripts.

### `ux` — UX Designer
- **Focus:** user flow, affordance clarity, error-message tone, onboarding friction, accessibility, information density.
- **Surfaces:** UI component files, routes, forms, error-handling copy, onboarding/setup flows, public-facing copy.

### `qa` — QA Engineer
- **Focus:** test gaps, regression risk, guard coverage, verification steps, reproduction recipes, non-happy-path behavior.
- **Surfaces:** test directories, verification scripts, CI config, feature-flag gates, error paths.

### `developer` — Software Developer (generalist)
- **Focus:** correctness of the proposed implementation, code readability, alignment with existing patterns, incremental delivery.
- **Surfaces:** the module(s) directly affected by the task, adjacent call sites, test co-location.

## Project roles (signal-inferred, `tier: project`)

The deep-analysis procedure maps detected project signals to project roles. A role is added when at least one mapping rule fires. Multiple signals for the same role do not duplicate the member; they contribute reasons.

| Signal pattern (from deep analysis) | Added role slug | Role display name | Default focus headline |
|---|---|---|---|
| `react-native`, `expo`, iOS or Android build directories, `Podfile`, `app.json` | `mobile-engineer` | Mobile Engineer | offline behavior, touch targets, native integration |
| `next`, `vite`, `react`, `vue`, `svelte`, `@angular/core`, web-route directories | `web-engineer` | Web Engineer | rendering strategy, routing, bundle size |
| `supabase`, `prisma`, `drizzle`, migrations directory, `*.sql` files | `database-engineer` | Database / SQL Engineer | schema design, migration safety, query performance |
| `openai`, `@anthropic-ai/sdk`, `@google/generative-ai`, `langchain`, prompt files | `llm-engineer` | LLM Engineer | prompt design, token budgets, evaluation, streaming |
| `Dockerfile`, `fly.toml`, `*.yml` under `.github/workflows/`, `Procfile`, k8s manifests | `devops-engineer` | DevOps / Platform Engineer | deployment, CI, observability, rollout strategy |
| `oauth`, `passport`, `auth.js`, session/middleware directories, JWT libraries | `security-engineer` | Security / Identity Engineer | authn/authz, session handling, secret hygiene |
| `.ipynb`, `pandas`, `numpy`, `data/` directory, `ml/` directory | `data-engineer` | Data / ML Engineer | data pipelines, training/eval loops, reproducibility |
| Unity project files, Unreal `.uproject`, Godot `project.godot` | `game-engineer` | Game Engineer | performance budgets, scene hierarchy, input handling |
| `vscode-extension/`, IntelliJ plugin manifest, `manifest.json` for browser extensions | `extension-engineer` | Extension Engineer | host-IDE APIs, activation events, permissions |
| CLI-first structure: `bin/`, `cli/`, `commander`, `yargs`, `clap` | `cli-engineer` | CLI Engineer | argument surface, error messages, exit codes, composability |

**Extensibility rule:** The deep-analysis layer is allowed to propose roles outside this table when a compelling signal is detected. It must always provide a `reason`. Example: an uncommon simulation engine justifies a `simulation-engineer` role.

## Slug convention

- Slugs are kebab-case.
- Slugs never contain the word `agent` to avoid confusion with Claude Code subagents.
- If a user's `add` description produces a slug collision, append a monotonically increasing suffix (`-2`, `-3`) OR prompt the user to rename / extend the existing member.
