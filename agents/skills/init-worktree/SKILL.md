---
name: init-worktree
description: Provision a Kibana worktree with bootstrap, development config, and CodeGraph indexing. Uses the PR's branch when a PR link is given (to test the PR), otherwise branches from upstream/main. Moves the session into the new worktree. No servers are started.
disable-model-invocation: true
---

# Init worktree

Provisions one Kibana worktree and moves the session into it. It never starts
Elasticsearch, Kibana, or Storybook, and runs no workflow. A caller may pass a tag and
an instruction for the new session; this skill passes them on without interpreting
them. A caller that must keep its own session may ask for no handoff.

When the request contains a PR link or number, the worktree uses that PR's head
branch. Otherwise the worktree branches from `upstream/main`. Branch naming for a new
branch: `fix/`, `feat/`, `perf/`, or `refactor/` plus a short description.

Worktrees live beside the primary Kibana checkout, in its parent directory. Never
create one inside the checkout. Orca reads its location from the project setting
"Worktree Location", which must be that parent directory, with the global "Nest
Workspaces" setting off. After `worktree create`, stop and report if the returned
path is not directly under that parent directory.

Before the first Orca command, load the `orca-cli` skill, resolve the `ORCA`
executable, run `ORCA skills get orca-cli`, and confirm the app with
`ORCA status --json`.

## Update the primary worktree

Fetch `upstream/main`. Fast-forward the primary `main` checkout only when it is on
`main`, has no tracked or untracked changes, and has not diverged. Otherwise leave it
unchanged.

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

## Resolve the PR

Skip this section when the request has no PR. Read the PR metadata and fetch its head into a local ref. The fetch works for
branches on forks too.

```bash
PR=<number from the link>
gh pr view "$PR" --repo elastic/kibana --json headRefName,state
git -C "$MAIN" fetch upstream "pull/$PR/head:refs/remotes/pr/$PR" --force
```

Use `headRefName` as `<branch>`. Stop and report when the PR is closed or merged.

## Create the worktree

Without a PR:

```text
ORCA repo list --json
ORCA worktree create --repo id:<kibanaRepoId> --name <branch> \
  --base-branch upstream/main --no-parent --setup skip --json
```

With a PR. `--branch` keeps the PR's own branch name instead of an Orca prefix:

```text
ORCA repo list --json
ORCA worktree create --repo id:<kibanaRepoId> --name <branch> --branch <branch> \
  --base-branch pr/<number> --pr <number> --no-parent --setup skip --json
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
from the JSON. Read the actual branch with
`git -C <worktree.path> branch --show-current`. Without a PR, Orca may prefix the
requested name, such as `rmyz/fix-...`. With a PR, the branch must equal the PR's
`headRefName`.

## Bootstrap

Start bootstrap in an Orca terminal so later work continues while it runs:

```text
ORCA terminal create --worktree id:<worktree.id> --title bootstrap \
  --command "kbnb; exit \$?" --json
```

Anything that needs built packages (Kibana, type checks, tests) must first confirm
bootstrap succeeded: `ORCA terminal wait --terminal <handle> --for exit --timeout-ms
2400000 --json`, then `ORCA terminal read` to check the outcome.

## Index with CodeGraph

Reuse the primary worktree's index when it is complete and compatible with the
installed CodeGraph version. Copy only the SQLite database through `.backup`; never
copy or link daemon state, sockets, locks, or WAL files. Then sync the snapshot with
the new worktree. Fall back to a full index when the primary worktree has no usable
index.

Snapshot the primary index without waiting for a sync. Run the worktree sync in the
background so `codegraph_explore` becomes available without blocking provisioning.
CodeGraph aborts when its parent process exits, so keep a background shell alive as
its parent:

```bash
WORKTREE=<worktree.path>
BRANCH_SAFE=$(git -C "$WORKTREE" branch --show-current | tr / -)
mkdir -p "$HOME/Code/ai-generated/$BRANCH_SAFE/files"
LOG="$HOME/Code/ai-generated/$BRANCH_SAFE/files/codegraph.log"

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

Nothing copies the ignored development config into a new worktree. Run the block: it
copies the file when missing or stale and verifies the result.

```bash
test -f "$MAIN/config/kibana.dev.yml"
cmp -s "$MAIN/config/kibana.dev.yml" "$WORKTREE/config/kibana.dev.yml" || \
  cp "$MAIN/config/kibana.dev.yml" "$WORKTREE/config/kibana.dev.yml"
cmp -s "$MAIN/config/kibana.dev.yml" "$WORKTREE/config/kibana.dev.yml"
```

Treat a failed final comparison as a blocker.

## Move to the new worktree

Provisioning is complete only when the worktree exists, bootstrap is running in its
terminal, CodeGraph indexing has started, and the development config verification
passed.

When the caller asked for no handoff, skip the spawn and the tab close. Report the
branch, the absolute worktree path, the worktree id, the bootstrap terminal handle,
and the PR URL when there is one. Then stop.

Otherwise, the terminal that received the request still belongs to the old Orca card,
and Orca cannot move a live terminal between worktrees. Continue in a fresh session of the
same agent in a new terminal tab in the new worktree. The session has no prior
conversation, so the prompt carries everything it needs. Always start it with
`spawn-session.sh`; do not build the command yourself:

```bash
"$HOME/.agents/skills/spawn-session/scripts/spawn-session.sh" "<worktree.path>" "<tag> <branch>" \
  "<tag> <branch>: Worktree: <worktree.path>. Bootstrap: <bootstrap-handle>. PR: <number, when there is one>. Request: <original request verbatim>. <caller instruction, when given>"
```

The tag is the caller's, or `[PR]` with a PR and `[NEW]` without. Exit `2` means this
session runs outside Orca: report the printed command, then stop.

After the new terminal starts, close the old terminal's whole tab with
`ORCA terminal close --terminal <old-handle> --tab --json`. The old handle comes from
`ORCA_TERMINAL_HANDLE`. Skip this step when `ORCA_TERMINAL_HANDLE` is unset, as in
Orca chat.

Report the branch, the absolute worktree path, and the PR URL when there is one. End
this session. The new session starts with `pwd -P`, which must equal
`<worktree.path>`; it stops if it does not.
