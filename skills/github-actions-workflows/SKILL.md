---
name: github-actions-workflows
description: >-
  Write or edit GitHub Actions workflow files using the action versions that are current right
  now, looked up from the GitHub API rather than recalled — any version written from memory is
  stale. Use when creating or changing a file under .github/workflows/, adding a CI, build or
  release job, porting CI from another provider, or when a run fails because an action version
  is deprecated or its inputs moved. Covers choosing `uses:` refs, runner labels, and
  Dependabot upkeep. This skill is not a security reviewer: for script injection,
  pull_request_target, fork permissions or GITHUB_TOKEN scopes, it does not apply.
license: MIT
compatibility: Requires the gh CLI (or curl and jq) and network access to api.github.com
---

# GitHub Actions Workflows

## The problem this exists for

A model's memory of action versions is frozen at its training cutoff, so writing
`actions/checkout@v4` from recall *feels* correct and is silently years stale. Version
numbers are the one thing in a workflow you must never write from memory.

Never type a version you did not look up in this session. That includes versions copied from
an existing workflow in the repository — those are exactly as stale as the file is old.

## Workflow

- [ ] Step 1: List the actions the job needs
- [ ] Step 2: Look up their current versions
- [ ] Step 3: Write the workflow using only looked-up versions
- [ ] Step 4: Validate
- [ ] Step 5: Set up Dependabot so it stays current

### Step 1: List the actions the job needs

Decide the steps first, as bare action names with no version: `actions/checkout`,
`actions/setup-node`, `actions/cache`. Include any already present in the file you are
editing — they need re-checking too.

### Step 2: Look up their current versions

One call, all of them at once:

```bash
scripts/latest-action-versions.sh actions/checkout actions/setup-node actions/cache
```

```
action              major  exact     major_ref
actions/checkout    v7     v7.0.1    tag
actions/setup-node  v7     v7.0.0    tag
actions/cache       v6     v6.1.0    tag
```

Read `major_ref` before choosing what to write — it is why this script exists rather than a
plain API call:

| `major_ref` | What `@<major>` really is | Write |
|---|---|---|
| `tag` | a moving major tag, republished on each release | `@v7` |
| `branch` | a branch, exactly as mutable as `@main` | `@v1.321.0`, or a SHA |
| `none` | no moving major ref exists | `@v1.321.0` |

`ruby/setup-ruby@v1` is the trap: it is a *branch*, so it is mutable in the way `@main` is,
while looking like an ordinary pinned major.

### Step 3: Write the workflow

- **First-party** (`actions/*`, `github/*`) with `major_ref: tag` → the major tag: `@v7`.
- **Everything third-party** → a full 40-character commit SHA with the version in a trailing
  comment, because tags and branches can be moved under you by a compromised upstream:

  ```yaml
  - uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a # v7.3.0
  ```

  ```bash
  gh api repos/docker/build-push-action/git/ref/tags/v7.3.0 --jq '.object.sha'
  ```

- **Runner labels go stale too.** `ubuntu-latest` moves on its own and is fine for most jobs.
  Pin only when the job depends on the image contents, and then look up which labels exist
  rather than guessing — `ubuntu-24.04` was not always the current one.
- **Language versions** in `setup-*` steps come from the project (`.node-version`,
  `.ruby-version`, `package.json` `engines`), not from memory. Prefer
  `node-version-file: .node-version` over a literal so there is one source of truth.

### Step 4: Validate

```bash
actionlint .github/workflows/*.yml   # brew install actionlint
```

`actionlint` catches expression, matrix and shell errors that only surface on a push. It does
not check whether a version is current — that is Step 2's job.

Then self-check that nothing stale survived, including in parts of the file you did not
touch:

```bash
grep -ohE 'uses: *[^ ]+' .github/workflows/*.yml | sort -u
```

Every line must match a version from Step 2, or a SHA with a version comment. If one does
not, go back to Step 2 for it. Do not skip this because you only edited one job — a stale
`uses:` elsewhere in the file is still a stale workflow.

### Step 5: Keep it current

Looking versions up once fixes today only. Add `.github/dependabot.yml` so the repository
maintains them:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

`directory: "/"` is correct even though the workflows live in `.github/workflows/` —
Dependabot resolves that itself. If the file already exists, add this entry rather than
replacing what is there.

## Gotchas

- **A green workflow is not a current one.** Deprecated actions keep working for a long time
  before they are shut off, so "it passes" says nothing about whether the version is
  supported. Only the lookup does.
- **SHA-pinned actions look current forever.** A SHA never warns and never expires. The
  trailing `# v7.3.0` comment is the only thing that makes staleness visible to a human or to
  Dependabot — a pinned SHA without it is unmaintainable.
- **`::set-output` and `::save-state` were removed.** Write to `$GITHUB_OUTPUT` and
  `$GITHUB_STATE`. If a workflow still uses the old syntax, it is old enough that every
  version in it needs re-checking.
- **A major bump can move inputs, not just internals.** After bumping, read that action's
  release notes for the majors you skipped rather than assuming the `with:` block still fits.

## Verifying it actually runs

```bash
gh workflow list
gh run watch          # follow the current run
gh run view --log-failed
```
