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

Load the `orca-cli` skill and resolve the `ORCA` executable. Capture the worktree
path and full id from `ORCA worktree show --worktree name:<branch> --json`. Do not use
`branch:<branch>`: the git branch carries a prefix such as `rmyz/`, so it does not
match. Use the id as the selector in the next steps.

## Relocate

If the current directory is the worktree path or inside it, spawn a session in the
main clone and stop. Tell the user the teardown continues in the new terminal. Do
nothing else here.

```bash
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
~/.agents/skills/spawn-session/scripts/spawn-session.sh "$MAIN" "teardown <branch>" "/teardown <branch>"
```

## Remove

1. Close every terminal in the worktree; this kills the Kibana and Storybook process
   trees running in them. Stop when the result is `unverifiable`:

   ```text
   ORCA terminal close --worktree id:<worktree.id> --all --json
   ```

2. Remove the worktree. It can take over two minutes, so run it as a background
   command and wait for it. Never end the command with `&` in a shell, which kills
   the job when the shell exits:

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

2. Verify the worktree's Kibana port no longer has a listener. Do not stop the shared
   Elasticsearch instance while another worktree may use it. When Elasticsearch was
   started from inside the removed worktree (its `.es/` directory lives there),
   stopping the worktree's processes stops it too, so report that.

3. When `worktree show` reported a `linkedPR`, delete the local PR ref that
   `init-worktree` fetched:

   ```bash
   MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   git -C "$MAIN" update-ref -d refs/remotes/pr/<linkedPR>
   ```

4. Remove the work artifacts. `<work-id>` is the branch name with `/` replaced
   by `-`:

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
