#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.config/opencode"
mkdir -p "$target"

for item in opencode.json package.json service-status-tui.tsx tui.jsonc commands agents; do
  ln -sfn "$PWD/$item" "$target/$item"
done

ln -sfn "$(dirname "$PWD")/AGENTS.md" "$target/AGENTS.md"
