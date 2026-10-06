#!/usr/bin/env bash
set -euo pipefail

command -v codex >/dev/null || exit 0

config="$HOME/.codex/config.toml"
mkdir -p "$(dirname "$config")"
touch "$config"

if ! grep -q '^approval_policy' "$config"; then
  { cat top-level.toml; cat "$config"; } > "$config.tmp"
  mv "$config.tmp" "$config"
fi
grep -q '^\[sandbox_workspace_write\]' "$config" || sed "s|~/|$HOME/|g" sandbox.toml >> "$config"

codex mcp get codegraph >/dev/null 2>&1 || codex mcp add codegraph -- codegraph serve --mcp

plugins=$(codex plugin list 2>/dev/null)
grep -q "ponytail@ponytail .*installed" <<<"$plugins" || {
  codex plugin marketplace add DietrichGebert/ponytail
  codex plugin add ponytail@ponytail
}
grep -q "worktrunk@worktrunk .*installed" <<<"$plugins" || wt config plugins codex install -y
