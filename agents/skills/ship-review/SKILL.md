---
name: ship-review
description: Ship phase 3. In a fresh session, verify acceptance criteria, apply confirmed cross-model review fixes, run checks, and create a draft PR without approval stops. Attach a QA demo (recording or screenshot) to the PR. Needs branch, worktree path, and plan file from the implement phase.
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

Fix confirmed failures and rerun affected checks until green. Run the cross-model
review first, then behavior QA and the demo on the reviewed code, then the
mechanical checks, before creating the draft PR. The cross-model review and
`node scripts/check.js --scope=local` are required for every change set, including
docs-only changes.

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
Do not change UI copy. Report the proposed text under the findings left open.

When you fixed at least one finding, run a second round on the fixes only. Run the snapshot script
again and record the SHA as `POST`. Run cross-review with scope
`git diff <PRE> <POST>`. Give it the round-one findings and tell it not to
repeat them. Fix confirmed Act-on findings from round two. Do not run a third round.
If round two shows the approach itself is wrong, stop and report it as a blocker.

### PR size

Measure total additions and deletions against the merge base, including untracked
files. If the change exceeds 500 lines and the plan has no `Size` reason, stop and
report a split proposal.

### Acceptance criteria and QA

Every acceptance criterion in the plan must pass. QA runs on the code left after the
cross-model review fixes. Take the numbered criteria from the plan's `Acceptance criteria` section,
not from memory. Run each check in the plan's `Verification` section yourself. If
any criterion fails or cannot be verified, fix it before continuing.

Skip behavior QA when First actions decided the change set needs no running Kibana. Then
verify each criterion against the code and the plan's targeted tests, and say so in
the report. Otherwise run behavior QA through a subagent. Brief it with the numbered
criteria, the plan file path, the Kibana URL, and
`~/.agents/skills/kibana-verify/SKILL.md` with the feature file the plan names.
Tell it to follow that skill, including its plan, result format, and validation.
Cover the happy path, relevant edge cases, and backend effects.

The subagent returns the path of `verify.json`. Run
`node ~/.agents/skills/kibana-verify/scripts/validate-verify.mjs <verify.json> --plan <plan-file>`
yourself. Count QA as done only when it prints `OK` and the verdict is `pass`. On
`fail`, fix the code and rerun the QA, then capture the demo again. On `blocked`,
fix the cause and rerun.

### Demo

The evidence files next to `verify.json` in `~/Code/ai-generated/<work-id>/demo/`
are the demo. Pass one file per acceptance criterion to `create-pr`, at most five,
in criterion order. When QA was skipped, run each criterion's check in a terminal
and save its output as `<ac>-output.txt` in the same directory.

## Run checks

Run the check suite after the review fixes and QA, before creating the draft PR:

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
First actions skipped servers, read and follow `~/.agents/skills/kibana-dev-stack/SKILL.md` now.

Then run the suite as `~/.agents/skills/kibana-dev-stack/SKILL.md` describes under "Scout".

Fix confirmed failures from any of the three and rerun only the affected check. If a
fix changes behavior, rerun affected behavior QA. When all checks are green, run
`ORCA worktree set --worktree path:<worktree-path> --comment "Validation passed" --json`.

## Create the draft PR

Walk the full diff against the merge base file by file, including
untracked files: every hunk must belong to this task. Revert anything unrelated
(debug prints, formatting churn, leftovers, generated files that should not ship) and
report what was removed.

Then invoke the `create-pr` skill to perform the commit, upstream sync, push, draft PR
creation, and `/ci` comment. Pass context from the plan and review session:
- Issue key and close/address status from the plan file
- Short manual testing steps, written from the passing checks in `verify.json`, one
  per acceptance criterion. Leave out the checks, evidence paths, and verdict: they
  stay in the local result file.
- The demo file paths under `~/Code/ai-generated/<work-id>/demo/`, so `create-pr`
  attaches them in `## Demo`
- Risk: breaking changes, migrations, privilege changes, and the `Size` reason from
  the plan, when any apply

If `create-pr` halts due to merge conflicts against `upstream/main`, resolve them, rerun
affected checks or QA, and invoke `create-pr` again.

Set the card status:

```text
ORCA worktree set --worktree path:<worktree-path> --workspace-status in-review --comment "Draft PR created" --json
```

Report the PR URL, the review findings fixed, the findings left open and why, the
check results, the plan's `Follow-ups`, and any remaining considerations. Remind the user about private
issue linking when applicable.

When behavior QA ran, add the QA result to this report only, never to the PR. Give
the verdict, then a table with one row per criterion: its id, its text, its status,
and the path of its evidence file. Add the `setup` entries that a reviewer must know
about, the `notCovered` entries, and the path of `verify.json`. When QA was skipped,
say so and give the reason.

