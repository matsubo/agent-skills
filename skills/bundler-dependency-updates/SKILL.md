---
name: bundler-dependency-updates
description: >-
  Update a Ruby project's gems to their latest versions with Bundler (bundle update), then
  fix the breaking changes that major version bumps introduce. Use when the user asks to
  update, upgrade or bump gems or dependencies, run bundle update or bundle outdated,
  refresh Gemfile.lock, or resolve failures that appeared after a gem upgrade — even if they
  do not mention Bundler by name. Covers Ruby projects with a Gemfile, including ones whose
  toolchain runs under Docker Compose. Not for npm packages, Python packages, or other
  ecosystems.
license: MIT
compatibility: Requires a Gemfile project and network access, plus either a local Ruby toolchain with Bundler or Docker Compose
---

# Bundler Dependency Updates

Update every gem to latest, then use the test suite as the detector for what broke.

## Step 0: Decide where Bundler runs

Look for `compose.yaml`, `compose.yml`, `docker-compose.yml` or `docker-compose.yaml`.

| Project | Prefix every `bundle` command with |
|---------|------------------------------------|
| Plain Ruby | nothing |
| Docker Compose | `docker compose run --rm <service>` |

`<service>` is the service whose build context contains the `Gemfile` — commonly `app`,
`web`, `api` or `rails`. Read the Compose file rather than guessing.

For a Compose project this is not a stylistic choice. Gems with native extensions
(`nokogiri`, `pg`, `ffi`, `grpc`) compile against the container's architecture and libc, and
a `Gemfile.lock` resolved on the host records platforms the container cannot use.

The rest of this skill writes commands bare. Apply the prefix from the table to each one.

## Workflow

```bash
git fetch origin && git status   # 1. never update on a stale tree — see Gotchas
bundle outdated                  # 2. what is behind, and by how much
bundle update                    # 3. re-resolves everything, rewrites Gemfile.lock
bundle exec rspec                # 4. or bin/rails test — Ruby has no build step, so the
                                 #    test suite is the only detector of breakage
```

If step 4 fails: fix the breakage, re-run step 4, and repeat until it is green. Only then
commit.

On a Compose project, run `docker compose build <service>` between steps 3 and 4 unless the
project mounts a gem volume (a named volume on `/usr/local/bundle` or `vendor/bundle`).
Without such a volume the gems installed by `run --rm` disappear with the container, and the
tests run against the stale gems baked into the image.

## Gotchas

- **Get level with `origin` before updating.** `Gemfile.lock` conflicts are miserable to
  resolve by hand, and the fix is always to re-resolve anyway. If the branch is behind, pull
  first (stash → pull → pop when the working tree is dirty).
- **Bare `bundle update` updates transitive dependencies too**, so the lockfile diff can be
  far larger than the Gemfile suggests. When that diff is too large to review, re-run with
  `--conservative` to hold transitive gems, `bundle update <gem>` for a single gem, or
  `--patch` / `--minor` to cap how far each gem may jump.
- **`Gemfile.lock` is the deliverable.** Always stage it. Never hand-edit it — re-resolve.
- **A lockfile resolved on macOS breaks Linux deploys.** If Bundler had to run on the host,
  add the deployment platform: `bundle lock --add-platform x86_64-linux` (or
  `aarch64-linux`). Running inside the container avoids the problem entirely.
- **`docker compose run` writes as root.** On Linux hosts that leaves a root-owned
  `Gemfile.lock` in the bind mount. Re-run with
  `docker compose run --rm --user "$(id -u):$(id -g)" <service> …` when it happens.
- **Always `bundle exec`.** Without it a binstub can load a different version than the one
  the lockfile pins.
- **The Gemfile may pin Ruby itself** (`ruby "3.3.0"`, `.ruby-version`). A gem that requires
  a newer Ruby fails to resolve. Either bump Ruby — including the Dockerfile base image —
  or hold that gem back.
- **Update Bundler separately.** `bundle update --bundler` rewrites `BUNDLED WITH`; doing it
  in the same commit as the gem update makes the diff hard to read.

## Common breaking change patterns

### Rails major version bump

```bash
bin/rails app:update    # regenerates config/ — review every hunk, accept nothing blindly
```

Then raise `config.load_defaults` in `config/application.rb` one version at a time, running
the tests between each step. New framework defaults, not the gem code, cause most of the
breakage.

### A constant or method disappeared

```bash
bundle show <gem>   # prints the install path; read its CHANGELOG.md or UPGRADING.md
```

### Any other major bump

1. Read the failure — the backtrace usually names the gem and the call site
2. Check the CHANGELOG or upgrade guide in `$(bundle show <gem>)`
3. Fix the minimum necessary — do not refactor surrounding code

## Commit

```bash
git add Gemfile Gemfile.lock <changed files>
git commit -m "chore: bundle update and fix <gem> vN breaking changes"
```
