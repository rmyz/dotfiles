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

| # | Name                  | Persona source                                            |
|---|-----------------------|-----------------------------------------------------------|
| 1 | Code Quality          | `~/.cursor/skills/branch-refactor-planner/SKILL.md`      |
| 2 | Adversarial           | `~/.cursor/skills/review-team/reviewers/adversarial.md`   |
| 3 | Architecture          | `~/.cursor/skills/review-team/reviewers/architecture.md`  |
| 4 | Fresh Eyes            | `~/.cursor/skills/review-team/reviewers/fresh-eyes.md`    |
| 5 | Product Flow          | `~/.cursor/skills/review-team/reviewers/product-flow.md`  |
| 6 | Observability Expert  | `~/.cursor/skills/review-team/reviewers/observability-expert.md` |

## Mode detection

- **Code review** (default): user says "review team", "review my changes", "comprehensive review"
- **Plan review**: user says "review team plan", "review this plan", or attaches a plan document

## Workflow

### Step 1 -- Gather context

**Code review mode:**

1. `git merge-base HEAD main` (fall back to `master` if needed)
2. `git diff --name-only <base>...HEAD` for the file list
3. `git diff <base>...HEAD` for the full diff
4. Read every changed file in full -- not just diff hunks

**Plan review mode:**

1. Read the plan document (attached file or user-provided path)
2. Identify files and areas the plan references
3. Read those files for context

Store the gathered context as `REVIEW_CONTEXT` (you will inject it into every
Task prompt below).

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
subagent_type: "generalPurpose"
readonly: true
```

Do **not** set the `model` parameter -- let every reviewer inherit the
current session's model.

#### Output format to include in every Task prompt

Paste this block at the end of every reviewer's Task prompt:

```
REQUIRED OUTPUT FORMAT
======================
Return your findings in EXACTLY this structure. Every finding must cite a
file path and line number or range. Keep each finding to 1-2 sentences.

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

---

If ALL sections are empty, report: "No findings -- all reviewers passed."
