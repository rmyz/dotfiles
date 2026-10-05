#!/usr/bin/env bash
set -euo pipefail

[ -L "$HOME/.agents" ] && rm "$HOME/.agents"
mkdir -p "$HOME/.agents"
ln -sfn "$PWD/skills" "$HOME/.agents/skills"
ln -sfn "$PWD/.skill-lock.json" "$HOME/.agents/.skill-lock.json"

for dir in */; do
  if [ -x "$dir/symlinks.sh" ]; then
    ( cd "$dir" && ./symlinks.sh )
  fi
done
