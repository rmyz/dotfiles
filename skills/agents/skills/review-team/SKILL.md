---
name: review-team
description: >-
  Launch a team of 6 specialized code reviewers in parallel to catch issues
  from multiple perspectives. Use when the user says "review team",
  "comprehensive review", "multi-perspective review", or wants a thorough
  multi-angle review of branch changes or a plan.
---

# Review Team

Launch 6 specialized reviewers in parallel, each with a distinct perspective,
then consolidate findings into a single prioritized report.

## Reviewers

| #   | Name                 | Persona source                                                   |
| --- | -------------------- | ---------------------------------------------------------------- |
| 1   | Code Quality         | `~/.agents/skills/branch-refactor-planner/SKILL.md`              |
| 2   | Adversarial          | `~/.agents/skills/review-team/reviewers/adversarial.md`          |
| 3   | Architecture         | `~/.agents/skills/review-team/reviewers/architecture.md`         |
| 4   | Fresh Eyes           | `~/.agents/skills/review-team/reviewers/fresh-eyes.md`           |
| 5   | Product Flow         | `~/.agents/skills/review-team/reviewers/product-flow.md`         |
| 6   | Observability Expert | `~/.agents/skills/review-team/reviewers/observability-expert.md` |

## Mode detection

- **Branch review** (default): user says "review team", "review my changes", "comprehensive review"
- **PR review**: user supplies a GitHub PR URL, or says "review pr"
- **Plan review**: user says "review team plan", "review this plan", or attaches a plan document

PR review runs the same six reviewers as branch review; it only differs in how the
diff is acquired (Step 0) and how findings are presented (Step 5).

## Scope -- changed code only

**Review only what this branch or PR changed.** Read whole files freely for
context, but every finding must sit on a line the diff touched.

Pre-existing problems in unedited code are out of scope, however tempting. The one
exception: a latent bug that the change actively makes reachable or worse -- report
that, and say explicitly that the line is pre-existing.

This rule is repeated inside each reviewer's prompt because subagents inherit none
of this context. Do not drop it when constructing prompts.

## Workflow

### Step 0 -- Acquire the PR (PR review mode only)

Skip this step for branch and plan review.

**Use `gh` only. Run no `git` commands at all** -- no fetch, no checkout, no
worktree, no branch switch. The user may have unrelated work in progress, and local
git state is not a trustworthy source for a remote PR: `FETCH_HEAD` can hold a
leftover value from an earlier fetch and silently yield a diff for a different PR.
`gh` asks GitHub, which is authoritative.

Extract `OWNER/REPO` and `PR_NUMBER` from the URL, then read the metadata:

```bash
gh pr view "$PR_NUMBER" --repo "$OWNER/$REPO" \
  --json title,body,baseRefName,headRefOid,files,additions,deletions,author
```

Capture `headRefOid` as `$HEAD_SHA` -- Step 1 needs it to read files at the PR's
version. More than 50 changed files (`.files | length`): warn the user and ask
whether to proceed or narrow scope.

Auth failure: tell the user to run `gh auth login`. Already-merged PRs are still
reviewable -- the user may want post-merge feedback.

### Step 1 -- Gather context

**Branch review mode** -- local git, comparing your branch against upstream:

```bash
git fetch upstream main
BASE=$(git merge-base HEAD upstream/main)
git diff --name-only "$BASE" HEAD      # file list
git diff "$BASE" HEAD                  # full diff
```

Never use `origin/main`; `origin` is the fork and its `main` is not kept in sync.
Read every changed file in full from disk -- not just diff hunks.

**PR review mode** -- `gh` only, no git:

```bash
# File list with status: added | modified | removed | renamed
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/files" --paginate \
  --jq '.[] | "\(.status)\t+\(.additions) -\(.deletions)\t\(.filename)"'

gh pr diff "$PR_NUMBER" --repo "$OWNER/$REPO"
```

`gh pr diff` is already computed against the PR's merge base, so there is no base to
resolve and nothing to assume about backport branches. **This diff is the definition
of "changed code"** for the scope rule.

`--paginate` matters: the API returns 30 files per page, so a large PR silently
truncates without it.

To read a changed file in full, at the PR's version:

```bash
gh api "repos/$OWNER/$REPO/contents/<path>?ref=$HEAD_SHA" \
  -H "Accept: application/vnd.github.raw"
```

Two rules for reading:

- **Skip files with status `removed`** -- they do not exist at `$HEAD_SHA` and the
  request returns HTTP 404. The diff already shows what was deleted; that is enough
  to review a deletion.
- **Never read from disk.** Disk holds whatever the user's current branch has, which
  is a different version of the file.

**Plan review mode:**

1. Read the plan document (attached file or user-provided path)
2. Identify files and areas the plan references
3. Read those files for context

Store the gathered context as `REVIEW_CONTEXT` (you will inject it into every
Task prompt below).

In PR review mode, `REVIEW_CONTEXT` must spell out `OWNER/REPO`, the resolved
`$HEAD_SHA`, and the exact `gh api ... -H "Accept: application/vnd.github.raw"`
command for reading a file. Subagents inherit no variables, and if they fall back to
reading from disk they will silently review the user's current branch instead of the
PR -- with no error to signal it.

### Step 2 -- Read all persona files

