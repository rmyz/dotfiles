---
name: ship-review
description: Ship phase 3. In a fresh session, verify acceptance criteria, apply confirmed cross-model review fixes, run checks, and create a draft PR without approval stops. Record a demo after PR creation when useful. Needs branch, worktree path, and plan file from the implement phase.
disable-model-invocation: true
---

# Ship: review

Phase 3 of `ship`. The invariants and session rules in
`~/.agents/skills/ship/SKILL.md` apply; read that file first.

## First actions

The spawn payload (branch, worktree path, plan file) is the whole truth; there is no
prior conversation. In order:

1. Set the worktree path as the working directory; verify `git branch
   --show-current` matches the payload branch.
2. Read the plan file, including its `Deviations` section. Plan plus deviations is
   the intent the implementation must be judged against.
3. Derive the change set from `git status` and `git diff upstream/main...`,
   including untracked files.
4. Decide whether the change set needs a running Kibana. It does when it changes
   code that runs in Kibana (server, public, or UI code) or when the plan names Scout
   tests. It does not when it only changes docs, Markdown, tests without Scout, or
   config the running app does not read. Only when it does, run ship's "Ensure the
   development stack"; it is idempotent and reuses the implement phase's servers when
   they are still healthy. Use the port that `launch-server.sh` prints; do not look it
   up again. Record the decision in the report.

## Validate

Fix confirmed failures and rerun affected checks until green. Complete behavior QA
when it applies, the cross-model review, and the mechanical checks before creating
the draft PR. The cross-model review and `node scripts/check.js --scope=local` are
required for every change set, including docs-only changes. "Cross-model review"
means `cross-review` in OpenCode and `review-team` elsewhere. Stop only for a blocker.

### Acceptance criteria and QA

Before the reviews, list every acceptance criterion from the issue or task
description. Verify each one against the implementation. A criterion is done only
when you can point at the code and the observed behavior that fulfills it. If any
criterion fails or cannot be verified, fix it before continuing; do not hand unmet
criteria to the reviews.

Skip behavior QA when step 4 decided the change set needs no running Kibana, and
say so in the report. Otherwise, for UI changes, run behavior QA through a `build`
subagent using `agent-browser`.
Brief it with the acceptance criteria, Kibana URL, and credentials. Verify the
happy path, relevant edge cases, and backend effects. For non-UI changes, use the
endpoint or command directly. Record what passed and what failed. Do not record a
demo before creating the PR.

### Cross-model review

In OpenCode, load `~/.agents/skills/cross-review/SKILL.md` and follow it over the
change set. It runs four reviewers on different model families with the technical
and product rubrics, then synthesizes findings into act-on, consider, noted, and
dismissed buckets weighted by cross-model agreement. Give it the plan file path for
the intent.

In any other agent, cross-review is unavailable. Load
`~/.agents/skills/review-team/SKILL.md` and follow it in local review mode instead;
everything below applies unchanged.

Verify each finding against the code. Fix confirmed correctness, security, and
maintainability issues that block a PR and fit the task. Record which findings you
fixed, which you did not fix, and why. Stop if a finding needs a product decision
that the task context cannot resolve.
Do not change UI copy without approval of the exact proposed text.

### PR size

Measure total additions and deletions against the merge base, including untracked
files. If the change exceeds 500 lines, assess whether a coherent split is needed.

## Run checks

Run the check suite after review fixes, before creating the draft PR:

### Targeted tests

Run every targeted unit, integration, API, and UI test named in the plan.
Add the smallest test that proves new non-trivial behavior.

### Mechanical checks

```bash
node scripts/check.js --scope=local
```

Use `local`, not `branch`, because changes are still uncommitted. If a
`kibana.jsonc` owner changed, run `node scripts/generate codeowners` and keep the
generated change.

### Scout

Use the Scout config paths recorded in the plan. If the final diff changes a package
not covered by the plan, check that package's
`test/scout*/{ui,api}/playwright.config.ts` too.

Reuse the already-running Kibana and shared Elasticsearch instance only when its
server settings satisfy the test. Create `.scout/servers/local.json` with the current
Kibana URL, Elasticsearch `9200`, `elastic`/`changeme` credentials, a trial license,
and the absolute `.ftr/role_users.json` path. Then run only the local stateful classic
target:

```json
{
  "serverless": false,
  "http2": false,
  "uiam": false,
  "isCloud": false,
  "cloudUsersFilePath": "<absolute-worktree>/.ftr/role_users.json",
  "license": "trial",
  "hosts": {
    "kibana": "http://localhost:<kibana-port>",
    "elasticsearch": "http://localhost:9200"
  },
  "auth": { "username": "elastic", "password": "changeme" }
}
```

Run:

```bash
node scripts/playwright test --config <playwright.config.ts> \
  --project local --grep @local-stateful-classic
```

Do not run `node scripts/scout start-server` or `node scripts/scout run-tests`; both
manage another local stack. If a Scout suite requires a custom server config that the
development stack does not provide, the PR is blocked. Do not start a second
Elasticsearch instance or proceed. Resolve the profile conflict or get an explicit
change to the single-Elasticsearch requirement.

Fix confirmed failures from any of the three and rerun only the affected check. If a
fix changes behavior, rerun affected behavior QA. Stop only when a change requires
a product decision or exceeds the task scope.

## Create the draft PR

Walk the full diff against the merge base file by file, including
untracked files: every hunk must belong to this task. Revert anything unrelated
(debug prints, formatting churn, leftovers, generated files that should not ship) and
report what was removed. Do not open a PR containing unrelated changes.

Then invoke the `create-pr` skill to perform the commit, upstream sync, push, draft PR
creation, and `/ci` comment. Pass context from the plan and review session:
- Issue key and close/address status from the plan file
- Short manual testing steps observed during validation

If `create-pr` halts due to merge conflicts against `upstream/main`, resolve them, rerun
affected checks or QA, and invoke `create-pr` again.

After the PR exists, record a short demo for visual changes. Use the verified
happy path and save the video as
`~/Code/oc-generated/demo/qa-<branch-safe>.webm`, with `/` in the branch name
replaced by `-`. Give the user its path for manual drag-and-drop. If recording
fails, report it with the PR URL.

Report the PR URL, the review findings fixed, the findings left open and why, the
check results, and any remaining considerations. Remind the user about private
issue linking or demo upload when applicable. Ship ends here.

Afterwards, run `handoff` when the user wants the per-team review-request messages,
and `teardown` once the PR merges or the worktree is abandoned.
