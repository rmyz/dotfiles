# CI failures

## Read the failure

Find the failed Buildkite build from `gh pr checks <PR_NUMBER>` or from
kibanamachine's "Build Failed" comment. Then read only the failed jobs:

```bash
bk build view <build-number> -p kibana-pull-request -s failed,broken -o json
bk job log <job-id> --agent --format markdown --max-tokens 4000
```

`bk` needs a Buildkite token (`BUILDKITE_API_TOKEN` or `bk auth login`). If it is
not set up, ask the user and read the kibanamachine comment instead.

## Classify it

- **Caused by this branch**: the failing test or check covers code the PR touches.
  Fix the root cause. Fix every instance of the same mistake, not only the reported
  line. Rerun the affected local check (`node scripts/jest <file>`,
  `node scripts/type_check --project <tsconfig.json>`, or
  `node scripts/eslint <files>`) before you push.
- **Known flaky**: search for an open issue first:
  `gh issue list -R elastic/kibana --label failed-test --state open --search "<test title>"`.
  A match means the failure is not from this branch. Never skip or disable the test.
- **Unrelated, no issue**: the failure is outside the PR's area. Retry the job once
  with `bk job retry <job-id>`, only after user approval. If it fails again the same
  way, investigate instead of retrying.
- **Infrastructure** (timeouts, lost agents): report it and stop. Do not retry.
- **`docs-build`**: this check is separate from kibana-ci and fails at random. Rerun
  it with the PR comment `run docs-build`, only after user approval.

After a retry, wait only for statuses newer than the retry:
`pr.mjs wait <PR_NUMBER> --for ci --since "<utc-time-of-retry>"`.
