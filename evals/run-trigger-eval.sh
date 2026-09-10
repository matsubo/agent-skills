#!/usr/bin/env bash
# Measure how reliably a skill's `description` triggers on realistic prompts.
#
#   ./evals/run-trigger-eval.sh evals/npm-dependency-updates/train_queries.json npm-dependency-updates
#
# The third argument is the fixture project each query runs against. It defaults to
# evals/fixture/<first segment of the skill name>, so npm-dependency-updates uses
# evals/fixture/npm.
#
# A should_trigger query passes when its trigger rate is above THRESHOLD; a
# should_not_trigger query passes when it is below. Results go to stdout as JSON.
#
# Do not add `set -o pipefail`: the jq | grep pipeline deliberately closes the
# stream early (SIGPIPE) as soon as the skill is seen, which is what keeps a run cheap.
set -euo pipefail

QUERIES_FILE="${1:?Usage: $0 <queries.json> [skill-name]}"
SKILL="${2:-npm-dependency-updates}"
RUNS="${RUNS:-3}"
THRESHOLD="${THRESHOLD:-0.5}"
TIMEOUT="${TIMEOUT:-180}"
MODEL="${MODEL:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="${3:-$REPO_ROOT/evals/fixture/${SKILL%%-*}}"

for cmd in claude jq; do
  command -v "$cmd" >/dev/null || { echo "$cmd is required but not installed" >&2; exit 1; }
done
[ -f "$QUERIES_FILE" ] || { echo "No such queries file: $QUERIES_FILE" >&2; exit 1; }
[ -d "$FIXTURE" ] || { echo "No such fixture directory: $FIXTURE" >&2; exit 1; }

# Run each query against a throwaway copy of the fixture project, not against this
# repository. Two things were measured rather than assumed here:
#   - An empty directory scores 0 for everything. The agent spends the run establishing
#     that there is no project to act on and never reaches the task.
#   - One fixture holding several ecosystems at once also scores 0 on generic prompts
#     ("bring the deps up to date"), because the agent stops to work out which ecosystem
#     is meant. Hence one single-ecosystem fixture per skill.
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cp -R "$FIXTURE/." "$WORKDIR/"

# Exits 0 when the skill was invoked, 1 otherwise. `.input.skill` is namespaced
# for plugin skills (matsubo:npm-dependency-updates), so match on the suffix.
check_triggered() {
  local query="$1"
  ( cd "$WORKDIR" && timeout "$TIMEOUT" claude -p "$query" \
      --output-format stream-json --verbose \
      --plugin-dir "$REPO_ROOT" \
      ${MODEL:+--model "$MODEL"} 2>/dev/null ) \
    | jq -rc 'select(.type=="assistant") | .message.content[]?
              | select(.type=="tool_use" and .name=="Skill") | .input.skill' \
    | grep -qE "(^|:)${SKILL}\$"
}

count="$(jq length "$QUERIES_FILE")"
for i in $(seq 0 $((count - 1))); do
  query="$(jq -r ".[$i].query" "$QUERIES_FILE")"
  should_trigger="$(jq -r ".[$i].should_trigger" "$QUERIES_FILE")"
  triggers=0

  for _ in $(seq 1 "$RUNS"); do
    if check_triggered "$query"; then triggers=$((triggers + 1)); fi
  done

  jq -n --arg query "$query" --arg skill "$SKILL" \
        --argjson should_trigger "$should_trigger" \
        --argjson triggers "$triggers" --argjson runs "$RUNS" \
        --argjson threshold "$THRESHOLD" '
    ($triggers / $runs) as $rate
    | { skill: $skill, query: $query, should_trigger: $should_trigger,
        triggers: $triggers, runs: $runs, trigger_rate: $rate,
        passed: (if $should_trigger then $rate > $threshold else $rate < $threshold end) }'
done | jq -s '{
  passed: (map(select(.passed)) | length),
  total: length,
  pass_rate: ((map(select(.passed)) | length) / length),
  failures: map(select(.passed | not)),
  results: .
}'
