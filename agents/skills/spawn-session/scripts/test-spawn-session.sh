#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(dirname "$0")/spawn-session.sh"

pick() {
  env -i PATH="$PATH" "$@" "$SCRIPT" /tmp/wt "[T] b" "prompt" 2>/dev/null || true
}

expect() {
  case "$2" in
    *"$1"*) ;;
    *) echo "FAIL: expected '$1' in: $2" >&2; exit 1 ;;
  esac
}

expect "claude" "$(pick CLAUDECODE=1)"
expect "codex" "$(pick CODEX_THREAD_ID=1)"
expect "opencode" "$(pick OPENCODE=1)"
expect "claude" "$(pick CLAUDECODE=1 OPENCODE=1)"

if env -i PATH="$PATH" "$SCRIPT" /tmp/wt "[T] b" "prompt" 2>/dev/null; then
  echo "FAIL: unknown agent must exit nonzero" >&2
  exit 1
fi

echo ok
