#!/usr/bin/env bash
set -euo pipefail

command -v pi >/dev/null || exit 0

pi mcp add codegraph --exposure direct -- codegraph serve --mcp >/dev/null

packages=$(pi list 2>/dev/null)
grep -q "DietrichGebert/ponytail" <<<"$packages" || pi install git:github.com/DietrichGebert/ponytail
grep -q "@tintinweb/pi-subagents" <<<"$packages" || pi install npm:@tintinweb/pi-subagents

