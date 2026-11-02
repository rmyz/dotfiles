#!/usr/bin/env bash
set -euo pipefail

REVIEWER=$1
SPLIT=${2:-all}
ONLY=${3:-}
LABEL=${ONLY:+pr-$ONLY}
LABEL=${LABEL:-$SPLIT}

DATA="$HOME/Code/ai-generated/files/review-eval"
KIBANA="$HOME/Code/kibana"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
CONFIG=$("$(dirname "$0")/config.sh")
RUN="$DATA/runs/$(date +%Y%m%d-%H%M%S)-$REVIEWER-$LABEL"
mkdir -p "$RUN"
[ -f "$DATA/scores.tsv" ] || printf 'date\treviewer\tsplit\tconfig\tcases\texpected\tcaught\trecall_pct\tfindings\tunmatched\n' > "$DATA/scores.tsv"

review() {
  local wt=$1 base=$2
  case "$REVIEWER" in
    code)
      (cd "$wt" && claude -p "/code-review high $base..HEAD" < /dev/null)
      ;;
    cross)
      (cd "$wt" && opencode run --agent build "Read ~/.agents/skills/cross-review/SKILL.md and follow it non-interactively.
Scope: git diff $base HEAD. Intent: $3. Plan: none.
Earlier findings: none.
Report only, do not edit files." < /dev/null)
      ;;
    *)
      echo "unknown reviewer: $REVIEWER" >&2
      exit 1
      ;;
  esac
}

jq -c --arg split "$SPLIT" --arg only "$ONLY" \
  '.[] | select($split == "all" or .split == $split) | select($only == "" or (.pr | tostring) == $only)' \
  "$DATA/cases.json" | while read -r case; do
  pr=$(jq -r .pr <<<"$case")
  base=$(jq -r .base_sha <<<"$case")
  sha=$(jq -r .reviewed_sha <<<"$case")
  title=$(jq -r .title <<<"$case")
  wt=$(mktemp -d)/kibana

  git -C "$KIBANA" worktree add --quiet --detach "$wt" "$sha"
  review "$wt" "$base" "$title" > "$RUN/$pr.report.md" 2>&1 || true
  git -C "$KIBANA" worktree remove --force "$wt"
  rmdir "$(dirname "$wt")"

  jq '{pr, title, expected}' <<<"$case" > "$RUN/$pr.expected.json"
  claude -p --model claude-sonnet-5-5 --output-format json --json-schema "$(cat "$SKILL_DIR/judge.schema.json")" "$(cat "$SKILL_DIR/judge.md")

Expected comments:
$(cat "$RUN/$pr.expected.json")

Review report:
$(cat "$RUN/$pr.report.md")" < /dev/null | jq .structured_output > "$RUN/$pr.judge.json"

  jq -s '.[0] + {expected_total: (.[1].expected | length)}' "$RUN/$pr.judge.json" "$RUN/$pr.expected.json" > "$RUN/$pr.score.json"
  jq -r --arg pr "$pr" '"\($pr)\tcaught \(.matched | map(.expected_id) | unique | length)/\(.expected_total)\tfindings \(.findings_total)\tunmatched \(.unmatched_findings | length)"' "$RUN/$pr.score.json"
done

jq -rs --arg date "$(date +%F)" --arg reviewer "$REVIEWER" --arg split "$LABEL" --arg config "$CONFIG" '
  (map(.expected_total) | add) as $expected |
  (map(.matched | map(.expected_id) | unique | length) | add) as $caught |
  (map(.findings_total) | add) as $findings |
  (map(.unmatched_findings | length) | add) as $unmatched |
  [$date, $reviewer, $split, $config, length, $expected, $caught, ($caught / $expected * 100 | round), $findings, $unmatched] | @tsv
' "$RUN"/*.score.json | tee -a "$DATA/scores.tsv"
