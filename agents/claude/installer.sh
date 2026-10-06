#!/usr/bin/env bash
set -euo pipefail

command -v claude >/dev/null || exit 0

claude mcp get codegraph >/dev/null 2>&1 || claude mcp add -s user codegraph -- codegraph serve --mcp

plugins=$(claude plugin list 2>/dev/null)
grep -q "ponytail@ponytail" <<<"$plugins" || {
  claude plugin marketplace add DietrichGebert/ponytail
  claude plugin install ponytail@ponytail --scope user
}
grep -q "worktrunk@worktrunk" <<<"$plugins" || wt config plugins claude install -y

settings="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$settings")"
[ -f "$settings" ] || echo '{}' > "$settings"
jq '.permissions.defaultMode = "bypassPermissions"
  | .permissions.allow = ((.permissions.allow // []) + ["mcp__codegraph__*"] | unique)
  | .skipDangerousModePermissionPrompt = true' "$settings" > "$settings.tmp"
mv "$settings.tmp" "$settings"
