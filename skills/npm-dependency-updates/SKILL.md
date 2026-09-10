---
name: npm-dependency-updates
description: >-
  Update an npm or bun project's dependencies to their latest versions with
  npm-check-updates (ncu), then fix the breaking changes that major version bumps
  introduce. Use when the user asks to update, upgrade, or bump npm packages or
  dependencies, run ncu, refresh package.json, or resolve build and type errors that
  appeared after a dependency upgrade — even if they do not mention ncu or
  npm-check-updates by name. Covers JavaScript and TypeScript projects only, not Ruby
  gems, Python packages, or other ecosystems.
license: MIT
compatibility: Requires a package.json project, bun (or npm/npx), and network access
---

# npm Dependency Updates

Update every dependency to latest, then use the build as the detector for what broke.

## Workflow

```bash
git fetch origin && git status   # 1. never update on a stale tree — see Gotchas
bunx npm-check-updates -u        # 2. rewrite package.json (fallback: npx npm-check-updates -u)
bun install                      # 3.
bun run build                    # 4. surfaces breaking changes
bun run test                     # 5.
```

If step 4 or 5 fails: fix the breaking change, re-run from step 4, and repeat until both
pass. Only then commit.

## Gotchas

- **Get level with `origin` before touching `package.json`.** Updating on a stale tree
  verifies the build against content that will not ship, and a later pull conflicts on
  `package.json` and the lockfile. If the branch is behind, pull first (stash → pull → pop
  when the working tree is dirty).
- **Run the build before the tests.** Build errors mask test errors.
- **`bun.lock` always changes.** Stage it alongside `package.json`.
- Major bumps (`X.0.0`) are where breakage lives; minor and patch bumps rarely need work.

## Common breaking change patterns

### Default export removed

```typescript
// Before (broken in v5+)
import yaml from 'js-yaml';

// After
import * as yaml from 'js-yaml';
```

### Default schema or API changed

```typescript
// Before (v4 auto-parsed timestamps)
yaml.load(content)

// After (v5 CORE_SCHEMA default — no timestamps)
yaml.load(content, { schema: yaml.YAML11_SCHEMA })
```

### Any other major version bump

1. Read the error message — it usually pinpoints the exact file and line
2. Check the package's CHANGELOG or migration guide in `node_modules/<pkg>/`
3. Fix the minimum necessary — do not refactor surrounding code

## Commit

```bash
git add package.json bun.lock <changed src files>
git commit -m "chore: bump all dependencies and fix <pkg> vN breaking changes"
```
