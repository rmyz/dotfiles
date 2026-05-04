---
name: create-pr
description: Create a pull request from the user's fork. Handles branch creation, committing, pushing, and PR creation with proper close references. Uses team config from workspace rules. Use when the user asks to create a PR, open a pull request, submit changes, or push a branch.
---

# Create Pull Request

Creates PRs from the user's fork, following the team's workflow conventions. Team-specific values (labels, repos) are read from workspace rules. Fork is auto-detected from git remotes.

## Instructions

### Step 1: Understand Current State

Run these in parallel to assess the situation:

```bash
git branch --show-current
git status
git diff --stat
git log --oneline -5
git remote -v
```

Check:

- Are we on the right branch, or do we need to create one?
- Are there uncommitted changes?

**Auto-detect fork**: From `git remote -v`, identify the remote that is NOT `origin` and points to `github.com/<user>/kibana`. Extract:

- **Fork remote name** (e.g., `shaharfork`, `myfork`)
- **Fork owner** (e.g., `shahargl`) from the URL `github.com/<owner>/kibana`

If multiple non-origin remotes exist, ask the user which one is their fork.

### Step 2: Branch (if needed)

If on `main` or an unrelated branch, create a new feature branch:

```bash
git checkout -b <branch-name>
```

Branch naming conventions:

- Bug fix: `fix/<short-description>`
- Feature/enhancement: `feat/<short-description>`
- Performance: `perf/<short-description>`
- Refactor: `refactor/<short-description>`

If already on the correct feature branch, skip this step.

### Step 3: Stage and Commit

Stage relevant changes and commit:

```bash
git add <relevant-files>
git commit -m "$(cat <<'EOF'
<type>: <short description>

<optional longer description>

Closes <ISSUE_REPO>#<issue-number>
EOF
)"
```

**Commit types**: Read from team config, or default to `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`

**Important**:

- Do NOT use `--no-verify` unless the user explicitly asks
- Do NOT commit `.env`, credentials, or unrelated files
- Use a HEREDOC for the commit message to handle multi-line properly
- Include `Closes <ISSUE_REPO>#<issue>` in the commit body if an issue number is known
- Read **ISSUE_REPO** from workspace rules (team config). Example: `elastic/security-team`

### Step 4: Determine the Issue Number

The `Closes` reference links the PR to an issue so it auto-closes on merge.

**If known from conversation context**: Use it directly.
**If not known**: Ask the user:

```
What issue should this PR close? (e.g., <ISSUE_REPO>#12345)
Or type "none" if there's no related issue.
```

### Step 5: Push to Fork

Push the branch to the user's fork (use the auto-detected fork remote name):

```bash
git push -u <FORK_REMOTE> HEAD
```

If the branch already exists on the remote and needs updating:

```bash
git push <FORK_REMOTE> HEAD --force-with-lease
```

### Step 6: Create the PR

Read labels and repos from workspace rules (team config). Create the PR:

```bash
gh pr create \
  --repo <PR_TARGET_REPO> \
  --head <FORK_OWNER>:<branch-name> \
  --base <PR_BASE_BRANCH> \
  --title "<type>: <description>" \
  --label "<TEAM_LABEL>" \
  --label "<RELEASE_NOTE_LABEL>" \
  --label "<BACKPORT_LABEL>" \
  --label "<VERSION_LABELS...>" \
  --body "$(cat <<'EOF'
## Summary

Closes <ISSUE_REPO>#<issue-number>

<1-3 bullet points describing what changed and why>

EOF
)"
```

**Values from team config** (workspace rules):

- `TEAM_LABEL` -- e.g., `Team:One Workflow`
- `PR_TARGET_REPO` -- e.g., `elastic/kibana`
- `PR_BASE_BRANCH` -- e.g., `main`
- `RELEASE_NOTE_LABEL` -- e.g., `release_note:skip`
- `BACKPORT_LABEL` -- e.g., `backport:version`
- `VERSION_LABELS` -- e.g., `v9.3.0`, `v9.4.0`
- `ISSUE_REPO` -- e.g., `elastic/security-team`

**If team config is missing**: Ask the user for each value you need before proceeding:

- "What is your team's label? (e.g., Team:One Workflow)"
- "Which repo should I target for the PR? (e.g., elastic/kibana)"
- "Which repo should I use for issues? (e.g., elastic/security-team)"
- "What version labels should I add? (e.g., v9.3.0, v9.4.0)"

**Values auto-detected**:

- `FORK_REMOTE` -- from `git remote -v` (non-origin remote). If no non-origin remote found, ask: "What is your fork remote name?"
- `FORK_OWNER` -- extracted from fork remote URL. If unclear, ask: "What is your GitHub username?"

**Notes on `--head`**: Must be `<FORK_OWNER>:<branch-name>` (the GitHub username, not the remote name).

### Step 7: Generate Architecture Diagram (optional)

**Requires Excalidraw MCP server.** If not available, skip this step entirely.

To check: try calling the Excalidraw `read_me` tool. If it returns "Tool not found", skip to Step 8.

If Excalidraw MCP is available, generate a before/after architecture diagram using the `pr-architecture-diagram` skill:

1. Call Excalidraw `read_me` (once per conversation)
2. Create a before/after diagram with `create_view` showing what changed
3. Export to Excalidraw for an interactive link (`export_to_excalidraw`)
4. Generate a static image (`GenerateImage`), compress it, upload to the fork repo branch
5. Update the PR description to embed both the image and the interactive link:

```markdown
### Architecture

![Architecture Diagram](github_raw_image_url)

[View interactive diagram on Excalidraw](excalidraw_url)
```

### Step 8: Report Back

Share the PR URL with the user.

## Key Rules

- **Never force push to main/master**
- **Never skip hooks** unless user explicitly asks
- **Never commit secrets** (.env, credentials, keys)
- **Always use `--force-with-lease`** instead of `--force` if force push is needed
- **Always include `Closes` reference** when an issue exists
- Fork remote and owner are **auto-detected** from `git remote -v`
- All team-specific values (labels, repos) come from **workspace rules** (team config)
