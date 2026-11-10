---
name: ship-review
description: Ship phase 3. In a fresh session, verify acceptance criteria, apply confirmed cross-model review fixes, run checks, and create a draft PR without approval stops. Record a demo after PR creation when useful. Needs branch, worktree path, and plan file from the implement phase.
disable-model-invocation: true
---

# Ship: review

Phase 3 of `ship`. The invariants and session rules in
`~/.agents/skills/ship/SKILL.md` apply; read that file first.

## First actions

Run ship's "First actions" and "Confirm bootstrap" from
`~/.agents/skills/ship/SKILL.md`. Read the plan's `Deviations` section too: plan plus
deviations is the intent the implementation must be judged against. Include untracked
files in the change set. Then:

- Decide whether the change set needs a running Kibana, using the rule in
  `~/.agents/skills/kibana-dev-stack/SKILL.md`. Only when it does, follow that file; it is
  idempotent and reuses the implement phase's servers when they are still healthy.
  When it starts a new Kibana, use the port that `launch-server.sh` prints. When it
  reuses one, take the port from the `kibana:<port>` terminal title. Record the
  decision in the report.

## Validate

Fix confirmed failures and rerun affected checks until green. Complete behavior QA
when it applies, the cross-model review, and the mechanical checks before creating
the draft PR. The cross-model review and `node scripts/check.js --scope=local` are
required for every change set, including docs-only changes. Stop only for a blocker.

### Acceptance criteria and QA

Before the reviews, list every acceptance criterion from the issue or task
description. Verify each one against the implementation. A criterion is done only
when you can point at the code and the observed behavior that fulfills it. Rerun
each check in the plan's `Verification` section yourself. Do not accept the implement
phase's evidence without a rerun. If any criterion fails or cannot be verified, fix
it before continuing; do not hand unmet criteria to the reviews.

Skip behavior QA when step 4 decided the change set needs no running Kibana, and
say so in the report. Otherwise, for UI changes, run behavior QA through a
subagent that uses `agent-browser`.
Brief it with the acceptance criteria, Kibana URL, credentials, and
`~/.agents/skills/kibana-verify/SKILL.md` with the feature file the plan names. The
subagent creates or updates that feature file after the run. Verify the
happy path, relevant edge cases, and backend effects. The subagent returns a
screenshot path or a response body for each check. Open the screenshots yourself
before you count a check as passed. For non-UI changes, use the endpoint or command
directly. Record what passed and what failed. Do not record a
demo before creating the PR.

### Cross-model review

Load `~/.agents/skills/cross-review/SKILL.md` and follow it over the change set in
local mode. It runs four reviewers on different model
families with the technical and product rubrics, then synthesizes findings into
act-on, consider, noted, and dismissed buckets weighted by cross-model agreement.
Give it the plan file path for the intent.

Before you apply any fix, run `"$HOME/.agents/skills/ship/scripts/snapshot.sh"` and
record the printed SHA as `PRE`.

Verify each finding against the code. Fix confirmed correctness, security, and
maintainability issues that block a PR and fit the task. Record which findings you
fixed, which you did not fix, and why. Stop if a finding needs a product decision
that the task context cannot resolve.
Do not change UI copy without approval of the exact proposed text.

When you fixed at least one finding, run a second round on the fixes only. Run the snapshot script
again and record the SHA as `POST`. Run cross-review with scope
`git diff <PRE> <POST>`. Give it the round-one findings and tell it not to
repeat them. Fix confirmed Act-on findings from round two. Do not run a third round.
If round two shows the approach itself is wrong, stop and report it as a blocker.

### PR size

Measure total additions and deletions against the merge base, including untracked
files. If the change exceeds 500 lines and the plan has no `Size` reason, stop and
report a split proposal.

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
`test/scout*/{ui,api}/playwright.config.ts` too. If that adds a Scout suite after
step 4 skipped servers, read and follow `~/.agents/skills/kibana-dev-stack/SKILL.md` now.

Then run the suite as `~/.agents/skills/kibana-dev-stack/SKILL.md` describes under "Scout".

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
- Risk: breaking changes, migrations, privilege changes, and the `Size` reason from
  the plan, when any apply

If `create-pr` halts due to merge conflicts against `upstream/main`, resolve them, rerun
affected checks or QA, and invoke `create-pr` again.

After the PR exists, record a short demo for visual changes. Use the verified
happy path and save the video as
`~/Code/ai-generated/<work-id>/demo/qa.webm`. Give the user its path for manual drag-and-drop. If recording
fails, report it with the PR URL.

Report the PR URL, the review findings fixed, the findings left open and why, the
check results, the plan's `Follow-ups`, and any remaining considerations. Remind the user about private
issue linking or demo upload when applicable.

