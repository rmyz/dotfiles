# Comment triage

Analyze review comments on a GitHub PR and recommend whether to **accept** or
**push back** on each one, with reasoning grounded in the actual diff.

## Inputs

The input is one or more GitHub PR comment links (e.g. `https://github.com/org/repo/pull/123#discussion_r456`), or a PR.
Extract `OWNER/REPO`, `PR_NUMBER`, and any comment/discussion IDs.

## Workflow

### Step 1 — Fetch PR metadata and diff

```bash
gh pr view "$PR_NUMBER" --repo "$OWNER/$REPO" \
  --json title,body,baseRefName,headRefName,files,additions,deletions
gh pr diff "$PR_NUMBER" --repo "$OWNER/$REPO"
```

### Step 2 — Fetch the review comments

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" --paginate
```

Filter to the comments the user linked. If the user gave only a PR URL with no
specific links, analyze every unresolved review comment.

For an `elastic/kibana` PR, also read the threads of Libra, Kibana's AI reviewer,
with `node ~/Code/kibana/.agents/skills/pr-babysit/scripts/pr.mjs threads <PR_NUMBER>`.
Read the body of Libra's latest review too, because some findings appear only
there. When a thread has `followUp: true`, triage only its latest reply, and reply
at most once more.

For each comment, extract:

- `body` — the reviewer's text
- `path` and `line` / `original_line` — file location
- `diff_hunk` — surrounding diff context
- `user.login` — who wrote it
- `in_reply_to_id` — thread context; fetch the parent if present

### Step 3 — Gather deeper context (if needed)

If the diff hunk alone is not enough to judge a comment, read the file around it
and check `git log` / `git blame` for why the code is written that way. Escalate
only when a comment spans multiple files or touches architecture: read and follow
`~/.agents/skills/cross-review/SKILL.md` in **PR mode** on the same PR. Do not
escalate for single-line style nits or localized logic questions.

### Step 4 — Analyze each comment

For every comment, decide whether the reviewer is correct or misread the code or
context, how severe the point is (blocking, nice-to-have, or stylistic), and whether
the effort is worth the gain. When the suggestion is not ideal, look for a middle
ground.

### Step 5 — Present verdicts

One block per comment:

```
### 💬 Comment by @reviewer — file/path.ts (line 42)

> [quoted reviewer comment, truncated if long]

**Verdict: ✅ Accept** | **Verdict: 🔙 Push back** | **Verdict: 🤝 Compromise**

[short reasoning that references the actual code]

**Suggested reply:**
> [draft reply]
```

### Verdict guidelines

| Verdict | When to use |
|---------|-------------|
| ✅ Accept | The comment is correct, improves the code, and the fix is reasonable |
| 🔙 Push back | The comment is incorrect, misreads the code, or the cost outweighs the benefit |
| 🤝 Compromise | The reviewer has a point but the suggested fix is not ideal — propose an alternative |

Lean toward **accepting** when the reviewer caught a genuine bug or edge case,
the suggestion measurably improves readability, or the fix is low-effort.

Lean toward **pushing back** when the comment misreads intent or context, the
suggestion adds unnecessary complexity, it is a pure style preference with no
clear winner, or it asks for something outside the PR's scope.

### Tone for suggested replies

Write as a peer: direct, specific, and actionable. Thank the reviewer only when
it is warranted, never reflexively. When pushing back, lead with the technical
reason rather than an apology. Say plainly when something is a preference rather
than a defect.

### Step 6 — Encode the lesson

For each accepted or compromise comment, ask whether it applies beyond this PR.
When it does, read `~/.agents/REVIEW.md`:

- No rule covers it: propose one imperative sentence under the matching heading.
- A rule covers it: the rule did not hold. Propose a lint rule or a skill check
  instead of a second sentence.

Show the proposals after the verdicts. Edit `~/.agents/REVIEW.md` only after the
user approves them.

### End with a summary

```
**Summary**: X comments analyzed — Y accept, Z push back, W compromise, R rules proposed
```

## Edge cases

- **Comment links from multiple PRs:** process each PR separately.
- **Deleted or outdated comments:** note them as stale and skip.
- **Comment threads:** read the full thread before rendering a verdict.
- **No comment links, just a PR URL:** analyze every unresolved review comment.
