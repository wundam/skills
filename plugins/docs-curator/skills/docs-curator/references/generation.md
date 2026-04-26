# Generation Triggers and Process

`generate` is a mid-risk action that proposes a new doc draft based on code analysis. Always with preview; never silent.

## When to generate

Three trigger types:

### Trigger 1: New folder without README

A folder added (working tree or recent commit window) that contains ≥3 source files, with no README at the folder itself or any ancestor up to the project root.

What to generate: `<folder>/README.md` with:
- 1-2 sentence purpose (inferred from code)
- File listing with one-line descriptions
- Usage example if entry points are detected

### Trigger 2: Architectural change without ADR

In the last N commits (default 10, configurable via `stale_window`), there's a "significant architectural change" — defined as any of:
- A top-level directory added or removed
- A directory renamed (≥3 files moved together)
- A module's exports changed substantially (signatures, removed public symbols)

If `docs/adr/` exists and no ADR was added in the same commit window, propose generating an ADR.

What to generate: `docs/adr/NNNN-<topic>.md` using a standard ADR template:
```
# ADR-NNNN: <Title>

## Status
Proposed

## Context
<Why this change was needed, inferred from code+commits>

## Decision
<What was changed>

## Consequences
<Trade-offs, inferred from the diff>
```

Determine the next number by reading existing ADRs (highest existing number + 1).

### Trigger 3: Plugin/package missing required doc

When project type detection (per `project-types.md`) flags a missing required file, propose generating it.

For `README.md`: minimal scaffold with project name, one-line description (inferred from code/manifests), install/usage if obvious.

For `CHANGELOG.md`: minimal scaffold with `## [Unreleased]` section only.

## Process

For each generation candidate:

1. Read the relevant source files (limit scope: only the candidate's directory and direct neighbors).
2. Draft the doc using your judgment.
3. Present the full content as a `[mid]` action: "generate <path> (preview to follow)".
4. When the user reaches this in the approval flow, show the full file content.
5. Ask: "Apply (y/n/skip)?".
6. On `y`, write the file with `Write` tool, `git add` it, do not commit.

## Limits

- Never generate more than 3 docs per audit run. If more candidates exist, generate the top 3 (by relevance) and report the rest as "deferred — re-run audit after these are accepted".
- Never generate inside `docs/adr/` more than 1 ADR per audit run — ADRs deserve human framing.
- Never generate a doc that would shadow an existing one (duplicate path).
