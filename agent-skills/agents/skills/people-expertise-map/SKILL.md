---
name: people-expertise-map
description: Builds and queries a knowledge graph of people and their expertise. Use when asked "who knows about X", "what does person Y work on", "who should I ask about Z", or when building team expertise profiles.
---

# People-Expertise Map

Builds a bidirectional knowledge graph: **Domain → People** and **People → Domains**.

## Critical: Slack Search Strategy

**Use the Slack MCP server tool `conversations_search_messages`** to search Slack.

### Rule 1: Search BOTH mentions AND authored content

To build a complete profile, you need TWO searches:

```
# 1. Find what OTHERS say about them (mentions, tags, discussions)
<use conversations_search_messages tool>
  search_query: "firstname.lastname"
  limit: 50

# 2. Find what THEY do (their own messages, PoCs, demos, ideas)
<use conversations_search_messages tool>
  search_query: "from:firstname.lastname"
  limit: 50
```

**Example for person "John Smith":**
```
# Search 1: What others say about John
conversations_search_messages(search_query="john.smith", limit=50)

# Search 2: What John authored himself
conversations_search_messages(search_query="from:john.smith", limit=50)
```

Only searching mentions misses all the person's own work - their PoCs, demos, ideas, and contributions.

### Rule 2: Use correct username format

```
# CORRECT formats
search_query="firstname.lastname"        # e.g., "shahar.glazner"
search_query="from:firstname.lastname"   # e.g., "from:shahar.glazner"

# For filter_users_from parameter (if needed):
filter_users_from="firstname.lastname"   # e.g., "shahar.glazner"
filter_users_from="U08TSNBB1PS"          # User ID

# WRONG - will fail with "user not found"
filter_users_from="@firstname"           # Partial name with @
filter_users_from="@shahar"              # Won't work
```

If you don't know the exact username, do a search first to discover it from the results.

### Rule 3: Never assume channels

The `search_query` parameter searches the **entire Slack workspace**. Never filter by channel until after global search.

### Slack Search Commands Reference

| Goal | MCP Tool Call |
|------|---------------|
| Find mentions of person | `conversations_search_messages(search_query="firstname.lastname", limit=50)` |
| Find person's own messages | `conversations_search_messages(search_query="from:firstname.lastname", limit=50)` |
| Find topic discussions | `conversations_search_messages(search_query="topic keyword", limit=50)` |
| Find person's PoCs/demos | `conversations_search_messages(search_query="from:firstname.lastname PoC demo", limit=30)` |
| Find discussions in a domain | `conversations_search_messages(search_query="task manager architecture", limit=50)` |

## Two Query Modes

### Mode 1: "Who knows about X?"
Returns people with expertise, ranked by depth, with evidence.

### Mode 2: "What does @person do?"
Returns their domains, style, projects, and communication profile.

## Data Gathering

### Sources to Mine

| Source | What to Extract |
|--------|-----------------|
| Slack messages | Topics they discuss, questions they answer, tone |
| Slack threads | Problems they solve, expertise they demonstrate |
| GitHub PRs (multiple repos) | Code areas, review patterns, technical depth |
| GitHub issues (multiple repos) | Problems they file/fix, roadmap items, epics |
| PR reviews | What they review = what they know |
| CODEOWNERS | Official ownership areas |
| GitHub Projects | Roadmap items, epics they're assigned to |

### GitHub Repos to Search

Read **PR_TARGET_REPO** and **ISSUE_REPO** from workspace rules (team config). Also search org-wide:

| Repo | Contains |
|------|----------|
| `<PR_TARGET_REPO>` (from team config) | Code, PRs, public issues |
| `<ISSUE_REPO>` (from team config) | Private issues, roadmap, epics, bugs |
| `elastic/elasticsearch` | ES core code and issues |

### Team Labels

Read **TEAM_LABEL** from workspace rules (team config) to filter by your team.

### Searching GitHub for Person Activity

**Always use `gh` CLI** - it's authenticated and can access private repos.

```bash
# PRs authored by person across Elastic org
gh search prs --author=USERNAME --org=elastic --limit=30

# Issues assigned to person (private repos too)
gh search issues --assignee=USERNAME --repo=<ISSUE_REPO> --limit=30

# Issues authored by person
gh search issues --author=USERNAME --repo=<ISSUE_REPO> --limit=30

# PRs reviewed by person
gh search prs --reviewed-by=USERNAME --org=elastic --limit=20

# Get detailed PR info
gh pr view 12345 --repo <PR_TARGET_REPO>

# Get issue with comments
gh issue view 12345 --repo <ISSUE_REPO> --comments

# List person's recent commits (via PRs, not git log)
gh search prs --author=USERNAME --repo=<PR_TARGET_REPO> --merged --limit=20
```

### Searching by Team Label

Read **TEAM_LABEL** and repos from workspace rules (team config):

```bash
# All open issues for your team
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --state=open

# Recent PRs for your team
gh search prs --repo=<PR_TARGET_REPO> --label="<TEAM_LABEL>" --limit=20

# Epics and roadmap items
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --label="epic"

# Bugs for the team
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --label="bug" --state=open
```

### Why `gh` over `git`

