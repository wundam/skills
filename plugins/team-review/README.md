# team-review

Assemble a virtual cross-functional team for a bug, feature, spec, or decision. The team investigates the code, identifies impact, and produces a consensus solution plan.

## Components

- **Skill:** `team-review` — activates when you ask for team-based analysis, review, or implementation planning.
- **Command:** `/team-review` — explicit entry point; paste a spec or bug report after the command.

## Usage

Install (replace `<marketplace-name>` with the `name` from [`.claude-plugin/marketplace.json`](../../.claude-plugin/marketplace.json)):

```
/plugin install team-review@<marketplace-name>
```

Invoke implicitly:

> I have a bug in the auth flow, can we get a team to look at it?

Invoke explicitly:

```
/team-review <paste spec / bug report / decision here>
```

## Phases

1. **Team Assembly** — suggests roles based on what the request touches; waits for user approval.
2. **Deep Dive & Solution Plan** — reads code, identifies root cause / design decisions, presents a consensus plan.
3. **Implementation Prompt Generation** — optional; produces a self-contained prompt another Claude session can execute.
