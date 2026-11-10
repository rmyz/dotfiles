---
name: review-pr
description: Review a Kibana pull request while preparing its local worktree, Elasticsearch, and Kibana environment for manual testing. Invoke explicitly with a GitHub PR URL.
disable-model-invocation: true
---

# Review PR

Checks the PR out in a local worktree, then runs `cross-review` on it while the
test environment starts. It reports findings and copy-ready comments, but never posts
comments or changes code.

## Input

Require one `https://github.com/elastic/kibana/pull/<number>` URL. Ask for it when
missing. Reject non-Kibana PRs because the local stack instructions are Kibana-specific.

Read the PR metadata with `gh` before starting. Stop on authentication failure or an
invalid PR. More than 50 changed files uses cross-review's confirmation gate.

## Workflow

### 1. Create the worktree

Read `~/.agents/skills/init-worktree/SKILL.md` and follow it for the
supplied PR URL, with no handoff: do not spawn a session and do not close any terminal.
It creates the worktree on the PR's branch and starts bootstrap, the dev config copy,
and CodeGraph indexing.

### 2. Run review and environment setup together

Start both at the same time:

- The review: load `~/.agents/skills/cross-review/SKILL.md` and follow it in local
  mode from the worktree, against `upstream/main`. The checked-out branch is the PR
  head, so the local diff is the PR diff. Give it the PR description as the intent and
  ask for paste-ready PR comments. Run it from the worktree and use its output as the
  review.
- The environment: one general-purpose subagent with the prompt below.

Replace `<PR_URL>`, `<worktree-path>`, and `<bootstrap-handle>`:

```text
Prepare the local Kibana test environment for <PR_URL> in the worktree at
<worktree-path>. Do not review or edit code and do not post anything to GitHub.

Load the orca-cli skill and resolve the ORCA executable. Wait for bootstrap with
`ORCA terminal wait --terminal <bootstrap-handle> --for exit` and confirm success with
`terminal read`. Use the worktree as the working directory for every following
command.

Read `~/.agents/skills/kibana-dev-stack/SKILL.md` and follow it for Elasticsearch and Kibana;
skip Storybook. Reuse the shared Elasticsearch on port 9200
when healthy. Start it from the primary main worktree only when absent. Reuse or
start a Kibana owned by the PR worktree on the lowest free port pair starting at 5601. Do
not run ship's other steps, tests, validation, or teardown.

Return the PR branch and commit, worktree path, bootstrap status, Elasticsearch
status, Kibana URL, and which Orca terminals hold the logs. Report failures with the command and output that failed. Leave
successful processes and the worktree running for manual testing.
```

### 3. Report

Return cross-review's report, including its copy-ready conventional comments. Do not
submit a GitHub review or comment.

Append:

```markdown
## Local test environment

- Worktree: <absolute path>
- Branch and commit: <branch> at <sha>
- Elasticsearch: <status and URL>
- Kibana: <status and URL>
- Logs: <Orca terminal titles>
```

If environment setup failed, still return the complete review report and put the
failure under `Local test environment`. Keep successful processes running. Do not
remove the worktree automatically.
