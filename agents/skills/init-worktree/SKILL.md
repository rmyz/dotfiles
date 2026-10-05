---
name: init-worktree
description: Provision a Kibana feature worktree from upstream/main with bootstrap, development config, and CodeGraph indexing. Orca worktree by default, Worktrunk fallback. No servers are started. Used standalone or as the first step of ship.
disable-model-invocation: true
---

# Init worktree

Provisions one Kibana feature worktree. It never starts Elasticsearch, Kibana, or
Storybook; server startup belongs to the phase that needs it.

Branch naming: `fix/`, `feat/`, `perf/`, or `refactor/` plus a short description.

## Update the primary worktree

Fetch `upstream/main` before creating the worktree. Fast-forward the primary `main`
checkout only when it is on `main`, has no tracked or untracked changes, and has not
diverged. Otherwise leave it unchanged and continue from the fetched remote branch.

```bash
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
git -C "$MAIN" fetch upstream main

if test "$(git -C "$MAIN" branch --show-current)" = main && \
  test -z "$(git -C "$MAIN" status --porcelain)" && \
  git -C "$MAIN" merge-base --is-ancestor HEAD upstream/main
then
  git -C "$MAIN" merge --ff-only upstream/main
fi
```

## Create the worktree (inside Orca, default)

Before the first Orca command, load the `orca-cli` skill, resolve the `ORCA`
executable, run `ORCA skills get orca-cli`, and confirm the app with
`ORCA status --json`.

```text
ORCA repo list --json
ORCA worktree create --repo id:<kibanaRepoId> --name <branch> \
  --base-branch upstream/main --no-parent --setup skip --json
```

If `worktree create` returns `runtime_unavailable`, treat the result as unknown.
Do not retry the create command. The runtime can create the worktree before it drops
the response. Check the result with:

```text
ORCA worktree list --repo id:<kibanaRepoId> --json
```

Continue when exactly one worktree has the requested `displayName`. Use its `id` and
`path`. Report the original error when there is no match. Stop and ask which worktree
to use when there is more than one match.

Capture the full `worktree.id` (`<repoId>::<worktreePath>`) and the worktree path
from the JSON. Use the path as the working directory for every following command, and
restore it at the start of every resumed phase.

Start bootstrap immediately in an Orca terminal so later work continues while it
runs:

```text
ORCA terminal create --worktree id:<worktree.id> --title bootstrap \
  --command "kbnb; exit \$?" --json
```

Anything that needs built packages (Kibana, type checks, tests) must first confirm
bootstrap succeeded: `ORCA terminal wait --terminal <handle> --for exit --timeout-ms
2400000 --json`, then `ORCA terminal read` to check the outcome.

The terminal that received the request still belongs to the old Orca card, and Orca
cannot move a live terminal between worktrees. Continue in a fresh session of the
same agent in a new terminal tab in the new worktree. The session has no prior
conversation, so the prompt carries everything it needs: the user's original request
verbatim, the branch, the worktree path, the bootstrap handle, and whether
`init-worktree` was invoked from `ship`.

```bash
CMD=$("$HOME/.agents/skills/ship/scripts/session-command.sh" "<worktree.path>" \
  "[PLAN] <branch>: read ~/.agents/skills/init-worktree/SKILL.md and continue it in this worktree from 'Index with CodeGraph'. Worktree: <worktree.path>. Bootstrap: <bootstrap-handle>. Invoked from ship: <yes|no>. Request: <original request>" \
  <ship-plan when invoked from ship, otherwise build>)
```

The third argument only selects the OpenCode agent; other agents ignore it.

```text
ORCA terminal create --worktree id:<worktree.id> --title "[PLAN] <branch>" \
  --command "$CMD" --focus --json
```

After the new terminal starts, close the old terminal's whole tab with
`ORCA terminal close --terminal <old-handle> --tab --json`. The old handle comes from
`ORCA_TERMINAL_HANDLE`.

In the new session, run `pwd -P` first. It must equal `<worktree.path>`; stop if it
does not. Then finish every remaining init-worktree step below (CodeGraph indexing,
development config) before anything else; provisioning completes before the plan
phase starts.

## Create the worktree (outside Orca, fallback)

```bash
wt switch --create <branch> --base upstream/main
```

Capture the new worktree path from Worktrunk's output and use it as the tool working
directory. `wt` starts `pnpm kbn bootstrap` in the background; confirm it completed
through `wt config state logs` before anything that needs built packages.

## Index with CodeGraph

Reuse the primary worktree's index when it is complete and compatible with the
installed CodeGraph version. Copy only the SQLite database through `.backup`; never
copy or link daemon state, sockets, locks, or WAL files. Then sync the snapshot with
this worktree. Fall back to a full index when the primary worktree has no usable
index.

Snapshot the primary index without waiting for a sync. Run the worktree sync in the
background so `codegraph_explore` becomes available without blocking provisioning.
CodeGraph aborts when its parent process exits, so keep a background shell alive as
its parent:

```bash
WORKTREE=$(pwd -P)
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
BRANCH_SAFE=$(git branch --show-current | tr / -)
mkdir -p "$HOME/Code/oc-generated/files"
LOG="$HOME/Code/oc-generated/files/codegraph-$BRANCH_SAFE.log"

if codegraph status "$MAIN" --json 2>/dev/null | \
  jq -e '.initialized and .index.state == "complete" and (.index.reindexRecommended | not)' >/dev/null
then
  mkdir -p "$WORKTREE/.codegraph"
  sqlite3 "$MAIN/.codegraph/codegraph.db" \
    ".backup \"$WORKTREE/.codegraph/codegraph.db\""
  nohup sh -c 'codegraph sync "$1"' sh "$WORKTREE" >> "$LOG" 2>&1 &
else
  nohup sh -c 'codegraph init -y "$1"' sh "$WORKTREE" > "$LOG" 2>&1 &
fi
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
only then read `~/.agents/skills/ship-plan/SKILL.md` and continue with it in the same session.
