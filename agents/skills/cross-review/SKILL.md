---
name: cross-review
description: Multi-model review of local changes or a GitHub PR. Four reviewers on different models apply the technical and product rubrics independently; findings are synthesized by consensus into act-on/consider/noted/dismissed buckets. Report-only. Works from any agent; the panel runs in OpenCode.
---

# Cross review

Multiple models review the same change independently. The adversarial signal comes
from model diversity, not personas: agreement across model families is
high-confidence signal, a lone-model finding is a noise candidate. This skill only
reports; it never applies changes.

## Outside OpenCode

The reviewer panel exists only in OpenCode. From any other agent, run the whole skill
in OpenCode and use its stdout as the report. Do not run the steps below yourself.
Replace the `<...>` values; the quoted heredoc keeps quotes and `$` in them safe:

```bash
cd "<worktree-or-repo>" && opencode run --agent build "$(cat <<'EOF'
Read ~/.agents/skills/cross-review/SKILL.md and follow it non-interactively.
Scope: <local, a ref, or a PR URL>. Intent: <one paragraph>. Plan: <plan file or none>.
Report only, do not edit files.
EOF
)"
```

The run takes several minutes; wait for it to exit. If `opencode` is missing or the
run fails, report it as a blocker instead of substituting another review.

When this skill runs non-interactively, it cannot ask the user. Where a step says to
ask, stop instead and print the question as a blocker.

## Step 1: Scope and intent

Two modes:

- **Local** (default): uncommitted changes plus branch commits against
  `upstream/main` (committed, staged, unstaged, untracked), or the ref the invocation
  names. Never use `origin/main`.
- **PR**: the invocation supplies a GitHub PR URL. Use `gh` only and run no `git`
  commands; local git state is not a trustworthy source for a remote PR. Read
  `gh pr view <n> --repo <owner/repo> --json title,body,headRefOid,files,additions,deletions`
  and capture `headRefOid` as `HEAD_SHA`. Warn and ask before reviewing more than 50
  files. The diff is `gh pr diff <n> --repo <owner/repo>`. Reviewers read a full file
  at the PR's version with `gh api "repos/<owner/repo>/contents/<path>?ref=<HEAD_SHA>" -H "Accept: application/vnd.github.raw"`,
  never from disk, and skip files with status `removed`.

State the intent in one paragraph before spawning anything: what the change is trying
to accomplish, derived from the plan file, the linked issue, the PR description,
commit messages, or the user's message. Reviewers judge whether the work achieves the
intent, not whether the intent is right. If the intent is unclear, ask before
proceeding.

## Step 2: Spawn the panel

Launch all four reviewers in one message via the subagent tool, one per pinned
subagent:

| Subagent        | Model                            |
| --------------- | -------------------------------- |
| `reviewer-opus` | `github-copilot/claude-opus-5.5` |
| `reviewer-kimi` | `github-copilot/kimi-k3`         |
| `reviewer-sol`  | `openai/gpt-6-sol`               |
| `reviewer-grok` | `github-copilot/grok-4.7`        |

Every reviewer gets the identical briefing:

- The intent paragraph and the plan file path when one exists.
- The mode, the exact diff scope, and the commands to obtain it (the `gh` commands in
  PR mode).
- The scope rule: every finding must sit on a line the diff touched. Pre-existing
  problems are out of scope, except a latent bug the change makes reachable or worse,
  which must be marked as pre-existing.
- Instructions to read and apply both rubrics:
  `~/.agents/skills/technical-review/SKILL.md` and
  `~/.agents/skills/product-review/SKILL.md`.
- Output format: one finding per line item with severity, `file:line`, rubric item,
  and a one-line suggested fix.

If a reviewer subagent is unavailable, continue with the remaining ones and say so in
the report; never substitute two reviewers from the same model family.

## Step 3: Synthesize

You are the lead reviewer, not a neutral aggregator. Merge findings that describe the
same issue and note which models raised each one. Then bucket every finding:

- **Act on** — real correctness, security, or maintainability issues given the actual
  goal. Would block a PR.
- **Consider** — legitimate, but the cost of addressing it now is not clearly worth
  it. The user decides.
- **Noted** — valid but low-impact or premature.
- **Dismissed** — wrong, nitpicky, or missing context, with a one-line reason.
  Always show this bucket so the user can override the filtering.

Weight by agreement: findings raised independently by two or more models rank above
lone-model findings of the same severity. A lone-model finding lands in Act on only
when you can verify it yourself in the code.

End with an agreement map: where the models agreed, where they diverged, and what the
pattern says about confidence.

In PR mode, also turn every Act-on and Consider finding into a comment ready to paste
onto the PR, following `~/.agents/skills/conventional-comments/SKILL.md`. Group them
by file and line. Never post anything to GitHub.

## Phase 2: auto-apply (not enabled)

Do not act on this section yet. It becomes active only when the user removes this
marker after grading the Act-on bucket across several PRs.

When enabled, findings may be applied without a per-finding user decision only when
all three hold:

1. Consensus: two or more model families raised it independently.
2. Safe class: a demonstrated correctness bug (write the failing test first, the fix
   turns it green), dead code introduced by the diff, or missed error handling inside
   changed code. Never UI copy, never architecture or refactors beyond the diff,
   never scope changes, never files outside the plan's file list.
3. Revalidation: affected tests and `node scripts/check.js --scope=local` rerun green
   after the fix.

Everything applied is listed afterwards with the models that agreed. All other
findings still go to the user.
