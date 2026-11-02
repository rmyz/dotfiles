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

LAST=$(awk -F'\t' '$3 == "all" { c = $4 } END { print c }' "$DATA/scores.tsv")
case "$CONFIG" in
  *-dirty) ;;
  "$LAST") ;;
  *)
    echo "review config changed: $LAST -> $CONFIG"
    exit 0
    ;;
esac

echo "nothing to do"
exit 1
