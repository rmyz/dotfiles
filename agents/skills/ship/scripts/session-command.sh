#!/usr/bin/env bash
set -euo pipefail

DIR=$1
PROMPT=$2
OPENCODE_AGENT=${3:-build}

if [ -n "${OPENCODE:-}" ]; then
  printf 'opencode %q --agent %q --prompt %q\n' "$DIR" "$OPENCODE_AGENT" "$PROMPT"
elif [ -n "${CLAUDECODE:-}" ]; then
  printf 'cd %q && claude %q\n' "$DIR" "$PROMPT"
elif [ -n "${CODEX_THREAD_ID:-}" ]; then
  printf 'codex -C %q %q\n' "$DIR" "$PROMPT"
elif [ -n "${CURSOR_AGENT:-}" ]; then
  printf 'agent --workspace %q %q\n' "$DIR" "$PROMPT"
else
  echo "unknown agent: set OPENCODE, CLAUDECODE, CODEX_THREAD_ID, or CURSOR_AGENT" >&2
  exit 1
fi
