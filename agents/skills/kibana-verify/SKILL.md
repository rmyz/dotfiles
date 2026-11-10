---
name: kibana-verify
description: Prove that a Kibana change works in the running app, with per-area recipes for reaching, checking, and driving each feature. Use when planning verification, running behavior QA, or checking that a UI or API change works.
---

# Kibana verify

A check proves a change only when it drives the real app and records what the app
did. This skill keeps one recipe per Kibana area in `features/`, so each QA run
starts from what the last run learned instead of rediscovering it.

## Launch

Read and follow `~/.agents/skills/kibana-dev-stack/SKILL.md`. It is idempotent and gives the
Kibana URL with its base path. Credentials are `elastic`/`changeme`.

Before the first drive, and after any failed drive, run the doctor. Kibana must
answer `available`:

```bash
curl -fsS -u elastic:changeme "<kibana-url>/api/status" | jq -r .status.overall.level
```

When the doctor fails, the stack is the problem, not the change. Fix the stack
before you judge the feature.

## Drive

1. Find the feature file for the area in `features/`. Read it fully.
2. Create the data it lists. Use `kibana-synthetic-data-generation` for
   observability data.
3. Follow its steps with `agent-browser` for UI or `curl` for API. Use its
   `data-test-subj` selectors.
4. Record evidence for each check: a screenshot under `~/Code/ai-generated/<work-id>/demo/`
   or the quoted response body. A check without evidence did not pass.

Never weaken a step or an expected result to make a check pass. When the app does
not do what the file says, decide which one is wrong:

- **The file is out of date**: the code changed on `upstream/main`. Update the file.
- **The app regressed**: the change broke it. Report the failure.

## Feature files

One file per area: `features/<area>.md`. Use these headings:

```markdown
# <Area>

Status: draft | verified <date>

## Reach
App path after the base path, required role, and required license.

## Data
The data the area needs and the exact command or request that creates it.

## Doctor
One read-only check that the area works before you test the change: a request and
its expected response, or a selector that must be visible.

## Drive
Numbered steps. Each step names the `data-test-subj` selector or request and the
expected result.

## Gotchas
Traps a previous run hit, each with its fix.
```

A file stays `draft` until a run drives every step end to end. Then set
`verified <date>`.

## After the run

- No file existed for the area: write one from the steps that worked.
- A step failed for a reason outside the change, such as a slow load, a missing
  role, or missing data: add it to `Gotchas`.
- Report every changed feature file, because it lives in the dotfiles repo.
