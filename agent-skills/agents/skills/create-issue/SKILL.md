---
name: create-issue
description: Create GitHub issues with proper formatting and labels. Uses team config from workspace rules for repo and labels. Use when the user asks to create an issue, file a bug, open a ticket, or document findings as an issue.
---

# Create GitHub Issue

Creates well-formatted GitHub issues following the team's conventions. Team-specific values (repo, labels) are read from workspace rules.

## Instructions

### Step 1: Gather Context

Collect the information needed for the issue. Context can come from:
- Current conversation (investigation findings, debugging sessions, feature requests)
- Slack threads (use `conversations_replies` to fetch full thread)
- Code exploration results
- APM traces or performance analysis

If context is insufficient, ask the user for:
- What type of issue (bug, enhancement, investigation finding, feature request)
- Summary of the problem or request
- Any relevant links (PRs, Slack threads, APM traces)

### Step 2: Check for Repo Issue Templates

Before formatting the issue, check if the issue repo has issue templates:

```bash
ls <ISSUE_REPO_PATH>/.github/ISSUE_TEMPLATE/ 2>/dev/null
```

Or fetch them via the API:

```bash
gh api repos/<ISSUE_REPO>/contents/.github/ISSUE_TEMPLATE --jq '.[].name' 2>/dev/null
```

**If templates exist**, read them and follow their structure (fields,
sections, checklists) instead of the generic templates below. YAML
templates (`.yml`) define structured fields — map each field to a
markdown section in the issue body. Check all checklist items that
you can satisfy (e.g., labels added, project fields set, parent
epic linked).

**If no templates exist** (or they are not relevant to the issue
type), fall back to the generic templates in Step 4.

### Step 3: Determine Issue Type and Labels

Read the **team label** from workspace rules (team config). Always include it. Add additional labels based on type:

| Type | Additional Labels | Title Prefix |
|------|------------------|--------------|
| Bug | `bug` | `[Bug]` |
| Enhancement | `enhancement` | (none) |
| Investigation/Perf | (none) | Descriptive |
| Feature request | (none) | (none) |

### Step 4: Format the Issue

If following a repo-specific template (Step 2), use that structure.
Otherwise, follow this structure based on issue type:

#### Bug Template

```markdown
## Summary
One paragraph describing the bug.

## Expected Behavior
What should happen.

## Actual Behavior
What actually happens. Include screenshots/traces if available.

## Steps to Reproduce
1. Step one
2. Step two
3. Observe...

## Additional Context
- Links to Slack threads, PRs, or related issues
- APM trace screenshots or analysis
- Root cause analysis if known
```

#### Enhancement / Feature Template

```markdown
## Description
What needs to be done and why.

## Context
Background information, links to discussions, Slack threads.

## Current Behavior (if applicable)
How things work today.

## Proposed Solution
Recommended approach with technical details.

## Impact
Who benefits and how.
```

#### Investigation / Performance Template

```markdown
## Summary
What was investigated and key findings.

## Context
Link to original discussion (Slack thread, etc.)

## Investigation Details
### Analysis
- What was measured/profiled
- Tools used (APM traces, etc.)

### Root Cause
Technical explanation of the finding.

### Fix Applied / Proposed
What was done or what should be done.
- Code changes with file paths
- Test results (before/after)

## References
- Slack thread: [link]
- PR: [link]
- APM trace: [screenshot/link]
```

### Step 5: Create the Issue

Read **ISSUE_REPO** and **TEAM_LABEL** from workspace rules (team config). If team config is missing, ask the user: "Which repo should I create the issue in?" and "What team label should I add?"

**Important**: If the issue body contains single quotes or special
characters, write it to a temp file and use `--body-file` instead
of `--body` with a heredoc to avoid shell escaping issues:

```bash
gh issue create --repo <ISSUE_REPO> \
  --title "Issue title" \
  --label "<TEAM_LABEL>" \
  --label "additional-label" \
  --body-file /tmp/issue-body.md
```

**Note**: `gh issue create` does not support a `--type` flag. Issue
type (bug, epic, story, etc.) is determined by the repo's issue
type configuration, not a CLI flag.

### Step 6: Add to GitHub Project (if configured)

Check if the team config has a **GitHub Projects** section. If it does not, skip this step entirely.

If the team config specifies a GitHub Project, add the newly created issue and set the required fields:

1. **Add the issue to the project** and capture the item ID:
   ```bash
   ITEM_ID=$(gh project item-add <PROJECT_NUMBER> --owner <PROJECT_OWNER> --url <ISSUE_URL> --format json | jq -r '.id')
   ```

2. **Get the project's node ID and field metadata**:
   ```bash
   PROJECT_ID=$(gh project view <PROJECT_NUMBER> --owner <PROJECT_OWNER> --format json | jq -r '.id')
   FIELDS=$(gh project field-list <PROJECT_NUMBER> --owner <PROJECT_OWNER> --format json --limit 100)
   ```

3. **Set each field** listed in the team config. For each field name → value pair, look up the IDs by name and set the value:
   ```bash
   FIELD_ID=$(echo "$FIELDS" | jq -r '.fields[] | select(.name == "<FIELD_NAME>") | .id')
   OPTION_ID=$(echo "$FIELDS" | jq -r '.fields[] | select(.name == "<FIELD_NAME>") | .options[] | select(.name == "<VALUE>") | .id')
   gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" --field-id "$FIELD_ID" --single-select-option-id "$OPTION_ID"
   ```

4. Report which project fields were set successfully. If any field or option name is not found, warn the user rather than failing silently.

### Step 7: Add as Sub-Issue (if applicable)

If the user specifies a parent epic, or if the repo's issue template
includes a checklist item about adding to an epic, link the issue
as a sub-issue using the GraphQL API:

1. **Get node IDs** for both the parent and child issues:
   ```bash
   gh api graphql -f query='
   {
     repository(owner: "<OWNER>", name: "<REPO>") {
       parent: issue(number: <PARENT_NUMBER>) { id }
       child: issue(number: <CHILD_NUMBER>) { id }
     }
   }'
   ```

2. **Add the sub-issue relationship**:
   ```bash
   gh api graphql -f query='
   mutation {
     addSubIssue(input: {
       issueId: "<PARENT_NODE_ID>",
       subIssueId: "<CHILD_NODE_ID>"
     }) {
       issue { number }
       subIssue { number }
     }
   }'
   ```

3. If the issue template has a checklist item about adding to an
   epic, update the issue body to check that box.

### Step 8: Report Back

After creation, share the issue URL with the user. If the issue was added to a GitHub Project or linked as a sub-issue, include that information as well.

## Key Conventions

- **Title format**: Use `[Bug]` prefix for bugs, descriptive prefix for investigations
- **Slack references**: Always include the full Slack thread link when the issue originates from Slack
- **Code references**: Include file paths and line numbers for code-related issues
- **Assignee**: Assign to the user if they authored the investigation. Use `--assignee` flag.
- **Keep it concise**: Issues should be scannable, not essays
- **Repo and labels**: Always read from workspace rules (team config), never hardcode
