---
name: kibana-dev-stack
description: Start or reuse the shared Elasticsearch and a worktree-owned Kibana (and Storybook) in Orca terminals, decide whether a change needs a running Kibana, run Scout against the stack, and keep the primary checkout current. Idempotent. Used by ship, review-pr, and kibana-verify.
disable-model-invocation: true
---

# Development stack

Starts the services a check needs. The procedure is idempotent: healthy owned
servers are reused, missing ones are started.

The scripts in `~/.agents/skills/kibana-dev-stack/scripts/` own detection, ownership checks, the
port allocation lock, and readiness polling. Each call passes an `ORCA terminal
create` launch command; the scripts export `$PORT` before running it.

Recompute state first, from the feature worktree:

```bash
BRANCH=$(git branch --show-current)
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
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

## Elasticsearch

`scripts/start-es.sh` does the whole check-or-start sequence: it accepts an existing
listener on `9200` only when an authenticated `elastic:changeme` request answers with
the `X-Elastic-Product: Elasticsearch` header and its process runs from `$MAIN` or
`$MAIN/.es`; any other process on `9200` is reported as a blocker. Only when the
port is free does it run the launch command from `$MAIN` and poll until the product
header appears. The `es` alias expands to `pnpm es snapshot --license trial --eis`;
running it through `zsh -ic` picks up the alias and the fnm node version exactly like
a manual terminal.

```bash
"$STACK_SCRIPTS/start-es.sh" "$MAIN" \
  'ORCA terminal create --worktree path:'"$MAIN"' --title es:9200 \
    --command "zsh -ic '"'"'es --use-cached'"'"'" --json'
```

If `path:$MAIN` does not resolve to an Orca-managed worktree, stop and report it
instead of starting Elasticsearch another way. On timeout the script exits nonzero;
read the `es:9200` terminal and stop. Never start a second development Elasticsearch
instance for another worktree.

## Kibana

Reuse a running Kibana only when it serves this worktree; `scripts/check-server.sh`
performs exactly that check (exit `0` reuse, `2` owned but unhealthy, `1` not this
worktree's). The stored port is the `kibana:<port>` title in `ORCA terminal list
--worktree path:$WORKTREE --json`; no title means no stored port. For an owned but
unhealthy server, close its terminal with `ORCA terminal close --terminal <handle>
--json` and wait until the port frees; never kill a PID from a file.

Otherwise `scripts/launch-server.sh` takes the atomic `mkdir` lock at
`/tmp/kibana-port-allocation.lock`, allocates the lowest unused port pair (`$PORT` and
`$PORT + 1`), stepping by 2 from `5601`, runs the launch command with `$PORT`
exported, polls the health command until ready, prints the port, and releases the lock. The `kbn` alias expands to
`pnpm start --eis`.

```bash
HEALTH='curl -fsSL -o /dev/null -u elastic:changeme "http://localhost:$PORT/api/status"'
PORT=$("$STACK_SCRIPTS/launch-server.sh" 5601 360 "$HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "kibana:$PORT" \
    --command "zsh -ic '"'"'kbn --port $PORT --dev.basePathProxyTarget=$((PORT + 1))'"'"'" --json' 2)
```

The terminal title is the port's system of record; nothing else stores it. Kibana
serves under a random 3-letter base path; the root URL on the allocated port
redirects to it. On startup failure, read the `kibana:<port>` terminal before
retrying once. Report the healthy URL.

## Storybook

Skip this section unless the plan includes Storybook file changes. Read
`src/dev/storybook/aliases.ts` and match each changed file against alias target
directories, keeping the deepest match. If no
alias matches, stop and ask which alias to use instead of guessing.

Reuse through `scripts/check-server.sh` with the `storybook:<port>` terminal title,
exactly like Kibana. Otherwise allocate and start from base port `9001`.
`scripts/storybook` hardcodes port `9001` and has no `--port` flag, so the launch
command invokes the resolved config directory directly instead of the wrapper:

```bash
STORYBOOK_HEALTH='curl -fsS "http://localhost:$PORT"'
PORT=$("$STACK_SCRIPTS/launch-server.sh" 9001 300 "$STORYBOOK_HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "storybook:$PORT" \
    --command "pnpm storybook dev --config-dir <alias-target-dir> -p $PORT" --json')
```

## Scout

Reuse the already-running Kibana and shared Elasticsearch instance only when its
server settings satisfy the test. Create `.scout/servers/local.json` with the current
Kibana URL, Elasticsearch `9200`, `elastic`/`changeme` credentials, a trial license,
and the absolute `.ftr/role_users.json` path. Then run only the local stateful classic
target:

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
    "elasticsearch": "http://localhost:9200"
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
manage another local stack. If a Scout suite requires a custom server config that the
development stack does not provide, the PR is blocked. Do not start a second
Elasticsearch instance or proceed. Resolve the profile conflict or get an explicit
change to the single-Elasticsearch requirement.

## Keep the primary checkout current

`scripts/update-main.sh` fast-forwards the primary `main` from `upstream/main`, runs
`kbnb`, and syncs CodeGraph (a full `codegraph index` when a reindex is recommended).
It skips when the primary checkout is not on a clean `main`. The `update-main` Orca
automation runs it on weekdays.
