---
name: teardown
description: Remove a finished Kibana feature worktree, its servers, its stored state, and its local folder after its PR merges or the work is abandoned. Invoke explicitly with a branch name.
disable-model-invocation: true
---

# Teardown

Stops one branch's servers and removes its worktree, stored state, and local folder.

Run every step from outside the target worktree, for example the main clone, so the
shell's working directory does not disappear mid-teardown.

## Remove

1. Load the `orca-cli` skill and resolve the `ORCA` executable. Capture the worktree
   path and full id from `ORCA worktree show --worktree name:<branch> --json`. Do not use
   `branch:<branch>`: the git branch carries a prefix such as `rmyz/`, so it does not
   match. Use the id as the selector in the next steps.

2. Close every terminal in the worktree; this kills the Kibana and Storybook process
   trees running in them. Stop when the result is `unverifiable`:

   ```text
   ORCA terminal close --worktree id:<worktree.id> --all --json
   ```

3. Remove the worktree:

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

3. Clean up branch-specific artifacts under `~/Code/ai-generated`:
   Replace `/` in the branch name with `-` for `<branch-safe>`.
   ```bash
   rm -f "$HOME/Code/ai-generated/plans/ship-plan-<branch-safe>.md"
   rm -f "$HOME/Code/ai-generated/demo/qa-<branch-safe>"*.webm
   ```
