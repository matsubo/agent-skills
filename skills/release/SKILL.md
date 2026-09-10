---
name: release
description: >-
  Cut a release: bump the version, generate release notes from the commit log, commit, tag,
  push after explicit approval, and publish a GitHub Release. Use when the user asks to
  release, ship, tag, or publish a new version. Takes patch/minor/major, or no argument for
  projects that version by date.
license: MIT
compatibility: Requires git; the GitHub Release step also requires the gh CLI and a GitHub remote
disable-model-invocation: true
argument-hint: "[patch|minor|major]"
---

# Release Workflow

A project-agnostic release procedure.

**Never run `git push` without explicit user approval.** Invoking this skill authorizes the
release; it does not authorize the push. Step 5 is a hard stop.

Progress:

- [ ] Step 1: Pre-flight (branch, working tree, tests)
- [ ] Step 2: Decide the version
- [ ] Step 3: Generate release notes
- [ ] Step 4: Commit and tag
- [ ] Step 5: Push — stop and ask
- [ ] Step 6: GitHub Release

## Step 1: Pre-flight

1. `git branch --show-current` — must be main or master. If not, stop and confirm.
2. `git status` — show uncommitted changes and confirm whether they belong in the release.
3. Run the test suite, using the first of these that exists: `just test`, `bun test`,
   `bun run test`. Stop on failure. If none exist, say so and ask whether to continue
   without tests.

## Step 2: Decide the version

- If `package.json` has a `version` field, bump it according to `$ARGUMENTS`
  (patch/minor/major, default patch). Edit it the way
  `npm version <type> --no-git-tag-version` would.
- If there is no version field (data or content repositories), use a date tag
  `vYYYY.MM.DD`, adding a `-2` suffix for a second release on the same day.

## Step 3: Generate release notes

```bash
git log --pretty=format:"%s" $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD
```

Group the subjects by Conventional Commit type: feat → What's New, fix → Bug Fixes,
refactor and perf → Improvements, docs → Documentation, chore → Maintenance. Rewrite each
one as plain, user-facing prose, in the language the repository documents itself in.

## Step 4: Commit and tag

```bash
git commit -m "chore: bump version to vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

Follow the repository's own commit message conventions if they differ.

## Step 5: Push — stop and ask

Stop here and present this to the user:

> Ready to push: <commit> + tag vX.Y.Z. Run `git push origin main --follow-tags`, or reply
> "push it" and I will run it.

Push only after explicit approval, and treat that approval as covering this release only.

## Step 6: GitHub Release

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "<release notes from Step 3>"
```

Report the Release URL. If the remote is not GitHub, skip this step and say so.

## Gotchas

- **`git push --follow-tags` pushes annotated tags only.** That is why Step 4 uses
  `git tag -a` rather than a lightweight tag.
- **A first release has no previous tag.** `git describe --tags` fails on a repository with
  no tags, which is why Step 3 falls back to the root commit.
- **A tag that has not been pushed is local only.** `git tag -d vX.Y.Z` removes it cleanly,
  so Steps 2-4 are reversible right up until the push.

## On failure

Stop at the failed step, show the full error, propose a fix, and ask whether to continue.
Tell the user which steps have already been applied and what rolling them back would take.
