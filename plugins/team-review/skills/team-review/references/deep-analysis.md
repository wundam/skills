# Deep project analysis

Runs on first use (no `team.json` exists) and on `/team-review reinit`. Produces two artifacts: the `project.signals` list (fed into `team.json`) and the `context.md` content.

## Procedure

### Step A — Read the obvious documents

Read, in order, as many of the following as exist. Missing files are fine.

- `README.md`, `README`, `README.rst`
- `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`
- `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Gemfile`, `*.csproj`, `Podfile`, `pubspec.yaml`, `mix.exs`, `composer.json`
- `docker-compose.yml`, `Dockerfile`, `fly.toml`, `Procfile`
- `tsconfig.json`, `app.json` (Expo), `next.config.*`, `vite.config.*`, `astro.config.*`, `svelte.config.*`, `nuxt.config.*`
- `supabase/config.toml`, `prisma/schema.prisma`, `drizzle.config.ts`

Record the project name (from manifest or repo directory name) and a one-paragraph summary (from the README's opening).

### Step B — List the top-level directory structure

One level deep. Note the presence of telltale directories: `app/`, `src/`, `api/`, `routes/`, `mobile/`, `ios/`, `android/`, `db/`, `migrations/`, `schema/`, `prompts/`, `tests/`, `e2e/`, `data/`, `ml/`, `notebooks/`, `vscode-extension/`, `bin/`, `cli/`, `.github/workflows/`.

### Step C — Emit signals

A signal is a single kebab-case string token. Add a signal when evidence is unambiguous. Common signals:

- Language: `typescript`, `javascript`, `python`, `rust`, `go`, `swift`, `kotlin`, `ruby`, `php`, `elixir`, `java`, `csharp`.
- Framework: `next`, `nuxt`, `sveltekit`, `astro`, `react`, `vue`, `svelte`, `angular`, `react-native`, `expo`, `flutter`, `rails`, `django`, `fastapi`, `express`, `nestjs`, `laravel`, `spring`.
- Storage: `supabase`, `prisma`, `drizzle`, `sequelize`, `postgres`, `mysql`, `mongodb`, `sqlite`, `redis`.
- LLM: `openai`, `anthropic`, `google-generative-ai`, `langchain`, `llamaindex`.
- Infra: `docker`, `fly-io`, `vercel`, `netlify`, `aws-lambda`, `kubernetes`, `github-actions`.
- Domain: `mobile`, `web`, `cli`, `ide-extension`, `browser-extension`, `game`, `data-pipeline`, `ml-training`.

Signals are advisory — never load-bearing at review time. They justify role selection and feed `context.md`.

### Step D — Map signals to project roles

Consult `references/role-catalog.md`. For each signal that fires a mapping rule, add the corresponding role slug. Record a `reason` on the member entry so the user can audit the choice.

Multiple signals may justify the same role — the member is added once, but the reason can merge: `"React Native + Expo detected"`.

### Step E — Present proposal to the user

Format:

```
TEAM PROPOSAL
════════════════════════════════════════════════════════════════

Project: <name>
Summary: <one line>

Core (always): PM, Architect, UX, QA, Developer

Project-specific (inferred from signals):
  - Mobile Engineer — React Native + Expo detected
  - Database Engineer — Supabase + migrations/ directory
  - ...

Signals: typescript, react-native, expo, supabase, github-actions, ...

════════════════════════════════════════════════════════════════

Proceed with this team? (yes / edit / reinit later)
```

If the user replies `edit`, accept free-form changes and revise. Confirm before writing files.

### Step F — Write state

On approval:

1. Create directory `<project>/.claude/team/` and subdirectories `members/`, `members/_archived/`, `reviews/`.
2. Render `templates/team.json.tmpl` → `<project>/.claude/team/team.json` with substitutions.
3. Render `templates/context.md.tmpl` → `<project>/.claude/team/context.md`. The `Stack & tooling` / `Domain & audience` / `Constraints & priorities` bullets are populated from the analysis; if the skill cannot infer them confidently, it asks the user one clarifying question per missing field.
4. For each team member, render `templates/member.md.tmpl` → `<project>/.claude/team/members/<slug>.md`. The `focus` and `surfaces` fields come from `references/role-catalog.md` for core roles; project-role fields are computed from the signals that justified the role.

**Substitution contract for multi-bullet placeholders:** `{{ STACK_BULLETS }}`, `{{ CONSTRAINTS_BULLETS }}`, `{{ FOCUS_BULLETS }}`, and `{{ SURFACE_BULLETS }}` expand to the complete bullet block including the leading `- ` prefix for each line. For `FOCUS_BULLETS` and `SURFACE_BULLETS` (inside YAML frontmatter), each bullet must be indented with two spaces (`  - concern 1\n  - concern 2`). For `STACK_BULLETS` and `CONSTRAINTS_BULLETS` (plain markdown), no indentation (`- Stack item 1\n- Stack item 2`).

## Empty-project fallback

If fewer than two signals are produced (e.g., a brand-new repo containing only a README), the skill asks the user one question:

> "I couldn't detect enough project signals. In one sentence: what is this project building, and for whom?"

The answer is used to populate `context.md`. Only core members are added. A note on the final proposal: `"Reinit recommended once the codebase takes shape."`
