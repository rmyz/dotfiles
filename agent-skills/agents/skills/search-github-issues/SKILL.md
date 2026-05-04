---
name: search-github-issues
description: Search for GitHub issues in a repository using gh CLI. Use when asked to find issues by team labels, keywords, or other criteria.
---

# Search GitHub Issues

Search for GitHub issues in a repository using the `gh` CLI with labels and keywords.

## When to Use

- Looking for issues with specific labels (like team labels)
- Searching by keywords in title/body
- Finding issues related to a specific topic or feature
- Locating issues for a particular team

## Instructions

### 1. Find the correct label format first

Labels may have different formats (e.g., `Team:My Team` vs `team:myteam`). Always search for labels first to get the exact name:

```bash
gh label list --repo <owner>/<repo> --search "<keyword>" --limit 20
```

### 2. List issues with the label

Once you have the exact label name:

```bash
gh issue list --repo <owner>/<repo> --label "<exact-label-name>" --limit 50
```

### 3. Search within labeled issues

Combine label filtering with keyword search for more targeted results:

```bash
gh issue list --repo <owner>/<repo> --label "<label>" --search "<keywords>" --limit 30
```

### 4. Get issue details

Once you find the relevant issue number:

```bash
gh issue view <issue-number> --repo <owner>/<repo>
```

## Tips

- Label names are case-sensitive - always use `gh label list` to find exact names
- The `--search` flag searches in title and body
- Combine multiple search terms in the search string
- Use `--state open` or `--state closed` to filter by state
- If label search returns empty, try searching issues directly with keywords
