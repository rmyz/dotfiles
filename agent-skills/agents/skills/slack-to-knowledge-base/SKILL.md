---
name: slack-to-knowledge-base
description: Extracts knowledge from Slack channels or threads with deep context gathering. Follows GitHub links, referenced threads, and learns about participants. Use when asked to dump a Slack channel, create docs from Slack, or build a knowledge base from conversations.
---

# Slack to Knowledge Base

Extracts conversations from Slack and synthesizes them into structured knowledge base files. **Be curious and recursive** - follow every lead to build complete context.

## Critical: Slack Search Strategy

**ALWAYS search globally first. NEVER assume or filter by channel.**

```
# CORRECT - searches ALL channels, DMs, threads across entire workspace
conversations_search_messages(search_query="topic")
conversations_search_messages(search_query="person.name")

# WRONG - limits results by assuming specific channels  
conversations_search_messages(filter_in_channel="#some-channel", ...)
conversations_search_messages(filter_users_from="@user", ...)
```

The `search_query` parameter searches the **entire Slack workspace**. You don't know what channels exist or where relevant discussions happened. Channel filters should only be used AFTER global search finds relevant channels.

## Mindset: Be a Detective

Don't just read the surface. For every conversation:
- **Follow GitHub links** - read PRs, issues, code references
- **Chase Slack references** - fetch linked threads, mentioned channels
- **Learn about people** - understand who's expert in what, who to ask
- **Read linked docs** - Google Docs, Confluence, external references

## Workflow

```
1. Fetch initial content
2. WHILE new references found:
   - Extract all links (GitHub, Slack, docs)
   - Fetch and read each reference
   - Note key people and their expertise
   - Add new context to working knowledge
3. Synthesize into appropriate format
4. Include all sources for future updates
```

## Step 1: Fetch & Scan for References

Fetch the channel/thread, then extract:

| Reference Type | Pattern | Action |
|----------------|---------|--------|
| GitHub PR | `github.com/.../pull/123` | `gh pr view 123 --repo owner/repo` |
| GitHub Issue | `github.com/.../issues/456` | `gh issue view 456 --repo owner/repo --comments` |
| GitHub code | `github.com/.../blob/...` | Read the referenced code |
| Slack thread | `slack.com/archives/.../p...` | Fetch with `conversations_replies` |
| Slack channel mention | `#channel-name` | Note for potential follow-up |
| Google Doc | `docs.google.com/...` | Note URL (can't fetch, but record it) |
| Person mention | `@username` or `U08XXXXX` | Track their expertise based on context |

### GitHub Repos to Check

Read **PR_TARGET_REPO** and **ISSUE_REPO** from workspace rules (team config):

| Repo | Contains |
|------|----------|
| `<PR_TARGET_REPO>` | Code, public PRs |
| `<ISSUE_REPO>` | Private issues, roadmap, epics, bugs |
| `elastic/elasticsearch` | ES core |

### Team Labels to Note

Read **TEAM_LABEL** from workspace rules (team config). When you see issues, check their labels for team context:
- `<TEAM_LABEL>` → Your team
- `epic` → Roadmap epic
- `bug` → Bug report

## Step 2: Recursive Context Gathering

For each GitHub link found, use `gh` CLI (authenticated, works with private repos):

```bash
# Read PR details
gh pr view 12345 --repo <PR_TARGET_REPO>

# Read issue with comments
gh issue view 12345 --repo <ISSUE_REPO> --comments

# Get PR diff summary
gh pr diff 12345 --repo <PR_TARGET_REPO>

# Check issue labels (team, epic, bug, etc.)
gh issue view 12345 --repo <ISSUE_REPO> --json labels
```

Extract from each:
- **PR**: title, description, key comments, files changed, labels
- **Issue**: description, labels (team, epic, bug), linked PRs, assignees
- **Code**: understand what the code does

For each Slack reference:
```
- Fetch the thread with conversations_replies
- Scan THAT thread for more references
- Repeat (but limit depth to 2-3 levels)
```

For people mentioned:
```
Build a mental model:
- What topics do they speak authoritatively on?
- What PRs/features are they associated with?
- Are they the "go-to" person for something?
```

## Step 3: Synthesize with Full Context

Now you have rich context. Create outputs that include:

### Decision Record
```markdown
# [Title]

## Status
[Accepted | Proposed | Deprecated]

## Context
[Full background - what prompted this, related issues]

## Decision
[What was decided and why]

## Implementation
[Link to PR if exists, code changes made]

## Key People
- @person1 - proposed the solution
- @person2 - raised concerns about X

## Sources
- Main thread: [slack link]
- Related PR: [github link]  
- Referenced issue: [github link]
- Date: YYYY-MM-DD
```

### Troubleshooting Guide
```markdown
# [Problem]: [Title]

## Symptoms
[What you'll observe]

## Root Cause
[Deep explanation from the discussion + code context]

## Solution
[Step by step, with code examples if found in PRs]

## Technical Details
[From GitHub PRs/code that was referenced]

## Who to Ask
- @person - expert on this topic

## Sources
- Discovery thread: [slack link]
- Fix PR: [github link]
- Related docs: [links]
```

## Step 4: Source Everything

Every fact should trace back to a source:

```markdown
## Sources & References

### Slack Threads
| Thread | Date | Key Topic |
|--------|------|-----------|
| [link] | YYYY-MM-DD | Original discussion |
| [link] | YYYY-MM-DD | Follow-up decision |

### GitHub
| Link | Type | Relevance |
|------|------|-----------|
| PR #123 | Implementation | Contains the fix |
| Issue #456 | Context | Original bug report |

### People (for follow-up)
| Person | Expertise |
|--------|-----------|
| @alice | System architecture |
| @bob | This specific feature |

### External Docs (not fetched)
- [Google Doc title](url) - mentioned but not accessible
```

## Depth Limits

To avoid infinite recursion:
- Slack threads: Follow up to 3 levels deep
- GitHub: Read linked PRs/issues, but don't spider the whole repo
- Stop when references become tangential to main topic

## Example: Full Extraction

**User**: "Create knowledge base from this thread about workflow IDs"

**Agent does**:
1. Fetch thread → finds GitHub issue #15450 mentioned
2. Read issue #15450 → understands full proposal, sees related Kubernetes naming link
3. Back in thread → sees reference to "connectors V2 discussion"
4. Fetch connectors V2 thread → learns it's a related problem
5. Notes @ihor proposed solution, @tal and @marco gave input
6. Synthesizes into decision record with:
   - Full context from issue
   - Design rationale from discussion
   - Implementation status from PR links
   - Who to contact for questions
   - All source links for future updates
