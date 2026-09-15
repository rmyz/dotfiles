---
name: review-pr
description: Review a Kibana pull request while preparing its local worktree, Elasticsearch, and Kibana environment for manual testing. Orca worktrees by default, Worktrunk fallback. Invoke explicitly with a GitHub PR URL.
disable-model-invocation: true
---

# Review PR

Runs Review Team against a remote Kibana PR while preparing the PR's local test
environment. It reports findings and copy-ready comments, but never posts comments or
changes code.

## Input

Require one `https://github.com/elastic/kibana/pull/<number>` URL. Ask for it when
missing. Reject non-Kibana PRs because the local stack instructions are Kibana-specific.

Read the PR metadata with `gh` before starting. Stop on authentication failure or an
invalid PR. More than 50 changed files uses Review Team's existing confirmation gate.

## Workflow

### 1. Prepare Review Team

Load `review-team` in PR review mode. Follow its Steps 0 through 2 exactly. The review
context must come from `gh`, never from the local checkout.

### 2. Run review and environment setup together

At Review Team Step 3, use one `multi_tool_use.parallel` call with seven `task` calls:

- The six reviewer tasks required by Review Team, unchanged.
- One `general` environment task using the prompt below.

Replace `<PR_URL>` and `<number>` with the supplied PR:

```text
Prepare the local Kibana test environment for <PR_URL>. Do not review or edit code and
do not post anything to GitHub.

Inside Orca (default; load the orca-cli skill and resolve the ORCA executable): reuse
the existing worktree already on the PR branch when one exists. Otherwise create one
and check the PR out into it:

  ORCA repo list --json
  ORCA worktree create --repo id:<kibanaRepoId> --name pr-<number> \
    --no-parent --setup skip --json
  gh pr checkout <number>   (run in the new worktree path)
  ORCA worktree set --worktree path:<worktree-path> \
    --display-name "PR #<number>: <short title>" --json

Then start bootstrap in an Orca terminal (`kbnb`),
wait for it with `terminal wait --for exit`, and confirm success with `terminal read`.

Outside Orca (fallback): from /Users/sromeu/Code/kibana run `wt switch "<PR_URL>"
--no-cd` (no `--create`; Worktrunk resolves PR and fork refs), capture the worktree
path, and wait for the bootstrap hook via `wt config state logs`.

Use the PR worktree as the working directory for every following command. Run
init-worktree's "Verify the development config" block.

Load the ship skill and follow only its "Ensure the development stack" section, for
Elasticsearch and Kibana; skip Storybook. Reuse the shared Elasticsearch on port 9200
when healthy. Start it from the primary main worktree only when absent. Reuse or
start a Kibana owned by the PR worktree on the lowest free port starting at 5601. Do
not run ship's other steps, tests, validation, or teardown.

Return the PR branch and commit, worktree path, bootstrap status, Elasticsearch
status, Kibana URL, and where the logs live (Orca terminal titles, or /tmp paths
outside Orca). Report failures with the command and output that failed. Leave
successful processes and the worktree running for manual testing.
```

The environment task is isolated from review acquisition. Its local git operations
must never replace Review Team's GitHub diff or file contents.

### 3. Report

Follow Review Team Steps 4 through 6 to consolidate findings, create the action plan,
and format comments for manual posting. Do not submit a GitHub review or comment.

Append:

```markdown
## Local test environment

- Worktree: <absolute path>
- Branch and commit: <branch> at <sha>
- Elasticsearch: <status and URL>
- Kibana: <status and URL>
- Logs: <Orca terminal titles, or /tmp paths outside Orca>
```

If environment setup failed, still return the complete review report and put the
failure under `Local test environment`. Keep successful processes running. Do not
remove the worktree automatically.
