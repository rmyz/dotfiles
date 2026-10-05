#!/usr/bin/env bash
set -euo pipefail

DIR=$1
TITLE=$2
PROMPT=$3
OPENCODE_AGENT=${4:-build}

if [ -n "${PI_CODING_AGENT:-}" ]; then
  CMD=$(printf 'cd %q && pi %q' "$DIR" "$PROMPT")
elif [ -n "${CLAUDECODE:-}" ]; then
  CMD=$(printf 'cd %q && claude %q' "$DIR" "$PROMPT")
elif [ -n "${CODEX_THREAD_ID:-}" ]; then
  CMD=$(printf 'codex -C %q %q' "$DIR" "$PROMPT")
elif [ -n "${CURSOR_AGENT:-}" ]; then
  CMD=$(printf 'agent --workspace %q %q' "$DIR" "$PROMPT")
elif [ -n "${OPENCODE:-}" ]; then
  CMD=$(printf 'opencode %q --agent %q --prompt %q' "$DIR" "$OPENCODE_AGENT" "$PROMPT")
else
  echo "unknown agent: set PI_CODING_AGENT, CLAUDECODE, CODEX_THREAD_ID, CURSOR_AGENT, or OPENCODE" >&2
  exit 1
fi

if [ -z "${ORCA_TERMINAL_HANDLE:-}" ]; then
  echo "not inside Orca; start the next session with:" >&2
  echo "$CMD"
  exit 2
fi

orca terminal create --worktree "path:$DIR" --title "$TITLE" --command "$CMD" --json
