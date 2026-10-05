---
name: unblock-pr
description: Progress an open elastic/kibana PR that has new review comments, merge conflicts, or failing CI. Invoke explicitly with a PR number or URL; with no argument, it targets the current branch's PR.
disable-model-invocation: true
---

# Unblock PR

Moves one open Kibana PR past whatever blocks it: review comments, merge conflicts,
or failing checks. The flow is:

`Comments -> Mergeability -> CI`

Never post comments, reviews, or label changes without explicit approval. Fixing code
and pushing approved fixes is allowed. Exception: always comment `/ci` after pushing
changes to a draft PR to trigger CI.

## Step 0: Resolve the PR

With a PR number or URL argument, use it. With no argument, resolve the current
branch's PR:

```bash
gh pr view --repo elastic/kibana --json number -q .number
```

If the branch has no open PR, stop and report it.

## Step 1: Comments

Fetch all unresolved review threads and issue comments newer than the last handled
batch:

```bash
gh pr view <PR_NUMBER> --comments
gh api repos/elastic/kibana/pulls/<PR_NUMBER>/comments
gh api repos/elastic/kibana/issues/<PR_NUMBER>/comments
```

If there are no new comments, skip to step 2.

If there are new comments, load `review-pr-comments` with their links to triage each
one as accept or push back. Present the triage result, then **stop** and wait for the
user's confirmation on how to proceed before changing any code or replying.

## Step 2: Mergeability

Check whether the branch merges cleanly into `upstream/main`:

```bash
git fetch upstream main
git merge-tree "$(git merge-base HEAD upstream/main)" HEAD upstream/main
```

- Conflicts: merge `upstream/main`, resolve every conflict in favor of the correct
  final code (not blind `--ours`), rerun affected validation from `ship` step 6, then
  push. If the PR is a draft, trigger CI. Confirm with the user first when a conflict needs a semantic decision.
- Outdated but mergeable: leave it as is. Do not merge just to refresh the branch.
- If `git merge-tree` output is ambiguous, verify with a local test merge and abort it.

## Step 3: CI

Read the check results:

```bash
gh pr checks <PR_NUMBER>
```

Classify each failure:

- Caused by this branch's code: fix the root cause, rerun the affected local
  validation (`node scripts/jest ...`, type_check, eslint), push the fix, and trigger CI if the PR is a draft.
- Flaky or unrelated to this branch: rerun the failed job once with `/ci` only after
  user approval. If it fails again the same way, investigate instead of rerunning.
- Infrastructure failures (timeouts, runner loss): report them and stop; do not rerun.
- Failing `docs-build`: this check is independent from kibana-ci and can fail intermittently.
  Rerun it with comment `run docs-build` on the PR only after user approval.

### CI on Draft PRs

Kibana draft PRs do not run CI automatically on push. When you push changes to a draft PR in Step 2 or Step 3, always comment `/ci`:

```bash
gh pr comment <PR_NUMBER> --body '/ci'
```

Check the PR draft status if needed:

```bash
gh pr view <PR_NUMBER> --json isDraft -q .isDraft
```

## Completion

When comments are answered, the branch merges cleanly, and CI is green or explained,
present the PR state and end. If anything needs a human decision, list those items and
end; do not wait silently.
