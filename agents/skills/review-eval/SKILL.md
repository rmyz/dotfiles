---
name: review-eval
description: Score the AI reviewers (cross-review or Claude /code-review) against human comments on past elastic/kibana PRs. Run after changing REVIEW.md, a review rubric, a reviewer model, or AGENTS.md. Invoke explicitly.
disable-model-invocation: true
---

# Review eval

Replays past PRs at the commit a human first reviewed. Each AI reviewer reviews that
commit, and a judge counts how many human comments the review caught.

## Data

`~/Code/ai-generated/files/review-eval/`:

- `cases.json`: one case per PR, with `base_sha`, `reviewed_sha`, `split`, and the
  `expected` human comments. Comments on UX, copy, and PR scope are left out.
- `runs/<timestamp>-<reviewer>-<split>/`: the report, judge output, and score for
  each case.
- `scores.tsv`: one row per run.
- `harvested.txt`: the PRs the loop has already considered.

Never read `holdout` comments to write or change a rule. Score changes on `dev` and
confirm them on `holdout`. The first four holdout cases fed the first `REVIEW.md`,
so their scores read high. PRs added after 2026-10-30 are the clean holdout.

## Run

Run it in an Orca terminal. One case takes several minutes.

```bash
~/.agents/skills/review-eval/scripts/run.sh <cross|code> [dev|holdout|all] [pr-number]
```

- `cross`: the four-model panel through `opencode run`.
- `code`: Claude's `/code-review high`, which follows `AGENTS.md`, and
  `AGENTS.md` tells it to read `REVIEW.md`.

The script checks out each case in a temporary detached worktree of
`~/Code/kibana`, so the commits must be fetchable from `upstream`.

## Read the score

- `recall_pct`: the share of human comments the review caught. This is the main
  score.
- `unmatched`: findings with no human comment. Some are real bugs the humans missed,
  so read them before you count them as noise.
- `config`: the dotfiles commit, with `-dirty` when review files have uncommitted
  changes.

Keep a review change only when `recall_pct` rises on `dev` and does not fall on
`holdout`. Compare two runs only when they cover the same split.

## Feedback loop

An Orca automation named `review-eval` runs this section every Monday. `teardown`
also starts it after a merge. Its precheck, `scripts/pending.sh`, skips the run
unless a merged PR is missing from `harvested.txt` or the committed review config
changed since the last full run. The loop runs without approval stops and never
edits `REVIEW.md` or a skill.

1. **Harvest.** Run `scripts/pending.sh` and take the PR numbers it prints. For each
   PR, find the first review with substantive human comments. Take its `commit_id`.
   Select the comments made on that commit. Leave out bots, LGTMs, and comments on
   UX, copy, or PR scope. With two or more comments left, run:

   ```bash
   python3 -I ~/.agents/skills/review-eval/scripts/add-case.py <pr> <commit_id> "<comment-id>=<short theme>" ...
   ```

   The script adds the case and the PR to `harvested.txt`. It puts PRs whose number
   is divisible by 3 in `holdout`. With fewer than two comments, append the PR number to
   `harvested.txt` only.
2. **Score the new cases.** Run `scripts/run.sh code all <pr>` for each new case.
3. **Rescore after config changes.** When `pending.sh` reported a config change,
   run `scripts/run.sh code all` and then `scripts/run.sh cross all`.
4. **Propose fixes.** Read each new `dev` case's `score.json`. For each human comment
   the review missed, check `REVIEW.md`. Propose a new rule when no rule covers it.
   When a rule covers it and the reviewer still missed it, propose a lint rule or a
   skill check instead. Do not read `holdout` comments for this step.
5. **Report.** Write `~/Code/ai-generated/files/review-eval/reports/<date>.md`. List
   the new cases, the new `scores.tsv` rows compared with the previous rows for the
   same reviewer and split, and the proposals. Set the Orca card comment to one line
   with the recall change and the number of proposals.
