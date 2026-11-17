---
name: create-pr
description: Publish a branch as a draft PR on elastic/kibana. Handles commit, sync with upstream/main, push to origin, draft PR creation with team labels, and /ci trigger. Uses team config from AGENTS.md. Use when the user asks to create a PR, open a pull request, or submit changes.
---

# Create PR

Publishes the current branch as a draft pull request on `elastic/kibana` from the user's fork (`origin`). Reads `TEAM_LABEL`, `RELEASE_NOTE_LABEL`, `BACKPORT_LABEL`, and the remote rules from `AGENTS.md`.

## Workflow

### 1. Preconditions and Fork Detection

Run these checks:

```bash
git branch --show-current
git status --short
git remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#'
```

- If on `main`, create a branch named `<type>/<short-description>`, where `<type>` is the commit type and `<short-description>` is two or three words naming the dominant directory of the diff. Then continue.
- Fork username is `FORK_OWNER`, extracted from `origin` (e.g. `rmyz`).

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

- Never use `--no-verify`.
- Only add `Closes #<id>` or `Addresses #<id>` to the commit body when the issue belongs to `elastic/kibana`.

### 3. Sync Upstream and Push

Always sync with `upstream/main` before pushing:

```bash
git fetch upstream main
git merge --no-edit upstream/main
```

- If conflicts occur, stop immediately. Report the conflicting files so validation can be re-run after resolving them.

```bash
git push -u origin HEAD
```

### 4. PR Metadata and Body

Use the label values that `AGENTS.md` defines for `TEAM_LABEL`, `RELEASE_NOTE_LABEL`, and `BACKPORT_LABEL`.

#### PR Title Rules

- Format: `[<Scope>] <What changed>`.
- Example: `[Nightshift] Register investigation URL locator`.
- Keep the title under 70 characters.
- Never use conventional commit standards or prefixes such as `feat:`, `fix:`, or `refactor:`. Only use `[Scope] What changed`.

#### PR Description Rules

- Structure:
  1. `## Summary`
  2. `## Demo` (conditional: visual changes or recorded QA only)
  3. `## Risk` (conditional: see below)
  4. `## How to test`
- **Summary**:
  - Put `Closes #<id>` or `Addresses #<id>` at the top of the section (elastic/kibana issues only).
  - For private-repo issues: omit the reference from the PR body. Remind the user to connect it via the Development field on the private issue.
  - Follow with concise bullets explaining what changed and why, plus any non-obvious user impact or key implementation note.
- **Demo**:
  - Placed before `## How to test`.
  - Include this section whenever QA demo files exist. Omit it entirely otherwise.
  - Attach every demo file (recording, screenshot, or text output). Label each one, for example happy path and failure scenario.
  - After the PR exists, upload the files with `gh pr edit <n> --repo elastic/kibana --body-file <body.md> --attach './file.png#alt text'` (repeat the flag per file). `gh` uploads each file to `user-attachments` and appends `![alt](url)` to the body. Paths resolve relative to the body file's directory, then the cwd.
  - Use a `Cell | Before | After` table only when the change alters an existing screen. `gh` rewrites only markdown references (`![alt](./a.png)`), not `<img src="./a.png">`, and markdown images cannot set width. So run `--attach` once, read the URLs back with `gh pr view <n> --json body -q .body`, rebuild the body with `<img src="<url>" width="300">` tags, and apply it with `--body-file` and no `--attach`. Each `--attach` run uploads again, so never repeat it for the same files.
  - A body reference only matches an attached file when it uses the same text as the flag without the `#alt` part (`![alt](./a.png)` with `--attach ./a.png#alt` fails). When it fails, `gh` appends the uploaded files at the end, so read the URLs from there and remove the appended lines.
  - Check that the final body contains `user-attachments` and no local paths. If the upload fails, report the demo file paths with the PR URL.
- **Risk**:
  - Include it only when the change renames or removes a stored id, schema field,
    route, or URL parameter; adds a migration; changes privileges; or exceeds 500
    lines. Omit it otherwise.
  - One bullet per item: what breaks, and for whom.
  - Add a revert note only when a plain revert does not undo the change, for example
    after a migration has run or data has been written.
- **How to test**:
  - Numbered list of manual steps so reviewers can reproduce and verify locally.
  - End with an explicit verification check (`Verify <expected result>`).
  - Never list Jest, FTR, or Scout test files that CI runs automatically.

### 5. Create Draft PR and Trigger CI

Always open PRs as draft. Always set `--head` to `"<FORK_OWNER>:<branch>"` (for example, `rmyz:<branch>`) pointing toward `--repo elastic/kibana --base main`. Never omit the `<FORK_OWNER>:` prefix. Always assign the PR to `@me`. Trigger CI immediately with `/ci`:

```bash
BODY_FILE="$HOME/Code/ai-generated/<work-id>/files/pr-body.md"
mkdir -p "$(dirname "$BODY_FILE")"
cat > "$BODY_FILE" <<'EOF'
## Summary

Closes #<id>

- <what changed and why>
- <user impact or key detail, if helpful>

## Demo

![<label>](<demo-file>)

## How to test

1. <action>
2. <action>
3. Verify <expected result>
EOF

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
  --body-file "$BODY_FILE")

gh pr comment "$PR_URL" --body '/ci'
```

Omit `Closes #<id>` if there is no public issue. Omit `## Demo` if there is no demo file. Insert `## Risk`
before `## How to test` only when the Risk rules apply. With demo files, repeat the
`![<label>](<demo-file>)` line per file, then upload them as described under **Demo**.

Output the created `PR_URL`.
