---
name: kibana-dev-stack
description: Start or reuse a worktree-owned Elasticsearch and Kibana (and Storybook) in Orca terminals, decide whether a change needs a running Kibana, and run Scout against the stack. Idempotent. Used by ship, review-pr, and kibana-verify.
disable-model-invocation: true
---

# Development stack

Starts the services a check needs. The procedure is idempotent: healthy owned
servers are reused, missing ones are started. Always start Elasticsearch first and
wait until it is healthy. Then start Kibana.

The scripts in `~/.agents/skills/kibana-dev-stack/scripts/` own detection, ownership checks, the
port allocation lock, and readiness polling. Each launch command runs through `sh -c`
with `$PORT` exported. `ORCA` in the launch strings below is the placeholder from
`orca-cli`: replace it with the executable you resolved before you run a block.

Recompute state first, from the feature worktree:

```bash
STACK_SCRIPTS="$HOME/.agents/skills/kibana-dev-stack/scripts"
WORKTREE=$(pwd -P)
```

## When a change needs Kibana

A change set needs a running Kibana when any of these holds: it changes code that runs
in Kibana (server, public, or UI code); it changes Storybook stories or components
shown in Storybook; a targeted test named in the plan needs a live server
(integration, API, or UI tests); or the plan names Scout tests. It does not when it
only changes docs, Markdown, unit tests, or config the running app does not read.
Start servers only when it does.

## Reuse a running server

Every server's terminal title holds its port: `es:<port>`, `kibana:<port>`, or
`storybook:<port>`. Read the titles with `ORCA terminal list --worktree
path:$WORKTREE --json`. No title means launch a new server.

```bash
"$STACK_SCRIPTS/check-server.sh" "$PORT" "$WORKTREE" "$HEALTH"
```

`$PORT` is the number in the title. `$HEALTH` is the health command of the section
below. Exit `0` means reuse the server. Exit `1` means no server of this worktree
listens on the port: launch a new one. Exit `2` means the server is owned but
unhealthy: close its terminal with `ORCA terminal close --terminal <handle> --json`,
wait until the port frees, then launch a new one.

## Elasticsearch

Each worktree owns its Elasticsearch. The primary `main` worktree starts nothing.
`scripts/launch-server.sh` allocates the lowest free port from `9200`, stepping by 1,
and starts it. The `es` alias expands to `pnpm es snapshot --license trial --eis`;
running it through `zsh -ic` picks up the alias and the fnm node version exactly like
a manual terminal.

```bash
ES_HEALTH='curl -sS -m 5 -u elastic:changeme -D - -o /dev/null "http://localhost:$PORT" | grep -qi "^x-elastic-product: Elasticsearch"'
ES_PORT=$("$STACK_SCRIPTS/launch-server.sh" 9200 600 "$ES_HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "es:$PORT" \
    --command "zsh -ic '"'"'es --use-cached --port $PORT -E cluster.name=es-$PORT'"'"'" --json')
```

When you reuse a server, set `ES_PORT` to the port in its `es:<port>` title. On
timeout the script exits nonzero: read the `es:<port>` terminal and stop. The unique
`cluster.name` keeps nodes from joining one cluster. Without it, two local nodes
discover each other on the transport ports and share indices.

## Kibana

`scripts/launch-server.sh` takes the atomic `mkdir` lock at
`/tmp/kibana-port-allocation.lock`, allocates the lowest unused port pair (`$PORT` and
`$PORT + 1`), stepping by 2 from `5601`, runs the launch command with `$PORT`
exported, polls the health command until ready, prints the port, and releases the lock.
`kbn <port>` is a shell function that adds `--port=<port>` and
`--dev.basePathProxyTarget=<port+1>`. Kibana connects to this worktree's Elasticsearch
through `--elasticsearch.hosts`.

```bash
HEALTH='curl -fsSL -o /dev/null -u elastic:changeme "http://localhost:$PORT/api/status"'
PORT=$("$STACK_SCRIPTS/launch-server.sh" 5601 360 "$HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "kibana:$PORT" \
    --command "zsh -ic '"'"'kbn $PORT --elasticsearch.hosts=http://localhost:'"$ES_PORT"''"'"'" --json' 2)
```

The terminal title is the port's system of record; nothing else stores it. Kibana
serves under a random 3-letter base path. The root URL on the port redirects to it:
get the full URL with `curl -sI http://localhost:$PORT | grep -i '^location'`. On
startup failure, read the `kibana:<port>` terminal before retrying once. Report the
healthy URL with its base path.

## Storybook

Skip this section unless the plan includes Storybook file changes. Read
`src/dev/storybook/aliases.ts` and match each changed file against alias target
directories, keeping the deepest match. If no
alias matches, stop and ask which alias to use instead of guessing.

Reuse as described above, with `$HEALTH` set to `$STORYBOOK_HEALTH`. Otherwise
allocate and start from base port `9001`. `scripts/storybook` hardcodes port `9001`
and has no `--port` flag, so the launch command invokes the resolved config directory
directly instead of the wrapper:

```bash
STORYBOOK_HEALTH='curl -fsS "http://localhost:$PORT"'
PORT=$("$STACK_SCRIPTS/launch-server.sh" 9001 300 "$STORYBOOK_HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "storybook:$PORT" \
    --command "pnpm storybook dev --config-dir <alias-target-dir> -p $PORT" --json')
```

## Scout

Run Scout against this stack when the suite needs no custom server configuration:
its `playwright.config.ts` targets the default local stateful classic servers.
Otherwise report the PR as blocked and stop. Create `.scout/servers/local.json` with
the Kibana URL, Elasticsearch `<es-port>`, `elastic`/`changeme` credentials, a trial
license, and the absolute `.ftr/role_users.json` path:

```json
{
  "serverless": false,
  "http2": false,
  "uiam": false,
  "isCloud": false,
  "cloudUsersFilePath": "<absolute-worktree>/.ftr/role_users.json",
  "license": "trial",
  "hosts": {
    "kibana": "http://localhost:<kibana-port>",
    "elasticsearch": "http://localhost:<es-port>"
  },
  "auth": { "username": "elastic", "password": "changeme" }
}
```

Run:

```bash
node scripts/playwright test --config <playwright.config.ts> \
  --project local --grep @local-stateful-classic
```

Do not run `node scripts/scout start-server` or `node scripts/scout run-tests`; both
manage another local stack.
