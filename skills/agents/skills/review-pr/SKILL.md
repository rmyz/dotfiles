---
name: review-pr
description: Review a Kibana pull request while preparing its local Worktrunk, Elasticsearch, and Kibana environment for manual testing. Invoke explicitly with a GitHub PR URL.
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

Replace `<PR_URL>` with the supplied URL:

```text
Prepare the local Kibana test environment for <PR_URL>. Do not review or edit code and
do not post anything to GitHub.

Work from /Users/sromeu/Code/kibana. Run `wt switch "<PR_URL>" --no-cd` to check out
the PR in its own Worktrunk worktree. Do not use `--create`; Worktrunk resolves PR and
fork refs. Capture the resulting worktree path. If that PR already has a worktree,
reuse it.

Use the PR worktree as the working directory for every following command. Wait for
the Worktrunk bootstrap hook and verify it succeeded with `wt config state logs`.

Load the `ship` skill and follow only its "Step 4: Start the shared development stack"
instructions. Reuse the shared Elasticsearch on port 9200 when healthy. Start it from
the primary main worktree only when absent. Reuse or start a Kibana process owned by
the PR worktree on the lowest free port starting at 5601. Do not run Ship's other
steps, tests, validation, or teardown.

Return the PR branch and commit, worktree path, bootstrap status, Elasticsearch
status, Kibana URL, and startup log path. Report failures with the command and log
that failed. Leave successful processes and the worktree running for manual testing.
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
- Startup log: <absolute path>
```

If environment setup failed, still return the complete review report and put the
failure under `Local test environment`. Keep successful processes running. Do not
remove the worktree automatically.
