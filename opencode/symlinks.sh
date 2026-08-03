#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.config/opencode"
mkdir -p "$target"

# Files and directories are linked individually: ~/.config/opencode also holds
# node_modules and OpenCode's own generated state, which must stay out of git.
# plugins/ and rules/ are linked as directories so anything added later — e.g.
# `wt config plugins opencode install` — lands in the repo without another edit.
for item in AGENTS.md opencode.json tui.json plugins rules; do
  ln -sfn "$PWD/$item" "$target/$item"
done

# oh-my-openagent reads its config from ~/.omo, a separate root from
# ~/.config/opencode. Only omo.jsonc is tracked; the rest of ~/.omo is runtime
# state and caches.
mkdir -p "$HOME/.omo"
ln -sfn "$PWD/omo.jsonc" "$HOME/.omo/omo.jsonc"
