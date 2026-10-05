#!/bin/sh
set -eu

PORT=$1
WORKTREE=$2
HEALTH_CMD=$3
TIMEOUT=${4:-120}
export PORT

PID=$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n1 || true)
[ -n "$PID" ] || exit 1

CWD=$(lsof -a -p "$PID" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
case "$CWD" in
  "$WORKTREE" | "$WORKTREE"/*) ;;
  *) exit 1 ;;
esac

END=$(($(date +%s) + TIMEOUT))
while [ "$(date +%s)" -lt "$END" ]; do
  if sh -c "$HEALTH_CMD" > /dev/null 2>&1; then
    echo "reusing port $PORT (pid $PID)"
    exit 0
  fi
  sleep 2
done
exit 2
