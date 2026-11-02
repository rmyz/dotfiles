---
name: unblock-pr
description: Triage review comments on an elastic/kibana PR, or move the PR past review comments, merge conflicts, and failing CI. Use with PR comment links, a PR number or URL, or no argument for the current branch's PR. Also use when the user asks whether to accept review feedback.
---

# Unblock PR

Moves one open Kibana PR past whatever blocks it: review comments, merge conflicts,
or failing checks. The flow is:

`Comments -> Mergeability -> CI -> Wait`

Never post comments, replies, reviews, reactions, or label changes, never resolve
threads, and never retry CI jobs without explicit approval. Fixing code and pushing
approved fixes is allowed. Exception: always comment `/ci` after pushing changes to
a draft PR to trigger CI. Never run `gh pr ready`.

`pr.mjs` below means `node ~/Code/kibana/.agents/skills/pr-babysit/scripts/pr.mjs`.
Use that path, not the copy in the current worktree.

## Step 0: Resolve the PR and the mode

- **Comment links only**: follow `references/triage.md` for those comments and end.
  Do not run the other steps.
- **PR number or URL**: use it.
- **No argument**: use the current branch's PR:
  `gh pr view --repo elastic/kibana --json number -q .number`. If the branch has no
  open PR, stop and report it.

Confirm the local branch is the PR's head branch. Run `git pull --rebase origin
<branch>` first, because kibanamachine pushes fix-up commits to PR branches.

Run `pr.mjs signals <PR_NUMBER>` for Libra, CI, and `mergeable`. On a draft PR,
ignore `ci=off`: drafts get CI through `/ci`.

## Step 1: Comments

Follow `references/triage.md` for every unresolved human comment and Libra thread.
Present the verdicts, draft replies, and proposed `REVIEW.md` rules, then **stop**
and wait for the user's decision before changing code or replying.

After approval:

- Fix the rule, not the line: find every instance of the same mistake in the diff.
- For a new guard test, break the code once to prove the test fails, then restore
  it.
- Post the approved replies before you push, so reviewers see the reason with the
  commit.
- Resolve threads only when the user approved it, with `pr.mjs resolve <thread-id>`.

## Step 2: Mergeability

Check whether the branch merges cleanly into `upstream/main`:

```bash
git fetch upstream main
git merge-tree "$(git merge-base HEAD upstream/main)" HEAD upstream/main
```

- Conflicts: merge `upstream/main` and resolve every conflict in favor of the
  correct final code, not blind `--ours`. Regenerate generated files instead of
  merging them by hand. If a conflict needs a semantic decision, abort the merge and
  ask the user. Rerun the affected checks from the "Run checks" section in
  `~/.agents/skills/ship-review/SKILL.md`, then push.
- Outdated but mergeable: leave it. Do not merge only to refresh the branch.
- If the `git merge-tree` output is unclear, verify with a local test merge and
  abort it.

## Step 3: CI

Take one snapshot with `pr.mjs wait <PR_NUMBER> --for ci --timeout 0`. For each
failure, follow `references/ci.md`.

## Step 4: Push and wait

Push only to the fork: `git push origin HEAD`. On a draft PR, comment `/ci`:

```bash
gh pr comment <PR_NUMBER> --body '/ci'
```

Then run `pr.mjs wait <PR_NUMBER> --for libra,ci`. When it prints `pending`, run it
again. When new Libra findings or CI failures arrive, go back to Step 1 or Step 3.

Stop after three rounds, or earlier when:

- the same rule or comment is flagged again after a fix,
- the same test fails again after a fix,
- a local check fails and the fix is not clear, or
- a conflict needs a decision.

## Report

End with the PR state:

- Comments: fixed, pushed back, and waiting for the user.
- Mergeability: clean, merged, or blocked.
- CI and Libra: the last result of each, with the commit SHA.
- Items that need a human decision.
