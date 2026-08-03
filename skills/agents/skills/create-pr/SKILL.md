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

**Remote layout**: `origin` **is** the fork; `upstream` is `elastic/kibana`.

```bash
# Fork owner, read from origin (e.g. "rmyz").
git remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#'
```

Do **not** infer the fork from "the remote that is not `origin`" — this clone
carries ~25 other contributors' remotes, and that rule picks one at random.

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

Push the branch to the fork, which is `origin`:

```bash
git push -u origin HEAD
```

If the branch already exists on the remote and needs updating:

```bash
git push origin HEAD --force-with-lease
```

### Step 6: Create the PR

Read labels and repos from workspace rules (team config). Create the PR:

```bash
gh pr create \
  --repo elastic/kibana \
  --head <FORK_OWNER>:<branch-name> \
  --base main \
  --draft \
  --title "<type>: <description>" \
  --label "<TEAM_LABEL>" \
  --label "<RELEASE_NOTE_LABEL>" \
  --label "<BACKPORT_LABEL>" \
  --body "$(cat <<'EOF'
## Summary

Closes <ISSUE_REPO>#<issue-number>

<1-3 bullet points describing what changed and why>

EOF
)"
```

**Values from team config**, which lives in the workspace rules (`AGENTS.md`) --
read them from there, not from a skill: `TEAM_LABEL`, `RELEASE_NOTE_LABEL`,
`BACKPORT_LABEL`, `ISSUE_REPO`.

Never pass a version label -- those are added manually.

**If the workspace rules carry no team config**: ask the user for each value you
need before proceeding:

- "What is your team's label? (e.g., Team:One Workflow)"
- "Which repo should I target for the PR? (e.g., elastic/kibana)"
- "Which repo should I use for issues? (e.g., elastic/security-team)"

**Values auto-detected**:

- `FORK_OWNER` -- extracted from the `origin` URL (see Step 1). Currently `rmyz`.

**Notes on `--head`**: Must be `<FORK_OWNER>:<branch-name>` (the GitHub username, not the remote name) -- e.g. `rmyz:fix/my-branch`.

**Notes on `--draft`**: PRs open as drafts. Mark ready with `gh pr ready <number>`
once codeowner reviews are actually wanted.

### Step 8: Report Back

Share the PR URL with the user.

## Key Rules

- **Never force push to main/master**
- **Never skip hooks** unless user explicitly asks
- **Never commit secrets** (.env, credentials, keys)
- **Always use `--force-with-lease`** instead of `--force` if force push is needed
- **Always include `Closes` reference** when an issue exists
- **`origin` is the fork; `upstream` is `elastic/kibana`** -- never treat a non-origin remote as the fork
- All team-specific values (labels, repos) come from **workspace rules** (team config)
