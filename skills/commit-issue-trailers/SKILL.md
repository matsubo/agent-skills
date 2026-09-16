---
name: commit-issue-trailers
description: >-
  Put the issue or PR a commit belongs to at the end of the commit message, as a trailer
  whose prefix says what the relationship is — `ref:`, `related:`, `part-of:`,
  `follows-up:`, `reverts:`, `blocked-by:`. Use when writing or amending a commit message,
  when the work came from an issue or PR, when the branch name carries an issue number, or
  when the user names an issue or PR while asking for a commit. Shapes the message only: it
  does not stage, commit or push, and it never emits `Closes`/`Fixes`/`Resolves`, which
  close issues on merge.
license: MIT
compatibility: Requires git; `git commit --trailer` needs git 2.32 or newer
---

# Commit Issue Trailers

A bare `#111` in a commit message records the number but not what it meant. Use a prefix
that carries the relationship, so the link still reads six months later.

## The vocabulary

Lowercase, colon, one id per line, as the last paragraph of the message. These are the only
six.

| Trailer | What it claims |
|---------|----------------|
| `ref: #111` | This commit is work on #111 — it implements, fixes or advances it |
| `related: #112` | Context: where the work came from, a similar bug, a discussion |
| `part-of: #120` | One commit of a tracking issue or epic that stays open |
| `follows-up: #98` | Fixes or extends something already merged in #98 |
| `reverts: #105` | Undoes #105 |
| `blocked-by: #130` | Cannot be finished until #130 is resolved |

Across repositories, write the full form: `ref: owner/repo#111`.

## How to use it

Take the ids from what the user told you in this session, and from the branch name. Give
each one the prefix that fits, and put them at the end:

```bash
git commit -m "fix: reject cross-origin returnTo after login" \
  --trailer "ref: #142" --trailer "part-of: #120" --trailer "related: #88"
```

```
fix: reject cross-origin returnTo after login

The post-login redirect trusted the user-controlled `returnTo` verbatim.

ref: #142
part-of: #120
related: #88
```

At most one `ref:` per commit. When nothing else fits, `related:` is the right answer — a
weak link gets a weak prefix rather than being dropped.

## Rules

- **Never write an id you were not given and cannot see in the branch name.** A wrong
  reference cannot be edited out of a pushed history.
- **A branch name is not a number hunt.** `142-fix-login` and `fix/issue-456` name issues.
  `release/2.0.1` is a version, `hotfix/2024-01-15` is a date, `feat/v3-rewrite` is an
  attempt, `feature/oauth2` is a word with a digit in it, and `feat/redesign-2` is the
  second try. Take a number only when it leads a segment or follows `issue`/`gh`/`pr`.
- **No id anywhere? Add nothing** and write an ordinary commit message.
- **Never `Closes`, `Fixes` or `Resolves`.** They close issues on merge. If an issue should
  close, say so and let the user decide.
- **No remote is not a reason to skip the trailer.** It records where the work came from; it
  is not a claim that the issue exists.

## Gotchas

- `git commit --trailer` keeps the lowercase spelling and does not duplicate a trailer the
  message already ends with. Different casing is *not* deduplicated.
- The trailer block coexists with `Co-Authored-By` and `Signed-off-by` in one paragraph.
- GitHub numbers issues and PRs from the same sequence, so a branch-derived id may turn out
  to be a PR. Every prefix here works for both.
