---
name: ship-review
description: Ship phase 3. In a fresh session, verify acceptance criteria with recorded QA and run the cross-model review, stop for validation approval, then run tests, mechanical checks, and Scout once and create the draft PR. Needs branch, worktree path, and plan file from the implement phase.
disable-model-invocation: true
---

# Ship: review

Phase 3 of `ship`. The invariants, stops, and session rules in
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
4. Run ship's "Ensure the development stack"; it is idempotent and reuses the
   implement phase's servers when they are still healthy.

## Validate

Run validation as one phase with no intermediate human gate. Fix confirmed failures
and rerun the affected checks until green. Tests and mechanical checks do not run
here; they run exactly once after the validation stop, when review fixes are already
in. Validation before the stop is behavior and review: acceptance criteria, recorded
QA, and the cross-model review.

### Acceptance criteria and QA

Before the reviews, list every acceptance criterion from the issue or task
description. Verify each one against the implementation. A criterion is done only
when you can point at the code and the observed behavior that fulfills it. If any
criterion fails or cannot be verified, fix it before continuing; do not hand unmet
criteria to the reviews.

Run the behavior QA in a subagent so browser snapshots stay out of this session.
Brief it with the plan summary, the acceptance criteria, the Kibana URL, and the
`elastic`/`changeme` credentials. The subagent decides how the change is actually
used:

- **UI surface**: test it in the running Kibana with `agent-browser`, covering the
  relevant edge cases (cancel/confirm, empty states). Record the whole pass:
  `agent-browser record start ~/Downloads/qa-<branch>.webm` before the first
  interaction, `agent-browser record stop` after the last. Verify the real effect
  (network, saved objects) when it applies, not just the visual layer.
- **No UI surface**: skip the browser and the video; QA it the way it is used (hit
  the endpoint, run the command, check logs and relevant tests).

The subagent reports what it tested, what passed or failed, and the absolute video
path. Present that path at the validation stop so the user can watch it before their
own manual pass.

### Cross-model review

After QA, load `~/.agents/skills/cross-review/SKILL.md` and follow
it over the change set. It runs three reviewers on different model families with the
technical and product rubrics, then synthesizes findings into act-on, consider,
noted, and dismissed buckets weighted by cross-model agreement. Give it the plan file
path for the intent.

<!-- Alternative: load `review-team` in local review mode here in place of
cross-review; everything below applies unchanged. -->

Never apply the outcome automatically. Present the synthesized buckets with a
proposed action plan ordering what to fix. Let the user choose which findings matter
at the validation stop; the chosen fixes are applied after approval.

### PR size

Measure total additions and deletions against the merge base, including untracked
files. Record whether the result respects the global 500-line rule and, if it does
not, whether a coherent split exists. The assessment goes into the validation stop.

**VALIDATION STOP.** Present:

- Changed files and a brief description of each
- QA outcome and the video path when one was recorded
- The synthesized review buckets and the proposed action plan
- Changed-line count and split assessment
- Running Kibana URL
- Any remaining risks or blockers
- A note that tests, mechanical checks, and Scout run once after approval

End the response and wait for explicit approval to create the draft PR, together with
the user's selection of review findings to apply.

## After approval: fixes and the checks

Apply the review findings the user selected. Then run the full check suite exactly
once, in this order:

### Targeted tests

Run every targeted unit, integration, API, and UI test named in the approved plan.
Add the smallest test that proves new non-trivial behavior.

### Mechanical checks

```bash
node scripts/check.js --scope=local
```

Use `local`, not `branch`, because changes are still uncommitted. If a
`kibana.jsonc` owner changed, run `node scripts/generate codeowners` and keep the
generated change.

### Scout

Discover Scout configs by walking from each changed file to its nearest
`kibana.jsonc`, then checking that package for
`test/scout*/{ui,api}/playwright.config.ts`.

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
fix requires changes beyond the mechanical (new behavior, scope changes), stop and
report instead of proceeding to the PR.

## Create the draft PR

Walk the full diff against the merge base file by file, including
untracked files: every hunk must belong to this task. Revert anything unrelated
(debug prints, formatting churn, leftovers, generated files that should not ship) and
report what was removed. Do not open a PR containing unrelated changes.

Then load `create-pr` for commit and PR metadata, but use the ordering below
instead of its default push step. Use the issue and close/address decision recorded in
the plan so this phase introduces no new human stop. Inspect status, diff, and
recent commits first. Stage only intended files. After creating the feature commit,
merge the latest `upstream/main` before pushing. Resolve any conflicts and rerun
affected validation before continuing.

```bash
git fetch upstream main
git merge --no-edit upstream/main
git push -u origin HEAD
PR_URL=$(gh pr create --repo elastic/kibana --head rmyz:<branch> --base main --draft)
gh pr comment "$PR_URL" --body '/ci'
```

Labels come from `team-config`. When a QA video was recorded, add a **Demo** section
to the PR description with a clearly marked placeholder and repeat the video's
absolute path in the final response, so the user can drag the file in manually. The
PR opens as a draft and stays a draft. The `/ci` comment triggers CI after creation.
Ship ends here.

Afterwards, run `handoff` when the user wants the per-team review-request messages,
and `teardown` once the PR merges or the worktree is abandoned.
