#!/bin/sh
set -eu

MAIN=$1
LAUNCH_CMD=${2:-}
TIMEOUT=${3:-600}

es_up() {
  curl -sS -m 5 -u elastic:changeme -D - -o /dev/null http://localhost:9200 2>/dev/null |
    grep -qi '^x-elastic-product: Elasticsearch'
}

PID=$(lsof -nP -tiTCP:9200 -sTCP:LISTEN 2>/dev/null | head -n1 || true)
if [ -n "$PID" ]; then
  if ! es_up; then
    echo "port 9200 is busy with a non-Elasticsearch service (pid $PID)" >&2
    exit 1
  fi
  CWD=$(lsof -a -p "$PID" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  case "$CWD" in
    "$MAIN" | "$MAIN"/*)
      echo "elasticsearch already running (pid $PID)"
      exit 0
      ;;
    *)
      echo "unexpected Elasticsearch running from $CWD" >&2
      exit 1
      ;;
  esac
fi

if [ -z "$LAUNCH_CMD" ]; then
  echo "no Elasticsearch on 9200 and no launch command given" >&2
  exit 1
fi

cd "$MAIN"
sh -c "$LAUNCH_CMD"

END=$(($(date +%s) + TIMEOUT))
while [ "$(date +%s)" -lt "$END" ]; do
  if es_up; then
    echo "elasticsearch ready"
    exit 0
  fi
  sleep 3
done

echo "elasticsearch not ready after ${TIMEOUT}s" >&2
exit 1