Read **all 6 persona files listed in the table above** in a single parallel
batch. Store each file's content -- you will embed it verbatim in the matching
Task prompt.

### Step 3 -- Launch 6 reviewers in parallel

Send a **single message containing 6 `Task` tool calls**, one per reviewer.

For every reviewer, construct the Task prompt by combining:

1. The persona instructions (from the file read in Step 2)
2. `REVIEW_CONTEXT` gathered in Step 1
3. The output format template (copy the block below verbatim)

Task parameters (same for all 6):

```
subagent_type: "general"
```

Do **not** set the `model` parameter -- let every reviewer inherit the
current session's model. Do **not** pass `readonly`; it is not a valid
parameter. Reviewers are read-only by instruction: end every prompt with
"Report findings only. Do not edit, create, or delete any file."

#### Output format to include in every Task prompt

Paste this block at the end of every reviewer's Task prompt:

```
SCOPE -- CHANGED CODE ONLY
==========================
Review ONLY the lines this diff changed. Read whole files for context, but every
finding you report MUST sit on a line the diff touched. Do NOT report pre-existing
problems in unedited code -- not style, not structure, not missing tests for code
that already existed. If you catch yourself citing a line that is not in the diff,
drop the finding.

Sole exception: a latent bug the change actively makes reachable or worse. Report
it, and state explicitly that the line is pre-existing.

REQUIRED OUTPUT FORMAT
======================
Return your findings in EXACTLY this structure. Every finding must cite a
file path and line number or range, and that line must appear in the diff.
Keep each finding to 1-2 sentences.

## [Your Reviewer Name] Findings

### Critical (must address)
- `file/path.ts:42` -- What is wrong and what to do instead.

### Important (should address)
- `file/path.ts:15-20` -- What is wrong and what to do instead.

### Minor (consider)
- `file/path.ts:99` -- What is wrong and what to do instead.

If a severity section has no findings, write "None."
Do NOT include findings outside your designated focus area.
```

### Step 4 -- Consolidate

After all 6 reviewers return:

1. Group findings by file path, then by line number / range.
2. When two or more reviewers flag the same location, merge into one item
   and tag it with every reviewer name that raised it.
3. Use the highest severity among the merged reviewers
   (Critical > Important > Minor).
4. Keep any domain-specific observations that don't overlap (e.g. from the
   Observability Expert) in a dedicated "Reviewer-Specific Notes" section.

Present the final report as:

```markdown
# Review Team Report

## Critical

- `file:line` [Reviewer1, Reviewer2] -- merged finding

## Important

- `file:line` [Reviewer1] -- finding

## Minor

- `file:line` [Reviewer1] -- finding

## Reviewer-Specific Notes

### Observability Expert

- domain-specific observations

### Architecture

- system-level observations
```

### Step 5 -- Generate plan

For all findings marked as **Critical** or **Important** in the consolidated report, generate a prioritized action plan. The plan should:

1. List each action item as a checklist bullet `- [ ]` with a brief, actionable description.
2. Reference the file and line(s) to fix, and summarize the core issue.
3. For merged findings, indicate all relevant reviewers.
4. Order first by severity (**Critical** before **Important**), then by file path, then by line number.
5. If there are no **Critical** or **Important** findings, state:
   `No blocking findings. Minor feedback may be addressed at your discretion.`

Example:

```markdown
## Action Plan

- [ ] `file/path.ts:42` (**Critical**, flagged by Reviewer1, Reviewer2): Replace unsafe method with secure alternative to prevent possible crash.
- [ ] `other/file.js:10-12` (**Important**, flagged by Reviewer3): Refactor duplicated code into a shared helper function.
```

If there are relevant reviewer-supplied remediation suggestions or links, include them, but avoid speculative advice outside reviewer focus.

### Step 6 -- Conventional comments (PR review mode only)

For branch and plan review, stop after Step 5. In PR review mode, also convert each
finding into a comment ready to paste onto the PR.

| Report severity | Conventional label        |
|-----------------|---------------------------|
| Critical        | `issue (blocking):`       |
| Important       | `suggestion:`             |
| Minor           | `nitpick (non-blocking):` |
| Praise          | `praise:`                 |

Use another label when it fits better: `question:` when the finding is uncertain,
`thought (non-blocking):` for ideas, `todo:` for mechanical fixes,
`polish (non-blocking):` for quality-of-life improvements.

Write as a peer: direct, specific, actionable. No lecturing, no corporate filler.
Say plainly when something is a preference rather than a defect. Where there is a
clear improvement, include a short plain snippet (1-10 lines) -- illustrative, not
a GitHub suggestion block, since the same pattern may apply elsewhere.

Group by file, ordered by line. Header line outside the block, and a fenced block
containing only what the user copies:

````
📄 **file/path.ts** (line 42) -- [Code Quality, Adversarial]

```markdown
suggestion: this nested ternary is doing too much in one expression.

Splitting it makes the intent obvious:

const status = isActive
  ? StatusType.Active
  : StatusType.Inactive;
```
````

End with:

```
**Summary**: X comments (Y blocking, Z suggestions, W nitpicks, V praise)
```

When the report has no Critical or Important findings and at most 2 Minor ones:

```
This PR looks solid across all review perspectives (code quality, correctness,
architecture, readability, product flow, observability). Nothing blocking.
```

---

If ALL sections are empty, report: "No findings -- all reviewers passed."
