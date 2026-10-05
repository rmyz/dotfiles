#!/bin/sh
set -eu

BASE_PORT=$1
TIMEOUT=$2
HEALTH_CMD=$3
LAUNCH_CMD=$4

LOCK=/tmp/kibana-port-allocation.lock
while ! mkdir "$LOCK" 2>/dev/null; do
  if [ -f "$LOCK/pid" ] && ! kill -0 "$(cat "$LOCK/pid")" 2>/dev/null; then
    rm -f "$LOCK/pid"
    rmdir "$LOCK" 2>/dev/null || true
    continue
  fi
  sleep 1
done
printf '%s\n' "$$" > "$LOCK/pid"
release_lock() {
  rm -f "$LOCK/pid"
  rmdir "$LOCK" 2>/dev/null || true
}
trap release_lock EXIT INT TERM

PORT=$BASE_PORT
while lsof -nP -iTCP:"$PORT" -sTCP:LISTEN > /dev/null 2>&1; do
  PORT=$((PORT + 1))
done
export PORT

sh -c "$LAUNCH_CMD"

END=$(($(date +%s) + TIMEOUT))
while [ "$(date +%s)" -lt "$END" ]; do
  if sh -c "$HEALTH_CMD" > /dev/null 2>&1; then
    echo "$PORT"
    exit 0
  fi
  sleep 2
done

echo "server on port $PORT not healthy after ${TIMEOUT}s" >&2
PID=$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n1 || true)
[ -z "$PID" ] || kill "$PID" 2>/dev/null || true
exit 1
