#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.claude"
skills="$(dirname "$PWD")/skills"

mkdir -p "$target/skills"
ln -sfn "$(dirname "$PWD")/AGENTS.md" "$target/CLAUDE.md"

find "$target/skills" -maxdepth 1 -type l ! -exec test -e {} \; -delete

for dir in "$skills"/*/; do
  ln -sfn "$skills/$(basename "$dir")" "$target/skills/$(basename "$dir")"
done
