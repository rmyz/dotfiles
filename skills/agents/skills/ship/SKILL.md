---
name: ship
description: End-to-end Kibana workflow taking one task from intake to a draft PR on elastic/kibana, split into three phases (plan, implement, review) that each run in their own session. Runs on Orca worktrees and terminals by default, with a Worktrunk/Herdr fallback. Invoke explicitly with an issue link, PR number, or task description.
disable-model-invocation: true
---

# Ship

Takes one Kibana task from investigation to a draft PR across three sessions:

`[PLAN] -> [IMPLEMENT] -> [REVIEW]`

Entry point: run the `init-worktree` skill, then load `ship-plan` and continue in
this session. The later phases run in fresh sessions spawned by the previous phase.
This file holds the shared invariants and procedures; every phase skill applies them.

## Runtime

Orca is the default runtime. Before the first Orca command, load the `orca-cli`
skill, resolve the `ORCA` executable, run `ORCA skills get orca-cli`, and confirm the
app with `ORCA status --json`.

Choose the runtime once, at worktree creation, and keep it for the whole task:

- **Inside Orca**: Orca worktrees, Orca terminals for every process, terminal titles
  as server state, `ORCA terminal read` for logs.
- **Outside Orca** (fallback): Worktrunk worktrees, `wt config state vars` as server
  state, `nohup` + `/tmp` logs, Herdr panels for anything the user should watch. The
  "Outside Orca" blocks below define the substitutions.

### Command tabs (inside Orca)

Every process ship starts after worktree creation runs in its own visible Orca
terminal tab: bootstrap, Elasticsearch, Kibana, Storybook, generators, lint, type
checks, tests, `check.js`, and Scout. Use `ORCA terminal create --worktree <selector>
--title <short-title> --command "<exact-command>; exit \$?" --json` for finite
commands; the explicit exit lets `terminal wait --for exit` observe completion. Use
the exact server command without an exit for long-running servers. Do not use
terminal splits, background shell jobs, or reuse a prior command tab.

Wait for finite commands with `ORCA terminal wait --terminal <handle> --for exit
--timeout-ms <timeout> --json`, then read their output with `ORCA terminal read
--terminal <handle> --json`; use cursor reads for long output. Leave every tab open
after completion so the user can inspect and close it. Only close a tab automatically
when ship must restart a failed server or move the session off the old card.

### Card status (inside Orca)

Update the Orca card at phase changes:

```text
ORCA worktree set --worktree path:<worktree-path> --workspace-status in-progress --json
ORCA worktree set --worktree path:<worktree-path> --comment "<one-line phase status>" --json
```

Set the comment at least after plan approval, after validation, and after the draft
PR exists. Set `--workspace-status in-review` when the draft PR is created.

## Invariants

The global rules already cover remotes, the 500-line PR limit, and skill locations;
they are not repeated here.

- Run one shared Elasticsearch instance on port `9200` from the primary `main`
  worktree. Never start Elasticsearch from a feature worktree.
- Run one Kibana instance per active worktree. Allocate the lowest free port starting
  at `5601`, then `5602`, `5603`, and so on.
- Run one Storybook instance per active worktree, only when the approved plan includes
  Storybook changes. Allocate the lowest free port starting at `9001`, then `9002`,
  `9003`, and so on.
- Ship ends at a created draft PR. Reviewer handoff and worktree teardown are separate
  skills: `handoff` and `teardown`.

## Human stops

| Stop          | Phase       | Placed after               | Waits for                                |
| ------------- | ----------- | -------------------------- | ---------------------------------------- |
| Plan approval | `[PLAN]`    | Styled HTML plan           | Explicit approval to implement           |
| Validation    | `[REVIEW]`  | All checks and reviews     | Explicit approval to create the draft PR |

At either stop, present the result and end the response. Do not create todos, inspect
more files, or start the next phase. Absence of objection is not approval. The
`[IMPLEMENT]` phase has no stop; it spawns `[REVIEW]` directly.

## Sessions

