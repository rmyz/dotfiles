#!/usr/bin/env bash
set -uo pipefail

ROOT=${1:-$HOME/.dotfiles/agents}
SKILLS="$ROOT/skills"
HERE=$(cd "$(dirname "$0")/.." && pwd)
SKIP='visual-explainer'
FILES=$(find "$SKILLS" "$ROOT/AGENTS.md" "$ROOT/REVIEW.md" -name '*.md' -not -path "*/$SKIP/*" -not -path '*/node_modules/*' 2>/dev/null)

echo "## Frontmatter"
for f in "$SKILLS"/*/SKILL.md; do
  d=$(basename "$(dirname "$f")")
  [ "$d" = "$SKIP" ] && continue
  n=$(sed -n 's/^name: *//p' "$f" | head -1)
  [ "$n" = "$d" ] || echo "$f: name '$n' differs from directory"
  grep -q '^description: ' "$f" || echo "$f: missing description"
done

echo "## Dead references"
for f in $FILES; do
  rg -o '~/\.agents/[A-Za-z0-9_./-]+' "$f" | sort -u | while read -r ref; do
    p=${ref/#\~/$HOME}
    p=${p%.}
    case "$p" in *-) continue ;; esac
    [ -e "$p" ] || echo "$f: $ref"
  done
done

echo "## Skill names without a skill directory (opencode commands)"
for c in "$ROOT"/opencode/commands/*.md; do
  rg -o 'Load the ([a-z0-9-]+) skill' -r '$1' "$c" | while read -r s; do
    [ -d "$SKILLS/$s" ] || echo "$c: skill '$s' does not exist"
  done
done

echo "## Stale terms"
while read -r t; do
  [ -z "$t" ] && continue
  rg -n -F -- "$t" $FILES "$HERE/../../opencode" 2>/dev/null | grep -v "$HERE/stale-terms.txt" | sed "s/^/[$t] /"
done < "$HERE/stale-terms.txt"

echo "## Em dashes"
rg -c '—' $FILES | sed "s|$ROOT/||" | sort -t: -k2 -rn

echo "## Duplicate lines across files (60+ chars, 2+ files)"
for f in $FILES; do
  awk -v f="$f" 'length($0)>=60 {gsub(/^[ \t>*-]+/,""); print $0 "\t" f}' "$f"
done | sort | awk -F'\t' '{c[$1]++; fl[$1]=fl[$1] " " $2; if(!seen[$1 SUBSEP $2]++) n[$1]++} END{for(k in n) if(n[k]>1) print substr(k,1,90) " =>" fl[k]}' | sed "s|$ROOT/||g; s|skills/||g; s|/SKILL.md||g" | sort | head -40

echo "## Largest skill docs (bytes)"
for d in "$SKILLS"/*/; do
  [ "$(basename "$d")" = "$SKIP" ] && continue
  echo "$(find "$d" -name '*.md' -exec cat {} + | wc -c | tr -d ' ') $(basename "$d")"
done | sort -rn | head -8
