---
name: create-pr
description: Publish a branch as a draft PR on elastic/kibana. Handles commit, sync with upstream/main, push to origin, draft PR creation with team labels, and /ci trigger. Uses team config from workspace rules. Use when the user asks to create a PR, open a pull request, or submit changes.
---

# Create PR

Publishes the current branch as a draft pull request on `elastic/kibana` from the user's fork (`origin`). Reads team labels and defaults from `AGENTS.md`.

## Workflow

### 1. Preconditions and Fork Detection

Run these checks:

```bash
git branch --show-current
git status --short
git remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#'
```

- If on `main`, stop. Ask for the target branch name or create it before continuing.
- Fork username is `FORK_OWNER`, extracted from `origin` (e.g. `rmyz`). Never treat non-`origin` remotes as the fork.
- Never push branches or create branches on `upstream` (`elastic/kibana`).
- Always push branches to the user's fork `origin` (`rmyz/kibana`), and create the PR pointing toward `elastic/kibana:main`.
- Target repository is always `elastic/kibana`; base branch is `main`.

### 2. Stage and Commit

If the working tree has uncommitted changes:

- Stage only the files intended for this task.
- Use caller context (e.g. from `/ship` plan) for the commit message. If missing in standalone mode, ask the user for commit type and summary.
- Format:

```bash
git commit -m "$(cat <<'EOF'
<type>: <short summary>

<optional longer description>
EOF
)"
```

- Allowed types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`.
- Do not commit secrets, untracked debris, or use `--no-verify`.
- Only add `Closes #<id>` or `Addresses #<id>` to the commit body when the issue belongs to `elastic/kibana`. Never mention private repository issues in public commits.

### 3. Sync Upstream and Push

Always sync with `upstream/main` before pushing:

```bash
git fetch upstream main
git merge --no-edit upstream/main
```

- If conflicts occur, stop immediately. Report the conflicting files so validation can be re-run after resolving them.
- Push only to the user's fork (`origin`): `git push -u origin HEAD`. Never push to `upstream`.

```bash
git push -u origin HEAD
```

Use `git push origin HEAD --force-with-lease` when updating an existing remote branch. Never force push to `main`.

### 4. PR Metadata and Body

Read team labels from `AGENTS.md` (`TEAM_LABEL`, `RELEASE_NOTE_LABEL`, `BACKPORT_LABEL`). Never pass a version label.

#### PR Title Rules

- Format: `[<Scope>] <What changed>`.
- Example: `[Nightshift] Register investigation URL locator`.
- Always use a short, useful title.
- Never use conventional commit standards or prefixes such as `feat:`, `fix:`, or `refactor:`. Only use `[Scope] What changed`.

#### PR Description Rules

- Structure:
  1. `## Summary`
  2. `## Demo` (conditional: visual changes or recorded QA only)
  3. `## How to test`
- **Summary**:
  - Put `Closes #<id>` or `Addresses #<id>` at the top of the section (elastic/kibana issues only).
  - For private-repo issues: omit the reference from the PR body. Remind the user to connect it via the Development field on the private issue.
  - Follow with 1-3 concise bullets explaining what changed and why, plus any non-obvious user impact or key implementation note.
- **Demo**:
  - Placed before `## How to test`.
  - Include this section only for visual changes or when QA recordings exist. Omit it entirely otherwise.
  - If multiple demo recordings were captured (e.g. happy path and failure scenario), list a clearly labeled drag-and-drop placeholder for each one.
- **How to test**:
  - Numbered list of manual steps so reviewers can reproduce and verify locally.
  - End with an explicit verification check (`Verify <expected result>`).
  - Never list Jest, FTR, or Scout test files that CI runs automatically.

### 5. Create Draft PR and Trigger CI

Always open PRs as draft. Always set `--head` to `"<FORK_OWNER>:<branch>"` (for example, `rmyz:<branch>`) pointing toward `--repo elastic/kibana --base main`. Never omit the `<FORK_OWNER>:` prefix. Always assign the PR to the author (`@me` or `<FORK_OWNER>`). Trigger CI immediately with `/ci`:

```bash
PR_URL=$(gh pr create \
  --repo elastic/kibana \
  --head "<FORK_OWNER>:<branch>" \
  --base main \
  --draft \
  --assignee "@me" \
  --title "[<Scope>] <What changed>" \
  --label "<TEAM_LABEL>" \
  --label "<RELEASE_NOTE_LABEL>" \
  --label "<BACKPORT_LABEL>" \
  --body "$(cat <<'EOF'
## Summary

Closes #<id>

- <what changed and why>
- <user impact or key detail, if helpful>

## Demo

<!-- Drag and drop video or screenshot here -->

## How to test

1. <action>
2. <action>
3. Verify <expected result>
EOF
)")

gh pr comment "$PR_URL" --body '/ci'
```

Omit `Closes #<id>` if there is no public issue. Omit `## Demo` if there is no visual change or recorded artifact.

Output the created `PR_URL`.
