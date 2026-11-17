---
name: request-reviews
description: Draft per-team codeowners review-request messages for an open elastic/kibana PR. Invoke explicitly with a PR number or URL when the user wants the review-request messages.
disable-model-invocation: true
---

# Request reviews

Drafts one review-request message per owning team for a Kibana PR.

## Steps

1. Resolve the PR number from the argument:
   `gh pr view <arg> --repo elastic/kibana --json number -q .number`.
2. Group changed files by owner set:

   ```bash
   (cd ~/Code/kibana-operations/triage && node code-owners.js "$PR_NUMBER")
   ```

3. Draft one message per team. A team that appears in several owner sets gets one
   message with all its files. Take `<one-line description>` from the PR title:

   > Hey team, I need your codeowners review in this PR. It <one-line description> and
   > modifies these files: <that team's files>

4. Present all messages and end. The user sends them after `gh pr ready <PR_NUMBER>`.
