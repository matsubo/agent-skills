# agent-skills

[![audit](https://github.com/matsubo/agent-skills/actions/workflows/audit.yml/badge.svg)](https://github.com/matsubo/agent-skills/actions/workflows/audit.yml)
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
| `github-actions-workflows` | model-invoked, or `/matsubo:github-actions-workflows` | Author `.github/workflows/` using action versions looked up from the API, never recalled. Bundles a version-lookup script. |
| `release` | `/matsubo:release [patch\|minor\|major]` | Version bump → release notes → commit → tag → push (with approval) → GitHub Release. |

## Safety

A skill is not a library. It is plain-text instructions that your agent reads and then acts
on — with your credentials, in your repository. Installing one is closer to running a shell
script than to adding a dependency, so the useful question is not "is this safe?" but "what
is enforced, and what still needs my eyes?"

**Enforced automatically on every push and pull request.** This is what the badge above
reports; the full check list is under [Audit](#audit).

- No instruction to run `rm -rf`, pipe a remote script into a shell or interpreter, force
  push, escalate with `sudo`, or disable the agent's permission prompts.
- No text that a reviewer cannot see but a model still reads: HTML comments, zero-width
  characters, bidirectional overrides.
- No credential literals, plus a [gitleaks](https://github.com/gitleaks/gitleaks) scan over
  the full history.
- Frontmatter conforms to the [specification](https://agentskills.io/specification), and
  `marketplace.json` cannot drift out of step with `skills/`.

**True of the skills here today**, and checkable in one `grep` each:

- Only `release` pushes at all, and it stops and asks first — see Step 5 of
  `skills/release/SKILL.md`. The dependency-update skills commit; they never push.
- The only network access from a bundled script is read-only `GET`s to `api.github.com`.

**What none of that proves.** The audit is a deny list of known-bad patterns, not a proof of
good behaviour, and it is worth being precise about the gap:

- A harmful instruction written in plain prose passes every pattern. "Delete the branch and
  make the remote match" contains nothing to grep for.
- It checks the text, not the outcome. These skills exist to run `bundle update`,
  `npm-check-updates -u` and `git commit` — commands that change your project by design.
- It says nothing about the third-party tools the skills invoke: Bundler, ncu, `gh`.
- The trigger evals are not part of CI, so a description can still fire on a prompt you did
  not mean it to.

**So verify it yourself.** Each skill is one Markdown file of under 150 lines, and
`github-actions-workflows` bundles a shell script besides. Reading the one you are about to
install takes a couple of minutes and is worth more than any badge.
The audit needs no API key or network access to a model, so it also runs on your own clone:

```
git clone https://github.com/matsubo/agent-skills && cd agent-skills
just audit
```

## Layout

```
.claude-plugin/
  marketplace.json          # marketplace + plugin definition; "name": "matsubo" sets the namespace
skills/
  <skill>/SKILL.md          # one directory per skill
  <skill>/scripts/          # executables the skill runs (never loaded into context)
evals/
  run-trigger-eval.sh       # measures how reliably a description triggers
  fixture/<ecosystem>/      # throwaway project each eval query runs against
  <skill>/*_queries.json    # labelled prompts, split into train and validation sets
scripts/
  audit.sh                  # the safety gate; everything CI enforces
  check-frontmatter.py      # spec conformance of one SKILL.md
  check-hidden-chars.py     # characters a reviewer cannot see
tests/
  audit_test.sh             # proves each audit check still fires
.github/workflows/audit.yml # runs the above on every push and pull request
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
just ci
```

## Audit

A skill is instructions that an agent executes on someone else's machine, and the only thing
standing between a change and that machine is someone reading a diff. `scripts/audit.sh` is
what makes that review enforceable. It is deterministic, needs no API key, and runs on every
push and pull request via `.github/workflows/audit.yml`.

```
just audit      # the gate
just test       # prove the gate still detects what it claims to
just ci         # both, plus claude plugin validate
```

What it checks:

| Check | Catches |
|-------|---------|
| `frontmatter-parse`, `name-*`, `description-*` | frontmatter that violates the spec |
| `body-length` | a SKILL.md past the 500 line budget |
| `marketplace-orphan`, `marketplace-missing` | `marketplace.json` and `skills/` disagreeing |
| `dangerous-pattern` | `rm -rf`, `curl \| sh` and `curl \| python3`, force push, `sudo`, `chmod 777`, `--dangerously-skip-permissions`, `eval $(curl …)` |
| `hidden-instruction` | HTML comments, zero-width characters, bidi overrides — text a model reads but a reviewer cannot see |
| `secret-literal` | a credential shaped like an API key |
| `script-not-executable` | a bundled script that would fail for whoever installs it |
| `eval-json`, `eval-query-schema`, `eval-fixture` | eval sets that would silently score zero |

The content checks cover every `*.md` and `*.sh` under `skills/`, not just `SKILL.md` — a
`references/` file ships to installers and is read by the model just as the SKILL.md is.

**`claude plugin validate --strict` is not sufficient on its own.** Measured against
deliberately broken skills, it rejects a missing frontmatter block, unparseable YAML and a
missing `description` — but it *accepts* a missing `name`, a `name` that violates the
specification's charset, a `name` that disagrees with its directory, and a `description` of
any length. `scripts/audit.sh` checks those itself; CI still runs `validate` as defence in
depth.

Two rules for changing the audit, both learned the hard way:

- **Every check needs a fixture that violates exactly one rule.** `tests/audit_test.sh`
  asserts on the *check id*, not just on a non-zero exit, so a case cannot pass because some
  unrelated check happened to fire.
- **Every pattern needs a near-miss that must stay silent.** `git push origin main
  --follow-tags` and `curl … | jq` are legitimate and appear in the skills here; an earlier
  pipe-to-shell pattern also missed `` `curl … | bash` `` written inside inline backticks,
  because it required whitespace after the shell name. Both directions are tested.

The workflow pins every action to a commit SHA rather than a tag, since a tag can be
repointed by its owner without any diff here; Dependabot moves the SHA and its `# vX.Y.Z`
comment together.

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

Each query runs against a fresh copy of `evals/fixture/<ecosystem>/`, chosen from the first
segment of the skill name, so `npm-dependency-updates` runs against `evals/fixture/npm`. Pass
a third argument to override it. Two constraints on that fixture were measured rather than
assumed:

- An empty directory scores 0 for every query. The agent spends the run establishing that
  there is no project to act on and never reaches the task.
- A single fixture holding several ecosystems at once also scores 0 on generic prompts such
  as "bring the deps up to date", because the agent stops to work out which ecosystem is
  meant. Hence one single-ecosystem fixture per skill.

Model behaviour is nondeterministic, so read the trigger rate rather than a single outcome.
Keep `RUNS` at 3 or more before drawing any conclusion about a description.

The evals are deliberately **not** part of CI: they need an API key and cost money per run,
and a gate that is read as a rate over repeated runs is not a gate. Run them locally with
`just eval <skill>` (add `validation` as a second argument for the validation set).

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
