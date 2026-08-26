#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.config/opencode"
mkdir -p "$target"

for item in AGENTS.md opencode.json package.json service-status-tui.tsx tui.jsonc rules; do
  ln -sfn "$PWD/$item" "$target/$item"
done
