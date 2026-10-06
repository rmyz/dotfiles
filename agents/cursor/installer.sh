#!/usr/bin/env bash
set -euo pipefail

command -v agent >/dev/null || exit 0

model=claude-opus-5-5-medium
config="$HOME/.cursor/cli-config.json"
mcp="$HOME/.cursor/mcp.json"
mkdir -p "$HOME/.cursor"
[ -f "$config" ] || echo '{"version": 1}' > "$config"
[ -f "$mcp" ] || echo '{"mcpServers": {}}' > "$mcp"

jq --arg m "$model" '.approvalMode = "unrestricted"
  | .selectedModel = {modelId: $m, parameters: []}
  | .model = ((.model // {}) + {modelId: $m, displayModelId: $m})
  | .hasChangedDefaultModel = true' "$config" > "$config.tmp"
cat "$config.tmp" > "$config" && rm "$config.tmp"

jq '.mcpServers.codegraph = {type: "stdio", command: "codegraph", args: ["serve", "--mcp", "--path", "${workspaceFolder}"]}' "$mcp" > "$mcp.tmp"
cat "$mcp.tmp" > "$mcp" && rm "$mcp.tmp"
