---
name: unblock-pr
description: Triage review comments on an elastic/kibana PR, or move the PR past review comments, merge conflicts, and failing CI. Use with PR comment links, a PR number or URL, or no argument for the current branch's PR. Also use when the user asks whether to accept review feedback.
---

# Unblock PR

Moves one open Kibana PR past whatever blocks it: review comments, merge conflicts,
or failing checks. The flow is:

`Comments -> Mergeability -> CI -> Wait`

Never resolve threads, retry CI jobs, or post `run docs-build` without explicit
approval. Post only replies the user approved. The one comment you post without
approval is `/ci`, under the `/ci` rule in `AGENTS.md`.

`pr.mjs` below means `node "$MAIN/.agents/skills/pr-babysit/scripts/pr.mjs"`, where
`MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` is the
primary checkout. Use that path, not the copy in the current worktree. Stop if
`test -f "$MAIN/.agents/skills/pr-babysit/scripts/pr.mjs"` fails. Its commands are
`signals`, `wait`, `threads`, and `resolve`; `$MAIN/.agents/skills/pr-babysit/SKILL.md`
describes their output.

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
ignore `ci=off`: drafts get CI through `/ci`. Steps 2 and 3 use this output.

## Step 1: Comments

Follow `references/triage.md` for every unresolved human comment and Libra thread.
Present the verdicts, draft replies, and proposed `REVIEW.md` rules, then **stop**
and wait for the user's decision before changing code or replying.

After approval:

- Fix the rule, not the line: search the diff with `rg` for the same pattern, list the
  hits, and fix each one.
- For a new guard test, break the code once to prove the test fails, then restore
  it.
- Post the approved replies before you push, so reviewers see the reason with the
  commit: `gh api -X POST "repos/elastic/kibana/pulls/<PR_NUMBER>/comments/<comment-id>/replies" -f body="<reply>"`.
- Resolve threads only when the user approved it, with `pr.mjs resolve <thread-id>`.

## Step 2: Mergeability

Read `mergeable` from the Step 0 signals.

- `CONFLICTING`: run `git fetch upstream main` and `git merge upstream/main`.
  Regenerate generated files instead of merging them by hand. When both sides
  changed the same logic, abort the merge and ask the user. Otherwise keep both
  changes. Rerun the affected targeted tests and
  `node scripts/check.js --scope=branch --base-ref upstream/main`, then push.
- `MERGEABLE`: leave the branch alone, even when it is outdated.
- `UNKNOWN`: run `pr.mjs signals <PR_NUMBER>` once more.

## Step 3: CI

Take one CI snapshot with `pr.mjs wait <PR_NUMBER> --for ci --timeout 0`. For each
failure, follow `references/ci.md`.

## Step 4: Push and wait

Push with `git push origin HEAD`. On a draft PR, comment `/ci`:

```bash
gh pr comment <PR_NUMBER> --body '/ci'
```

Then run `pr.mjs wait <PR_NUMBER> --for libra,ci`. When it prints `pending`, run it
again. When new Libra findings arrive, go back to Step 1 and triage them. Never fix
them directly, and never loop until Libra passes. When CI failures arrive, go back to
Step 3.

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
