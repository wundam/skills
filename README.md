# Skills Marketplace

A personal Claude Code plugin marketplace. Each plugin bundles one install-decision worth of related skills, agents, commands, or hooks.

Marketplace name and owner are defined in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json). Substitute `<marketplace-name>` with that file's `name` field in the commands below.

## Install from local disk

Substitute `<repo-path>` with the absolute path to this repo on your machine:

```
/plugin marketplace add <repo-path>
/plugin install <plugin-name>@<marketplace-name>
```

## Install from GitHub (once published)

```
/plugin marketplace add <github-url>
/plugin install <plugin-name>@<marketplace-name>
```

## Available plugins

See [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json).

## Customize for your own marketplace

When forking, update these config files — nothing else should need hand-editing:

- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — marketplace `name`, `description`, `owner.name`, `owner.url`
- `plugins/<plugin>/.claude-plugin/plugin.json` — plugin `author`, `description`
- [`LICENSE`](LICENSE) — copyright holder

## Contributing / releasing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