| Command | `git` | `gh` |
|---------|-------|------|
| View commits | Only local clone | Query any repo remotely |
| Private repos | Need clone + access | Already authenticated |
| Issues | Can't access | Full access |
| PR details | Can't access | Full access with comments |
| Search across repos | Not possible | `--org=elastic` |

## Building a Person Profile

For each person, gather:

```yaml
person:
  id: "@username"
  github: "username"
  real_name: "Full Name"
  
  expertise:
    - domain: "workflow execution engine"
      confidence: high
      evidence:
        - "Authored PR <PR_TARGET_REPO>#12345 - performance improvements"
        - "Owns epic <ISSUE_REPO>#456"
        - "Answered 12 questions about topic in #team-channel"
      
  projects:
    - name: "Performance & Scale Improvements"
      role: "lead"
      pr: "<PR_TARGET_REPO>#12345"
      issue: "<ISSUE_REPO>#456"
      
  team_labels:
    - "<TEAM_LABEL>"
```

## Query: "Who knows about X?"

### Process

1. **Search Slack** for messages about X:
   ```
   conversations_search_messages(search_query="X topic keyword", limit=50)
   ```
2. **Search GitHub** across multiple repos:
   ```bash
   gh search prs "X" --org=elastic --limit=20
   gh search issues "X" --repo=<PR_TARGET_REPO> --limit=20
   gh search issues "X" --repo=<ISSUE_REPO> --limit=20
   ```
3. For each hit, note who authored/participated
4. Check team labels to understand organizational context
5. Score and rank

### Output Format

```markdown
# Who knows about: [Topic]

## Top Experts

### 1. @person_name (High confidence)
**Why**: Authored the main implementation, owns the epic

**Evidence**:
- PR <PR_TARGET_REPO>#123: Implemented the core feature
- Epic <ISSUE_REPO>#456: Owns the roadmap item
- Thread [slack link]: Explained the architecture

**Best for**: Deep technical questions, architectural decisions
```

## Query: "What does @person do?"

### Process

1. **Search Slack for mentions** (what others say about them):
   ```
   conversations_search_messages(search_query="firstname.lastname", limit=50)
   ```

2. **Search Slack for their authored content** (what they do):
   ```
   conversations_search_messages(search_query="from:firstname.lastname", limit=50)
   ```

3. **Fetch their GitHub activity** using `gh` CLI:
   ```bash
   # PRs they authored
   gh search prs --author=USERNAME --org=elastic --limit=30
   
   # Issues assigned to them (roadmap, epics)
   gh search issues --assignee=USERNAME --repo=<ISSUE_REPO> --limit=30
   
   # PRs they reviewed (shows what areas they know)
   gh search prs --reviewed-by=USERNAME --org=elastic --limit=20
   
   # Issues they created (bugs found, features proposed)
   gh search issues --author=USERNAME --repo=<ISSUE_REPO> --limit=20
   ```

4. Check what team labels appear on their issues
5. Analyze communication style from Slack
6. Build comprehensive profile

## Storage & Updates

### Persist the Knowledge Graph

```
~/.cursor/knowledge/people/
├── by-person/
│   ├── sergi-massaneda.md
│   ├── shahar-glazner.md
│   └── ...
├── by-domain/
│   ├── workflow-execution.md
│   └── ...
├── by-team/
│   ├── one-workflow.md
│   └── ...
└── index.md
```

### Team Profile Example

```markdown
# Team: <Team Name>

**Label**: `<TEAM_LABEL>` (from team config)
**Slack**: #team-channel

## Members
| Person | Role | GitHub |
|--------|------|--------|
| @person1 | Lead | github-user1 |
| @person2 | Engineer | github-user2 |

## Active Epics
- Epic 1: <ISSUE_REPO>#123
- Epic 2: <ISSUE_REPO>#456

## Key Repos
- <PR_TARGET_REPO> (code, PRs)
- <ISSUE_REPO> (issues, roadmap)
```

## Example Queries

**"Who should I ask about X?"**
```
# Step 1: Search Slack
conversations_search_messages(search_query="X topic", limit=50)

# Step 2: Search GitHub (repos from team config)
gh search issues "X topic" --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --limit=20
gh search prs "X topic" --repo=<PR_TARGET_REPO> --label="<TEAM_LABEL>" --limit=20
```

**"What does the team own?"**
```
gh search issues --repo=<ISSUE_REPO> --label="<TEAM_LABEL>" --state=open --limit=30
gh search prs --repo=<PR_TARGET_REPO> --label="<TEAM_LABEL>" --limit=20
```

**"Build profile for someone"**
```
# Step 1: Slack mentions (what others say)
conversations_search_messages(search_query="firstname.lastname", limit=50)

# Step 2: Slack authored (what they do)
conversations_search_messages(search_query="from:firstname.lastname", limit=50)

# Step 3: GitHub PRs
gh search prs --author=USERNAME --org=elastic --limit=30

# Step 4: GitHub issues
gh search issues --assignee=USERNAME --repo=<ISSUE_REPO> --limit=20
```

**"Find all PRs someone authored"**
`gh search prs --author=USERNAME --org=elastic`
