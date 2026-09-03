---
name: teardown
description: Remove a finished Kibana feature worktree, its servers, its stored state, and its local folder after its PR merges or the work is abandoned. Orca worktrees by default, Worktrunk fallback. Invoke explicitly with a branch name.
disable-model-invocation: true
---

# Teardown

Stops one branch's servers and removes its worktree, stored state, and local folder.

Run every step from outside the target worktree, for example the main clone, so the
shell's working directory does not disappear mid-teardown.

Resolve the runtime first: if `ORCA worktree show --worktree branch:<branch> --json`
resolves, the worktree is Orca-managed. Otherwise use the Worktrunk fallback.

## Inside Orca (default)

1. Capture the worktree path and full id from `worktree show`.

2. Stop every terminal in the worktree; this kills the Kibana and Storybook process
   trees running in them:

   ```text
   ORCA terminal stop --worktree branch:<branch> --json
   ```

3. Remove the worktree:

   ```text
   ORCA worktree rm --worktree branch:<branch> --force --json
   ```

## Outside Orca (fallback)

1. Clear the branch's stored variables:

   ```bash
   wt config state vars clear --all --branch=<branch>
   ```

2. Remove the worktree with process reaping. `--reap` stops Kibana's entire process
   tree:

   ```bash
   wt remove --reap --foreground <branch>
   ```

## Verify (both runtimes)

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
