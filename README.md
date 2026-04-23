# wundam-skills

A public [Claude Code](https://docs.claude.com/claude-code) plugin marketplace by [wundam](https://wundam.com).

Each plugin bundles one install-decision worth of related skills, commands, or hooks — things you'd always want together. Currently one plugin (`team-review`), more over time.

## Install

```
/plugin marketplace add https://github.com/wundam/skills
/plugin install <plugin-name>@wundam-skills
```

Reload your Claude Code session afterward so the new skills and commands are picked up.

## Plugins

### `team-review` — v1.0.0

A **persistent, project-level senior team** stored under your project's `.claude/team/`. Not a one-shot review panel — a long-lived collective that grows in understanding across every review you run.

On first use in a project the skill runs deep analysis (reads READMEs, manifests, directory shape), proposes a broad senior roster, and writes state to `.claude/team/`. Subsequent reviews reuse the team and accumulate per-member memory.

**Roster** — 5 core (PM, Architect, UX, QA, Developer) plus project-inferred specialists (Mobile, Web, Database, LLM, DevOps, Security, Data, Game, Extension, CLI, or custom).

**Two review modes — both converge to consensus:**

- `/team-review --basic <task>` — single LLM voices members in sequence, resolves tensions up to 5 passes. Fast, cheap.
- `/team-review --advanced <task>` — parallel subagents per member debate across multiple rounds with isolated contexts. Slower, more expensive, more robust for high-stakes decisions.

**Lifecycle commands:**

| Command | Purpose |
|---|---|
| `/team-review <task>` | Run a review (prompts for mode). |
| `/team-review team` | Show the current roster. |
| `/team-review add <role description>` | Propose and add a new member. |
| `/team-review remove <slug>` | Archive a member (notes preserved). |
| `/team-review reinit` | Re-analyze the project; diff and update the roster. |

**Install:**

```
/plugin install team-review@wundam-skills
```

Full docs: [`plugins/team-review/README.md`](plugins/team-review/README.md) and [`plugins/team-review/skills/team-review/SKILL.md`](plugins/team-review/skills/team-review/SKILL.md).

## How it's organized

```
wundam-skills/
├── .claude-plugin/marketplace.json     # marketplace manifest
├── plugins/
│   └── <name>/
│       ├── .claude-plugin/plugin.json
│       ├── skills/<skill>/SKILL.md
│       ├── commands/<cmd>.md
│       ├── CHANGELOG.md
│       └── README.md
└── scripts/release.sh                   # per-plugin semver release tool
```

Each plugin is independently versioned with semver. Tags are namespaced: `team-review/v1.0.0`, `<next-plugin>/v0.1.0`, etc.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Repo layout
- Local development (register this repo as a local marketplace for iterative edits)
- Release workflow (`./scripts/release.sh <plugin> <patch|minor|major>` with strict `[Unreleased]` CHANGELOG gate)
- Running the release-script integration tests

## Fork for your own marketplace

When forking, update these config files — nothing else should need hand-editing:

- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — marketplace `name`, `description`, `owner.name`, `owner.url`
- `plugins/<plugin>/.claude-plugin/plugin.json` — plugin `author`, `description`
- [`LICENSE`](LICENSE) — copyright holder

Docs and skill prose are written generically; there is no hardcoded path to this specific repo.

## License

MIT — see [LICENSE](LICENSE).
