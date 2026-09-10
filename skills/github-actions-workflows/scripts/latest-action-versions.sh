#!/usr/bin/env bash
# Print the current version of each GitHub Action named on the command line.
#
#   scripts/latest-action-versions.sh actions/checkout ruby/setup-ruby
#   action            major  exact      major_ref
#   actions/checkout  v7     v7.0.1     tag
#   ruby/setup-ruby   v1     v1.321.0   branch
#
# major_ref says what `@<major>` actually resolves to:
#   tag    — a moving major tag, the normal case for actions/* and github/*
#   branch — a branch, as mutable as @main even though it does not look it
#   none   — no moving major ref at all; you must use the exact version
set -eu

[ $# -gt 0 ] || { echo "usage: $0 <owner/repo> [owner/repo ...]" >&2; exit 2; }

# gh is preferred: it is authenticated, so it avoids the 60/hour anonymous rate
# limit that makes a bare curl fail partway through a batch.
if command -v gh >/dev/null 2>&1; then
  # gh prints the error body to stdout and exits non-zero, so the status must be
  # checked; redirecting stderr alone would let a 404 JSON blob through as data.
  api() { gh api "$1" --jq "$2" 2>/dev/null || return 1; }
  ref_kind() {
    gh api "repos/$1/git/ref/tags/$2" >/dev/null 2>&1 && { echo tag; return; }
    gh api "repos/$1/git/ref/heads/$2" >/dev/null 2>&1 && { echo branch; return; }
    echo none
  }
elif command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  echo "warning: gh not found, falling back to anonymous API (60 requests/hour)" >&2
  api() { curl -fsSL "https://api.github.com/$1" | jq -r "$2" || return 1; }
  ref_kind() {
    curl -fsSL -o /dev/null "https://api.github.com/repos/$1/git/ref/tags/$2" && { echo tag; return; }
    curl -fsSL -o /dev/null "https://api.github.com/repos/$1/git/ref/heads/$2" && { echo branch; return; }
    echo none
  }
else
  echo "error: need either the gh CLI, or curl and jq" >&2; exit 1
fi

is_version() { printf '%s' "$1" | grep -qE '^v?[0-9]+(\.[0-9]+)*$'; }

printf 'action\tmajor\texact\tmajor_ref\n'
status=0
for action in "$@"; do
  case "$action" in
    */*/*|*/) printf '%s\tERROR\t-\tnot an owner/repo reference\n' "$action"; status=1; continue ;;
    */*)      ;;
    *)        printf '%s\tERROR\t-\tnot an owner/repo reference\n' "$action"; status=1; continue ;;
  esac

  # Most actions publish releases; some only push tags, so fall back to the
  # highest semver tag rather than reporting nothing.
  exact="$(api "repos/$action/releases/latest" '.tag_name' || true)"
  if ! is_version "${exact:-}"; then
    exact="$(api "repos/$action/tags" '.[].name' 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)"
  fi
  if ! is_version "${exact:-}"; then
    printf '%s\tERROR\t-\tno release or semver tag found (private, renamed, or deleted?)\n' "$action"
    status=1
    continue
  fi

  major="$(printf '%s' "$exact" | sed -E 's/^(v?[0-9]+).*/\1/')"
  printf '%s\t%s\t%s\t%s\n' "$action" "$major" "$exact" "$(ref_kind "$action" "$major")"
done
exit $status
