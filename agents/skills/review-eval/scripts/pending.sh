#!/usr/bin/env bash
set -euo pipefail

DATA="$HOME/Code/ai-generated/files/review-eval"
CONFIG=$("$(dirname "$0")/config.sh")

NEW=$(gh pr list -R elastic/kibana --author @me --state merged --search "merged:>=$(date -v-30d +%F)" \
  --json number -q '.[].number' | grep -vxF -f "$DATA/harvested.txt" || true)
if [ -n "$NEW" ]; then
  echo "new merged PRs: $(echo $NEW)"
  exit 0
fi

case "$CONFIG" in
  *-dirty) ;;
  *)
    for REVIEWER in code cross; do
      LAST=$(awk -F'\t' -v r="$REVIEWER" '$2 == r && $3 == "all" { c = $4 } END { print c }' "$DATA/scores.tsv")
      if [ "$CONFIG" != "$LAST" ]; then
        echo "review config changed for $REVIEWER: $LAST -> $CONFIG"
        exit 0
      fi
    done
    ;;
esac

echo "nothing to do"
exit 1
