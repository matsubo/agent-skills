# agent-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Personal [Agent Skills](https://agentskills.io/specification) for Claude Code,
distributed as a plugin marketplace.

Skills are namespaced under `matsubo`, so they are invoked as `/matsubo:<skill>`.

## Install

```
/plugin marketplace add matsubo/agent-skills
/plugin install matsubo@matsubo-agent-skills
```

## Skills

| Skill | Invoke | Description |
|-------|--------|-------------|
| `npm-dependency-updates` | model-invoked, or `/matsubo:npm-dependency-updates` | Update npm/bun dependencies to latest with npm-check-updates, then fix the breaking changes major bumps introduce. |
| `bundler-dependency-updates` | model-invoked, or `/matsubo:bundler-dependency-updates` | Update Ruby gems to latest with `bundle update`, then fix the breaking changes major bumps introduce. Handles Docker Compose projects. |
| `release` | `/matsubo:release [patch\|minor\|major]` | Version bump → release notes → commit → tag → push (with approval) → GitHub Release. |

## Layout

```
.claude-plugin/
  marketplace.json          # marketplace + plugin definition; "name": "matsubo" sets the namespace
skills/
  <skill>/SKILL.md          # one directory per skill
evals/
  run-trigger-eval.sh       # measures how reliably a description triggers
  fixture/                  # throwaway polyglot project each eval query runs against
  <skill>/*_queries.json    # labelled prompts, split into train and validation sets
```

## Adding a skill

Create `skills/<name>/SKILL.md`, then add `"./skills/<name>"` to the `skills` array in
`.claude-plugin/marketplace.json`.

Conventions, following the [Agent Skills specification](https://agentskills.io/specification)
and [best practices](https://agentskills.io/skill-creation/best-practices):

- **`name`** must match the directory name: 1-64 characters, lowercase letters, numbers and
  single hyphens. Prefer a noun phrase over an abbreviation. Scope a skill to its ecosystem
  when siblings exist (`npm-dependency-updates` and `bundler-dependency-updates`) so the two
  do not compete for the same prompts, and say in each `description` which ecosystems the
  skill does *not* cover.
- **`description`** carries the entire triggering burden — it is all the agent sees until the
  skill loads. Say both what the skill does and when to use it, in imperative phrasing, with
  the words a user would actually type. State the boundary too when a near-miss skill exists.
  Max 1024 characters.
- **`license`** and **`compatibility`** are optional spec fields. Use `compatibility` only for
  real environment requirements (required binaries, network access).
- **Body** stays under 500 lines and roughly 5,000 tokens; move anything longer into
  `references/`, one level deep, and say *when* to read it.
- Write only what the agent would otherwise get wrong. A `## Gotchas` section of
  environment-specific facts is usually the highest-value part of a skill.
- Skills are installed by other people: never rely on the author's own hooks, global settings,
  or machine.

Validate before committing:

```
claude plugin validate . --strict
claude plugin validate ./skills --strict
```

## Evals

`evals/` measures whether a skill's `description` triggers on the prompts it should, and
stays quiet on near-misses that belong to a sibling skill.

```
./evals/run-trigger-eval.sh evals/npm-dependency-updates/train_queries.json npm-dependency-updates
./evals/run-trigger-eval.sh evals/bundler-dependency-updates/train_queries.json bundler-dependency-updates
```

Tune the description against the train set only, then check the validation set to confirm the
change generalized rather than overfitting. `RUNS`, `THRESHOLD`, `TIMEOUT` and `MODEL` are
environment variables.

Each query runs against a fresh copy of `evals/fixture/`, a small project carrying a
`package.json`, a `Gemfile` and a `requirements.txt` at once. An empty directory does not
work — the agent spends the run establishing that there is nothing to act on and never
reaches the task — and the repository itself would bias the result. The mixed ecosystems are
what make the cross-ecosystem negatives answerable rather than nonsense.

## Publishing

[skills.sh](https://skills.sh/) indexes this format and resolves skills straight from GitHub,
so anyone can install from this repository without the Claude Code marketplace:

```
npx skills add matsubo/agent-skills
npx skills add matsubo/agent-skills --list    # what the registry sees
```

The leaderboard is built from install telemetry rather than a submission form, so a repository
appears at `https://skills.sh/<owner>/<repo>` once it has been installed through the CLI.
Run `--list` after any frontmatter change: the registry parses YAML more strictly than
`claude plugin validate` does, and silently skips a skill whose frontmatter fails to parse.

## License

MIT — see [LICENSE](LICENSE). Each `SKILL.md` also carries `license: MIT` in its frontmatter,
so the terms travel with the skill when it is copied out of this repository.
