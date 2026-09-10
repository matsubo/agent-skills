# agent-skills

Personal [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) for Claude Code,
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
| `ncu` | `/matsubo:ncu` | Update npm/bun dependencies to latest and fix breaking changes from major bumps. |
| `release` | `/matsubo:release [patch\|minor\|major]` | Version bump → changelog → commit → tag → push (with approval) → GitHub Release. |

## Layout

```
.claude-plugin/
  marketplace.json   # marketplace + plugin definition; "name": "matsubo" sets the namespace
skills/
  <skill>/SKILL.md   # one directory per skill
```

To add a skill, create `skills/<name>/SKILL.md` with `name` and `description` frontmatter,
then add `"./skills/<name>"` to the `skills` array in `.claude-plugin/marketplace.json`.

## License

MIT
