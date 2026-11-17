---
name: teardown
description: Remove a finished Kibana feature worktree, its servers, its stored state, and its local folder after its PR merges or the work is abandoned. Invoke explicitly with a branch name.
disable-model-invocation: true
---

# Teardown

Stops one branch's servers and removes its worktree, stored state, and local folder.

Run every step from outside the target worktree. Closing the worktree's terminals
kills the agent running inside it, so teardown never finishes there.

## Resolve

Load the `orca-cli` skill. Capture the worktree path and full id from
`ORCA worktree show --worktree name:kibana-<branch-safe> --json`, where
`<branch-safe>` is the branch with `/` replaced by `-` (`init-worktree` names every
worktree this way). Use the id as the selector in the next steps.

## Relocate

If the current directory is the worktree path or inside it, spawn a session in the
main clone and stop. Tell the user the teardown continues in the new terminal.

```bash
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
~/.agents/skills/spawn-session/scripts/spawn-session.sh "$MAIN" "teardown <branch>" "Load the teardown skill and follow it for <branch>"
```

## Remove

1. Close every terminal in the worktree; this kills the Elasticsearch, Kibana, and
   Storybook process trees running in them. If the result is `unverifiable`, stop and
   report the terminals still open:

   ```text
   ORCA terminal close --worktree id:<worktree.id> --all --json
   ```

2. Remove the worktree. It can take over two minutes, so run it as a background
   command (the Bash tool's `run_in_background`) and wait for it to finish. Never end
   the command with `&`, which kills the job when the shell exits:

   ```text
   ORCA worktree rm --worktree id:<worktree.id> --force --json
   ```

## Verify

1. Confirm the local folder is gone and delete any leftover. Removal normally deletes
   it, but the directory can survive when processes hold files. Only ever target that
   worktree's own path:

   ```bash
   ls -d <worktree-path> >/dev/null 2>&1 && rm -rf <worktree-path>
   ```

2. Verify the worktree's Kibana and Elasticsearch ports (`kibana:<port>` and
   `es:<port>` terminal titles) no longer have a listener.

3. When `worktree show` reported a `linkedPR`, delete the local PR ref that
   `init-worktree` fetched:

   ```bash
   MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   git -C "$MAIN" update-ref -d refs/remotes/pr/<linkedPR>
   ```

4. Remove the work artifacts (`<work-id>` as defined in `AGENTS.md`):

   ```bash
   rm -rf "$HOME/Code/ai-generated/<work-id>"
   ```

## Feed the review eval

When the PR merged, start the `review-eval` automation if its precheck finds work.
It runs in its own Orca session, so do not wait for it:

```bash
if ~/.agents/skills/review-eval/scripts/pending.sh; then
  ORCA automations run --id "$(ORCA automations list --json | jq -r '.result.automations[] | select(.name == "review-eval") | .id')" --json
fi
```

Skip this step when the work was abandoned.

## Close this terminal

Run this last. It kills the agent, so nothing runs after it. Skip it when the
teardown ran directly in the user's own terminal (no `/teardown` session spawned by
the Relocate step).

```bash
ORCA terminal close --terminal "$ORCA_TERMINAL_HANDLE" --tab --json
```