One session per phase. The spawn prompt's first characters are the phase tag and
branch (`[IMPLEMENT] <branch>: ...`), so opencode titles the session with them.

The handoff payload between phases is exactly: branch, worktree path, plan file path.
Nothing else. A spawned session treats that payload as the whole truth: its first
actions are to set the worktree as the working directory, read the plan file, and run
`git status` plus `git diff upstream/main...`. There is no prior conversation to
recall.

### Spawning the next phase

`[PLAN]` spawns `[IMPLEMENT]` only after explicit plan approval. `[IMPLEMENT]` spawns
`[REVIEW]` immediately when implementation and deviation notes are complete.

The next session's command is always:

```bash
opencode "<worktree-path>" --prompt "[<PHASE>] <branch>: load the ship-<phase> skill and follow it. Worktree: <worktree-path>. Plan: <plan-file>."
```

Inside Orca, run it in a new Orca terminal, then end this session:

```text
ORCA terminal create --worktree path:<worktree-path> \
  --title "[<PHASE>] <branch>" --command '<the opencode command>' --json
```

Outside Orca, print the exact `opencode` command and ask the user to run it in a new
Herdr panel, then end this session.

## Ensure the development stack

`[IMPLEMENT]` runs this as its first action; `[REVIEW]` runs it again before
validation. The procedure is idempotent: healthy owned servers are reused, missing
ones are started. `[PLAN]` never starts servers.

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

### Elasticsearch

`scripts/start-es.sh` does the whole check-or-start sequence: it accepts an existing
listener on `9200` only when an authenticated `elastic:changeme` request answers with
the `X-Elastic-Product: Elasticsearch` header and its process runs from `$MAIN` or
`$MAIN/.es`; any other process on `9200` is reported as a blocker. Only when the
port is free does it run the launch command from `$MAIN` and poll until the product
header appears. The `es` alias expands to `yarn es snapshot --license trial --eis`;
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

### Kibana

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
`yarn start --eis`.

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

### Storybook

Skip this section unless the approved plan includes Storybook file changes. Resolve
the correct alias first: read `src/dev/storybook/aliases.ts` and match each changed
file path against the alias target directories, keeping the deepest match. If no
alias matches, stop and ask which alias to use instead of guessing.

Reuse through `scripts/check-server.sh` with the `storybook:<port>` terminal title,
exactly like Kibana. Otherwise allocate and start from base port `9001`.
`scripts/storybook` hardcodes port `9001` and has no `--port` flag, so the launch
command invokes the resolved config directory directly instead of the wrapper:

```bash
STORYBOOK_HEALTH='curl -fsS "http://localhost:$PORT"'
PORT=$("$SHIP_SCRIPTS/launch-server.sh" 9001 300 "$STORYBOOK_HEALTH" \
  'ORCA terminal create --worktree path:'"$WORKTREE"' --title "storybook:$PORT" \
    --command "fnm exec --using=.nvmrc yarn storybook dev --config-dir <alias-target-dir> -p $PORT" --json')
```

### Outside Orca

The same scripts run with these substitutions:

- Launch commands become `nohup` strings run through `wt step tether`, with logs in
  `/tmp`:

```bash
'nohup wt step tether -- zsh -ic "es --use-cached" > /tmp/kibana-shared-es.log 2>&1 &'
'nohup wt step tether -- zsh -ic "kbn --port $PORT" > "/tmp/kibana-$BRANCH_SAFE-$PORT.log" 2>&1 &'
'nohup fnm exec --using=.nvmrc yarn storybook dev --config-dir "<alias-target-dir>" -p "$PORT" > "/tmp/storybook-$BRANCH_SAFE-$PORT.log" 2>&1 &'
```

- Server state lives in Worktrunk: read stored ports with `wt config state vars get
  kibana-port` / `storybook-port`, set them after a successful launch, and clear them
  when cleaning up an owned-but-unhealthy server (kill the listener PID from `lsof`,
  then wait until the port frees).
- Logs live in the `/tmp` paths above; `export BRANCH_SAFE=${BRANCH//\//-}` first.
