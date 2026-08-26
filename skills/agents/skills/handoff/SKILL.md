---
name: handoff
description: Draft per-team codeowners review-request messages for an open elastic/kibana PR. Invoke explicitly with a PR number or URL when the user wants the handoff messages.
disable-model-invocation: true
---

# Handoff

Drafts one review-request message per owning team for a Kibana PR. It never posts
anything.

## Steps

1. Resolve the PR number from the argument with `gh pr view`. Confirm the target repo
   is `elastic/kibana`.
2. Group changed files by owner set:

   ```bash
   co <PR_NUMBER>
   ```

3. `co` groups files by owner set. Merge duplicate entries by team before drafting one
   message per team:

   > Hey team, I need your codeowners review in this PR. It <one-line description> and
   > modifies these files: <that team's files>

4. Present all messages and end. Do not post them. The user sends them after
   `gh pr ready <PR_NUMBER>`.
