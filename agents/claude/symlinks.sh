#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.claude"
skills="$(dirname "$PWD")/skills"
opencode_only="cross-review"

mkdir -p "$target/skills"
ln -sfn "$(dirname "$PWD")/AGENTS.md" "$target/CLAUDE.md"

find "$target/skills" -maxdepth 1 -type l ! -exec test -e {} \; -delete

for dir in "$skills"/*/; do
  name="$(basename "$dir")"
  case " $opencode_only " in
    *" $name "*) rm -f "$target/skills/$name" ;;
    *) ln -sfn "$skills/$name" "$target/skills/$name" ;;
  esac
done
