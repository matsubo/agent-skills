---
name: ncu
description: Use when updating npm/bun dependencies to latest versions and fixing breaking changes from major version upgrades.
---

# ncu — Dependency Update & Breaking Change Fix

## Overview

Update all dependencies to latest, install, build to surface breaking changes, fix them, test.

## Steps

```bash
git fetch origin && git status  # step 0: catch up to origin first (see below)
bunx npm-check-updates -u   # update package.json (fallback: npx npm-check-updates -u)
bun install
bun run build               # surface breaking changes
bun run test
```

If build or test fails → fix breaking changes → repeat until both pass → commit.

## Step 0: Catch up to origin before updating

Always `git fetch origin` and get level with the upstream branch **before** touching
`package.json`. If the local branch is behind, pull first (stash → pull → pop when the
working tree is dirty).

Updating on a stale tree means the build verification runs against content that is not
what will ship, and a later pull can conflict on `package.json` / lockfile.

## Common Breaking Change Patterns

### Import style changes (default export removed)
```typescript
// Before (broken in v5+)
import yaml from 'js-yaml';

// After
import * as yaml from 'js-yaml';
```

### Default schema/API changes
```typescript
// Before (v4 auto-parsed timestamps)
yaml.load(content)

// After (v5 CORE_SCHEMA default — no timestamps)
yaml.load(content, { schema: yaml.YAML11_SCHEMA })
```

### General approach for any major version bump
1. Read the error message — usually pinpoints exact file/line
2. Check the package's CHANGELOG or migration guide in `node_modules/<pkg>/`
3. Fix the minimum necessary — don't refactor surrounding code

## Commit

```bash
git add package.json bun.lock <changed src files>
git commit -m "chore: bump all dependencies and fix <pkg> vN breaking changes"
```

## Notes

- Major version bumps (X.0.0) need attention; minor/patch usually safe
- `bun.lock` always changes — always stage it
- Run `bun run build` before `bun run test` — build errors mask test errors
