#!/usr/bin/env bash
# Audit this repository's skills for spec violations, manifest drift and unsafe content.
#
#   scripts/audit.sh [repository-root]
#
# Exits 0 when nothing is wrong, 1 when any ERROR is reported. WARNINGs are printed but do
# not fail the run.
#
# The audit deliberately does not shell out to `claude`. It has to run in CI without an API
# key, on a contributor's clone, and inside the test suite over synthetic fixtures. CI runs
# `claude plugin validate` as a separate step; that command is a weak gate on its own —
# measured against deliberately broken skills, --strict accepts a missing `name`, a `name`
# that violates the specification's charset or disagrees with its directory, and a
# `description` of any length. Those are checked here instead.
set -eu

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT="$(cd "$ROOT" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v jq >/dev/null || { echo "jq is required but not installed" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required but not installed" >&2; exit 2; }

errors=0
warnings=0

error() {
  printf 'ERROR   %-20s %s\n            %s\n' "$1" "$2" "$3"
  errors=$((errors + 1))
}

warn() {
  printf 'WARN    %-20s %s\n            %s\n' "$1" "$2" "$3"
  warnings=$((warnings + 1))
}

# Read `check-id<TAB>location<TAB>message` findings from a helper script. A temp file
# rather than a pipe, so that the `error` calls run in this shell and their increments to
# $errors survive; a `while read` on the right-hand side of a pipe runs in a subshell and
# every count would be discarded.
drain() {
  local file="$1"
  while IFS="$(printf '\t')" read -r check location message; do
    [ -n "$check" ] || continue
    error "$check" "$location" "$message"
  done < "$file"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- Skill discovery ----------------------------------------------------------------

[ -d "$ROOT/skills" ] || { echo "No skills/ directory in $ROOT" >&2; exit 2; }

skill_dirs=()
while IFS= read -r dir; do
  skill_dirs+=("$dir")
done < <(find "$ROOT/skills" -mindepth 1 -maxdepth 1 -type d | sort)

skill_files=()
for dir in "${skill_dirs[@]}"; do
  if [ -f "$dir/SKILL.md" ]; then
    skill_files+=("$dir/SKILL.md")
  else
    error "skill-md-missing" "${dir#"$ROOT"/}" "skill directory contains no SKILL.md"
  fi
done

if [ "${#skill_files[@]}" -eq 0 ]; then
  echo "No SKILL.md files found under $ROOT/skills" >&2
  exit 2
fi

# --- Frontmatter and body budget ----------------------------------------------------

"$SCRIPT_DIR/check-frontmatter.py" "${skill_files[@]}" > "$WORK/frontmatter.tsv"
drain "$WORK/frontmatter.tsv"

# --- Invisible characters -----------------------------------------------------------

# Everything under skills/ ships to whoever installs the skill and is read by the model, so
# the content checks cover all of it — not just SKILL.md. references/*.md matters most: it is
# the documented place to move long content into, so it would otherwise be the one authoring
# path that bypasses this gate entirely. Bundled scripts are scanned for the same reason.
#
# Only the frontmatter checks above stay restricted to SKILL.md, since nothing else has any.
text_files=()
while IFS= read -r file; do
  text_files+=("$file")
done < <(find "$ROOT/skills" -type f \( -name '*.md' -o -name '*.sh' \) | sort)

"$SCRIPT_DIR/check-hidden-chars.py" "${text_files[@]}" > "$WORK/hidden.tsv"
drain "$WORK/hidden.tsv"

# --- Manifest consistency -----------------------------------------------------------

MANIFEST="$ROOT/.claude-plugin/marketplace.json"
if [ ! -f "$MANIFEST" ]; then
  error "marketplace-missing-file" ".claude-plugin/marketplace.json" "manifest does not exist"
elif ! jq empty "$MANIFEST" 2>"$WORK/jq.err"; then
  error "marketplace-parse" ".claude-plugin/marketplace.json" "$(tr -d '\n' < "$WORK/jq.err")"
else
  jq -r '.plugins[]?.skills[]?' "$MANIFEST" | sed 's|^\./||; s|^skills/||; s|/$||' | sort -u \
    > "$WORK/listed.txt"
  for dir in "${skill_dirs[@]}"; do basename "$dir"; done | sort -u > "$WORK/ondisk.txt"

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    error "marketplace-orphan" "skills/$name" \
      "on disk but absent from marketplace.json; add \"./skills/$name\" to plugins[].skills"
  done < <(comm -13 "$WORK/listed.txt" "$WORK/ondisk.txt")

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    error "marketplace-missing" ".claude-plugin/marketplace.json" \
      "lists \"./skills/$name\", which does not exist on disk"
  done < <(comm -23 "$WORK/listed.txt" "$WORK/ondisk.txt")
fi

# --- Unsafe content -----------------------------------------------------------------

# A skill is instructions that an agent executes on someone else's machine. Each pattern
# below is something a reviewer should have to approve deliberately rather than inherit by
# installing a skill.
#
# The patterns are tuned against the skills that already exist here. Bare `git push` is
# NOT a pattern: skills/release/SKILL.md documents `git push origin main --follow-tags`
# legitimately, and `--force-with-lease` is excluded for the same reason. Likewise the
# pipe-to-shell pattern requires a shell on the right-hand side, because
# skills/github-actions-workflows/scripts/ pipes curl into jq.
audit_pattern() {
  local check="$1" regex="$2" explanation="$3" file line
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"
    line="$(printf '%s' "${hit#*:}" | cut -d: -f1)"
    error "$check" "${file#"$ROOT"/}:$line" "$explanation"
  done < <(grep -nE "$regex" "${text_files[@]}" /dev/null || true)
}

audit_pattern "dangerous-pattern" \
  'rm[[:space:]]+-[[:alpha:]]*[rR][[:alpha:]]*f|rm[[:space:]]+-[[:alpha:]]*f[[:alpha:]]*[rR]' \
  'recursive forced delete; a skill should not instruct an agent to run rm -rf'

audit_pattern "dangerous-pattern" \
  '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?([a-z]*sh|python[0-9.]*|node|perl|ruby)([^[:alnum:]_-]|$)' \
  'pipes a remote script straight into a shell or interpreter; pin and inspect it instead'

audit_pattern "dangerous-pattern" \
  '\-\-dangerously-skip-permissions' \
  'disables the permission prompts that are the user last line of defence'

audit_pattern "dangerous-pattern" \
  'git[[:space:]]+push.*(--force([^-]|$)|[[:space:]]-f([[:space:]]|$))' \
  'force push discards other people commits; use --force-with-lease if it is truly needed'

audit_pattern "dangerous-pattern" \
  '(^|[^[:alnum:]_./-])sudo[[:space:]]' \
  'escalates privilege on the installer machine'

audit_pattern "dangerous-pattern" \
  'chmod[[:space:]]+(-[[:alpha:]]+[[:space:]]+)*(777|a\+rwx)' \
  'world-writable permissions'

audit_pattern "dangerous-pattern" \
  'base64[[:space:]]+(-d|-D|--decode)[^|]*\|[[:space:]]*[a-z]*sh([^[:alnum:]_-]|$)' \
  'executes decoded content, which hides what is actually run from review'

audit_pattern "dangerous-pattern" \
  'eval[[:space:]]+["'\'']?\$\((curl|wget)' \
  'evaluates content fetched at runtime, which no reviewer can audit'

audit_pattern "secret-literal" \
  'sk-ant-api[0-9]{2}-|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}' \
  'looks like a live credential committed to a public repository; rotate it'

# An HTML comment is invisible in every rendered view of a Markdown file, so instructions
# hidden in one reach the model without reaching the human who approved the skill.
audit_pattern "hidden-instruction" \
  '<!--' \
  'HTML comment; a reviewer reading the rendered file cannot see what an agent still reads'

# --- Bundled scripts ----------------------------------------------------------------

while IFS= read -r script; do
  [ -x "$script" ] || error "script-not-executable" "${script#"$ROOT"/}" \
    "bundled script is not executable; it will fail for anyone who installs the skill"
done < <(find "$ROOT/skills" -type f -name '*.sh' | sort)

# --- Evals ---------------------------------------------------------------------------

if [ -d "$ROOT/evals" ]; then
  while IFS= read -r queries; do
    relative="${queries#"$ROOT"/}"
    if ! jq empty "$queries" 2>"$WORK/jq.err"; then
      error "eval-json" "$relative" "not valid JSON: $(tr -d '\n' < "$WORK/jq.err")"
      continue
    fi
    # run-trigger-eval.sh reads .query and .should_trigger from every entry; an entry
    # missing either is silently scored rather than reported, so check the shape here.
    if ! jq -e 'type == "array" and length > 0 and all(
                  (.query | type == "string" and length > 0) and
                  (.should_trigger | type == "boolean"))' "$queries" >/dev/null; then
      error "eval-query-schema" "$relative" \
        'every entry needs a non-empty string `query` and a boolean `should_trigger`'
    fi
  done < <(find "$ROOT/evals" -type f -name '*_queries.json' | sort)

  # run-trigger-eval.sh defaults the fixture to evals/fixture/<first segment of the skill
  # name>, so a missing fixture makes every query in that set score zero.
  while IFS= read -r dir; do
    name="$(basename "$dir")"
    [ "$name" != "fixture" ] || continue
    fixture="$ROOT/evals/fixture/${name%%-*}"
    [ -d "$fixture" ] || error "eval-fixture" "evals/$name" \
      "run-trigger-eval.sh defaults to evals/fixture/${name%%-*}, which does not exist"
  done < <(find "$ROOT/evals" -mindepth 1 -maxdepth 1 -type d | sort)

  for dir in "${skill_dirs[@]}"; do
    name="$(basename "$dir")"
    [ -d "$ROOT/evals/$name" ] || warn "eval-missing" "skills/$name" \
      "no evals/$name/ queries measure whether this description triggers"
  done
fi

# --- Summary -------------------------------------------------------------------------

printf '\n%d skill(s) audited: %d error(s), %d warning(s)\n' \
  "${#skill_files[@]}" "$errors" "$warnings"
[ "$errors" -eq 0 ]
