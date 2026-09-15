---
name: init-worktree
description: Provision a Kibana feature worktree from upstream/main with bootstrap, development config, and CodeGraph indexing. Orca worktree by default, Worktrunk fallback. No servers are started. Used standalone or as the first step of ship.
disable-model-invocation: true
---

# Init worktree

Provisions one Kibana feature worktree. It never starts Elasticsearch, Kibana, or
Storybook; server startup belongs to the phase that needs it.

Branch naming: `fix/`, `feat/`, `perf/`, or `refactor/` plus a short description.

## Create the worktree (inside Orca, default)

Before the first Orca command, load the `orca-cli` skill, resolve the `ORCA`
executable, run `ORCA skills get orca-cli`, and confirm the app with
`ORCA status --json`.

Capture the current OpenCode session ID first, from `opencode session list --format
json`: the newest session whose `directory` equals the current working directory. Do
not create a second OpenCode session for the task.

```text
git fetch upstream main
ORCA repo list --json
ORCA worktree create --repo id:<kibanaRepoId> --name <branch> \
  --base-branch upstream/main --no-parent --setup skip --json
```

Capture the full `worktree.id` (`<repoId>::<worktreePath>`) and the worktree path
from the JSON. Use the path as the working directory for every following command, and
restore it at the start of every resumed phase.

Start bootstrap immediately in an Orca terminal so later work continues while it
runs:

```text
ORCA terminal create --worktree id:<worktree.id> --title bootstrap \
  --command "kbnb" --json
```

Anything that needs built packages (Kibana, type checks, tests) must first confirm
bootstrap succeeded: `ORCA terminal wait --terminal <handle> --for exit --timeout-ms
2400000 --json`, then `ORCA terminal read` to check the outcome.

The terminal that received the request still belongs to the old Orca card, and Orca
cannot move a live terminal between worktrees. Resume the same OpenCode session in a
new terminal tab in the new worktree:

```text
ORCA terminal create --worktree id:<worktree.id> --title "[PLAN] <branch>" \
  --command 'opencode "<worktree.path>" --session "<session-id>"' \
  --focus --json
ORCA terminal wait --terminal <new-handle> --for tui-idle --timeout-ms 60000 --json
ORCA terminal send --terminal <new-handle> \
  --text "Continue init-worktree in this worktree. Bootstrap: <bootstrap-handle>." \
  --enter --json
```

After the continuation input is accepted, close the old terminal's whole tab with
`ORCA terminal close --terminal <old-handle> --tab --json`. The old handle comes from
`ORCA_TERMINAL_HANDLE`. A short overlap between two TUI clients is acceptable; two
OpenCode session IDs are not.

In the resumed session, run `pwd -P` first. It must equal `<worktree.path>`; stop if
it does not. The full conversation is already present. Do not send a handoff prompt
or repeat the user request. Then finish every remaining init-worktree step below
(CodeGraph indexing, development config) before anything else; provisioning completes
before the plan phase starts.

## Create the worktree (outside Orca, fallback)

```bash
git fetch upstream main
wt switch --create <branch> --base upstream/main
```

Capture the new worktree path from Worktrunk's output and use it as the tool working
directory. `wt` starts `pnpm kbn bootstrap` in the background; confirm it completed
through `wt config state logs` before anything that needs built packages.

## Index with CodeGraph

Start indexing in the background so `codegraph_explore` answers from this worktree's
own files. `codegraph init` aborts when its parent process exits, so keep a
background shell alive as its parent:

```bash
nohup sh -c 'codegraph init -y "$(pwd -P)"' \
  > "/tmp/codegraph-init-$(git branch --show-current | tr / -).log" 2>&1 &
```

## Verify the development config

Only the Worktrunk fallback has a hook that copies the ignored development config;
inside Orca nothing copies it for you. Either way, run the block: it copies the file
when missing or stale and verifies the result.

```bash
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
test -f "$MAIN/config/kibana.dev.yml"
cmp -s "$MAIN/config/kibana.dev.yml" config/kibana.dev.yml || \
  cp "$MAIN/config/kibana.dev.yml" config/kibana.dev.yml
cmp -s "$MAIN/config/kibana.dev.yml" config/kibana.dev.yml
```

Treat a failed final comparison as a blocker.

## Done

Provisioning is complete only when the worktree exists, bootstrap is running in its
terminal, CodeGraph indexing has started, and the development config verification
passed. Report the branch and the absolute worktree path. When invoked from `ship`,
only then continue with `ship-plan` in the same session.
