---
name: release
description: General-purpose release workflow. Version bump → changelog → commit → tag → push (requires user approval) → GitHub Release. Argument: patch/minor/major, or no argument for projects that use date-based tags.
disable-model-invocation: true
argument-hint: "[patch|minor|major]"
---
# Release Workflow

A project-agnostic release procedure. Running `/release` already states the intent to
release, but **push always requires explicit user approval** (global rule).

## Step 1: Pre-flight

1. `git branch --show-current` — must be main / master. If not, stop and confirm.
2. `git status` — show uncommitted changes and confirm whether they belong in the release.
3. Run tests (try each in order, use the first that exists): `just test` → `bun test` →
   `bun run test`. Stop on failure. If none of them exist, tell the user and ask whether
   to continue without tests.

## Step 2: Decide the version

- If `package.json` has a `version` field, bump it according to `$ARGUMENTS`
  (patch/minor/major, default patch). Edit it the way
  `npm version <type> --no-git-tag-version` would.
- If there is no version field (data/content repositories), use a date tag
  `vYYYY.MM.DD` (add a `-2` suffix for a second release on the same day).

## Step 3: Generate release notes

```bash
git log --pretty=format:"%s" $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD
```

Classify by Conventional Commits: feat → What's New / fix → Bug Fixes / refactor, perf →
Improvements / docs → Documentation / chore → Maintenance. Write in plain, user-facing
language, in the language the repository documents itself in.

## Step 4: Commit & tag

1. Commit the version change: `chore: bump version to vX.Y.Z` (no attribution — per
   global settings)
2. Annotated tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`

## Step 5: Push (user approval required)

A global hook blocks `git push`. **Stop here** and present the following to the user:

> Ready to push: <commit> + tag vX.Y.Z. Run `! git push origin main --follow-tags`, or
> reply "push it".

Push only after explicit approval. That approval covers this release only.

## Step 6: GitHub Release

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "<release notes>"
```

Report the Release URL. If the remote is not GitHub, skip this step and say so.

## On failure

Stop at the failed step → show the full error → propose a fix → ask the user whether to
continue. Tell the user that any tag created along the way can be rolled back with
`git tag -d`.
