---
name: review-pr-comments
description: Triage PR review comments — decide whether to accept or push back on each one. Given comment links from a GitHub PR, fetches comment content and PR diff, then reasons about each comment in context and drafts a reply. Use when the user shares PR comment links, asks "should I accept this feedback", or wants help responding to PR review comments.
---

# Review PR Comments

Analyze review comments on a GitHub PR and recommend whether to **accept** or
**push back** on each one, with reasoning grounded in the actual diff.

## Inputs

The user provides:

1. One or more GitHub PR comment links (e.g. `https://github.com/org/repo/pull/123#discussion_r456`)
2. Optionally, the PR URL itself

Extract `OWNER/REPO`, `PR_NUMBER`, and any comment/discussion IDs from the links.

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

For each comment, extract:

- `body` — the reviewer's text
- `path` and `line` / `original_line` — file location
- `diff_hunk` — surrounding diff context
- `user.login` — who wrote it
- `in_reply_to_id` — thread context; fetch the parent if present

### Step 3 — Gather deeper context (if needed)

If the diff hunk alone is not enough to judge a comment:

1. Read the full file around the comment (±30 lines).
2. Check `git log` / `git blame` for why the code is written that way.
3. **Last resort only:** if the comment spans multiple files or touches
   architecture, read and follow `~/.agents/skills/review-team/SKILL.md` in
   **PR review mode** on the same PR. Do not escalate for single-line style nits
   or localized logic questions.

### Step 4 — Analyze each comment

For every comment, reason through:

1. **Is the reviewer correct?** Does it identify a real issue, or is it based on
   a misreading of the code or context?
2. **Severity** — blocking, nice-to-have, or purely stylistic?
3. **Cost vs benefit** — effort to address vs improvement gained. Mechanical fix,
   or does it require rethinking the approach?
4. **Alternatives** — if the suggestion is not ideal, is there a better middle
   ground?

### Step 5 — Present verdicts

One block per comment:

```
### 💬 Comment by @reviewer — file/path.ts (line 42)

> [quoted reviewer comment, truncated if long]

**Verdict: ✅ Accept** | **Verdict: 🔙 Push back** | **Verdict: 🤝 Compromise**

[2-4 sentences of reasoning, referencing the actual code]

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

### End with a summary

```
**Summary**: X comments analyzed — Y accept, Z push back, W compromise
```

## Edge cases

- **Comment links from multiple PRs:** process each PR separately.
- **Deleted or outdated comments:** note them as stale and skip.
- **Comment threads:** read the full thread before rendering a verdict.
- **No comment links, just a PR URL:** analyze every unresolved review comment.
