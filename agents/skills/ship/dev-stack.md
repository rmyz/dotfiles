# Development stack

`[REVIEW]` runs this before behavior QA. `[IMPLEMENT]` starts only the services it
needs during implementation. The procedure is idempotent: healthy owned servers
are reused, missing ones are started. `[PLAN]` never starts servers.

The scripts in `~/.agents/skills/ship/scripts/` own detection, ownership checks, the
port allocation lock, and readiness polling. Both runtimes pass their own launch
command; the scripts export `$PORT` before running it.

Recompute state first, from the feature worktree:

```bash
BRANCH=$(git branch --show-current)
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
SHIP_SCRIPTS="$HOME/.agents/skills/ship/scripts"
WORKTREE=$(pwd -P)
```

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
"$SHIP_SCRIPTS/start-es.sh" "$MAIN" \
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
`/tmp/kibana-port-allocation.lock`, allocates the lowest unused port starting at
`5601`, runs the launch command with `$PORT` exported, polls the health command until
ready, prints the port, and releases the lock. The `kbn` alias expands to
`pnpm start --eis`.

```bash
HEALTH='curl -fsSL -o /dev/null -u elastic:changeme "http://localhost:$PORT/api/status"'
PORT=$("$SHIP_SCRIPTS/launch-server.sh" 5601 360 "$HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "kibana:$PORT" \
    --command "zsh -ic '"'"'kbn --port $PORT'"'"'" --json')
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
PORT=$("$SHIP_SCRIPTS/launch-server.sh" 9001 300 "$STORYBOOK_HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "storybook:$PORT" \
    --command "pnpm storybook dev --config-dir <alias-target-dir> -p $PORT" --json')
```

## Outside Orca

The same scripts run with these substitutions:

- Launch commands become `nohup` strings run through `wt step tether`, with logs in
  `~/Code/ai-generated/files`. Create it first with
  `mkdir -p "$HOME/Code/ai-generated/files"`:

```bash
'nohup wt step tether -- zsh -ic "es --use-cached" > "$HOME/Code/ai-generated/files/kibana-shared-es.log" 2>&1 &'
'nohup wt step tether -- zsh -ic "kbn --port $PORT" > "$HOME/Code/ai-generated/files/kibana-$BRANCH_SAFE-$PORT.log" 2>&1 &'
'nohup pnpm storybook dev --config-dir "<alias-target-dir>" -p "$PORT" > "$HOME/Code/ai-generated/files/storybook-$BRANCH_SAFE-$PORT.log" 2>&1 &'
```

- Server state lives in Worktrunk: read stored ports with `wt config state vars get
  kibana-port` / `storybook-port`, set them after a successful launch, and clear them
  when cleaning up an owned-but-unhealthy server (kill the listener PID from `lsof`,
  then wait until the port frees).
- Logs live in the generated-files paths above; `export
  BRANCH_SAFE=${BRANCH//\//-}` first.
