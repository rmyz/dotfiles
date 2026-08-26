---
name: teardown
description: Remove a finished Kibana feature worktree, its servers, and its stored state after its PR merges or the work is abandoned. Invoke explicitly with a branch name.
disable-model-invocation: true
---

# Teardown

Stops one branch's servers, clears its Worktrunk state, and removes its worktree.

## Steps

1. Clear the branch's stored variables:

   ```bash
   wt config state vars clear --all --branch=<branch>
   ```

2. Remove the worktree with process reaping. `--reap` stops Kibana's entire process
   tree:

   ```bash
   wt remove --reap --foreground <branch>
   ```

3. Verify the worktree's Kibana port no longer has a listener. Do not stop the shared
   Elasticsearch instance while another worktree may use it.
