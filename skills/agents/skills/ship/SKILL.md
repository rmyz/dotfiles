---
name: ship
description: End-to-end Kibana workflow taking one task from intake to a draft PR on elastic/kibana with per-team review requests prepared. Invoke explicitly with an issue link, PR number, or task description.
disable-model-invocation: true
---

# Ship

Takes one Kibana task from intake to a draft PR, stopping at three human gates.
Orchestrates existing skills rather than duplicating them.

## Invariants

- `origin` is the fork (`rmyz/kibana`); `upstream` is `elastic/kibana`.
- Diff, branch, and rebase against `upstream/main`. **Never `origin/main`** — it is
  thousands of commits stale and is never synced.
- Skills live in `~/.agents/skills/`. Ignore `~/.claude` and `~/.cursor`.

## Human gates

| Gate | Placed after | Waits for |
|---|---|---|
| 1 | Plan validated by momus (Step 3) | Greenlight to implement |
| 2 | Checks and Scout green (Step 6) | Confirmation the work is done |
| 3 | review-team report (Step 7) | Which findings to address |

At each gate: present the result, then **end the response**. Do not create todos, do
not read further files, do not start the next step. Absence of objection is not
approval.

## Step 1 — Worktree

```bash
git fetch upstream main
wt switch --create <branch>
```

Branch naming: `fix/`, `feat/`, `perf/`, or `refactor/` plus a short description.

`wt` runs `yarn kbn bootstrap` in the background (usually under 2 minutes). Steps 2–4
can proceed while it runs, but **Step 5 fails with `TS Project map missing` until it
finishes** — confirm via `wt config state logs` before any type check or test.

## Step 2 — Gather resources

Ask once for whatever exists:

- GitHub issue and prior related PR links
- Slack threads
- Screenshots, Figma URLs

Read everything provided before planning. If nothing is provided, name what would
have helped and proceed on the task description alone — do not block.

## Step 3 — Plan, then stop

1. Explore first. Name every file to be changed *before* writing the plan; prefer
   `codegraph_explore` over a grep-and-read loop.
2. Write the plan to `.omo/plans/<branch>.md`. It must state each file, the change
   per file, and how that change gets verified.
3. Validate it with momus, passing the file path as the **entire** prompt:
   `task(subagent_type="momus", prompt=".omo/plans/<branch>.md")`
4. Address what momus flags and revise the file.

**GATE 1 — HARD STOP.** Present the plan plus momus's findings, then end the response.
No todos. No source edits. Wait for an explicit greenlight.

## Step 4 — Implement

Work the entire plan checklist without pausing for confirmation between items. Stop
only on a genuine blocker, or when every item is done.

`lsp_diagnostics` must be clean on each changed file before moving to the next.

## Step 5 — Mechanical checks

```bash
node scripts/check.js --scope branch --base-ref upstream/main
```

Covers type check, eslint, and jest for affected packages. Fix and re-run until clean.

If any `kibana.jsonc` `owner` field changed, also run `node scripts/generate codeowners`
and commit the result — otherwise Step 9 reports stale ownership.

## Step 6 — Scout tests

Only when the changed packages have them. Discovery: walk up from each changed file to
the nearest `kibana.jsonc`, then look for `test/scout*/{ui,api}/playwright.config.ts`
beneath that package root.

```bash
node scripts/scout start-server --arch stateful --domain classic
node scripts/scout run-tests --arch stateful --domain classic --config <playwright.config.ts>
```

Start the server once and keep it up across runs; do not reboot ES and Kibana per
invocation. `scripts/check.js` does not run Scout, so this step is additive rather
than redundant.

**GATE 2 — HARD STOP.** Report check and Scout results, then end the response.

## Step 7 — review-team

Load the `review-team` skill in **branch review mode**: six reviewers in parallel,
then one consolidated report. Reviewers report only on lines this branch changed.

This runs *after* Step 5 by design. Six agents reading a diff that does not typecheck
spends the most expensive step in this workflow on the cheapest class of bug.

**GATE 3 — HARD STOP.** Present the consolidated report and action plan, then end the
response. Wait for the user to choose which findings to address. Re-run Step 5 after
applying any fixes.

## Step 8 — Draft PR

Load the `create-pr` skill for commit, push, and PR creation. The values that matter:

```bash
git push -u origin HEAD
gh pr create --repo elastic/kibana --head rmyz:<branch> --base main --draft
```

Labels come from `team-config`. The PR opens as a draft and stays one.

## Step 9 — Route reviewers

```bash
co <PR_NUMBER>
```

`co` groups files by owner *set* (comma-joined), so a team spanning two sets appears
twice — **merge by team** before drafting messages.

Draft one message per team:

> Hey team, I need your codeowners review in this PR, it \<one-line description\> and
> modifies the following files: \<that team's files\>

**Do not post these.** Hand them to the user, who sends them after
`gh pr ready <PR_NUMBER>`.

## Teardown

Once the PR merges: `wt remove <branch>`.
