#!/usr/bin/env bash
set -euo pipefail

command -v opencode >/dev/null || exit 0

grep -q "setup" "$HOME/.config/opencode/plugins/worktrunk.ts" 2>/dev/null || wt config plugins opencode install -y
