---
name: kibana-verify
description: Prove that a Kibana change works in the running app, with per-area recipes for reaching, checking, and driving each feature. Use when planning verification, running behavior QA, or checking that a UI or API change works.
---

# Kibana verify

A check proves a change only when it drives the real app and records what the app
did. This skill keeps one recipe per Kibana area in `features/`, so each QA run
starts from what the last run learned instead of rediscovering it.

## Launch

Read and follow `~/.agents/skills/kibana-dev-stack/SKILL.md`. It gives the Kibana URL
with its base path. Credentials are `elastic`/`changeme`. Internal APIs need
`kbn-xsrf: x` and `x-elastic-internal-origin: kibana`, plus `elastic-api-version: 1`
where the feature file says so.

Before the first drive, and after any failed drive, run the doctor. Kibana must
answer `available`:

```bash
curl -fsS -u elastic:changeme "<kibana-url>/api/status" | jq -r .status.overall.level
```

When the doctor fails, the stack is the problem, not the change. Fix the stack
before you judge the feature.

## Acceptance criteria

The caller gives the numbered acceptance criteria (`AC1`, `AC2`, ...) and the plan
file that lists them under `## Acceptance criteria`. Standalone, write the criteria
to `~/Code/ai-generated/<work-id>/plans/verify-plan.md` under that heading, one list
item per criterion, and use it as the plan file. Verification succeeds only when
every criterion has a passing check. Before you drive anything, note for each
criterion the check that proves it, the expected result, and what you will not
cover. Never drop, merge, or reword a criterion. A criterion you cannot reach is
`blocked`, never skipped.

## Drive

1. Find the feature file in `features/` that matches the area of the changed files.
   Read it fully. When none matches, create one (see "After the run").
2. Turn the feature on. When the changed code sits behind a disabled plugin, a
   feature flag, an advanced setting, or a license, enable it in
   `config/kibana.dev.yml` or through the API. Dev Kibana reloads itself on a config
   change: wait until `/api/status` answers `available`. That is expected work, not a
   reason to stop.
3. Create the data it lists. Use `kibana-synthetic-data-generation` for APM, logs, or
   infra data. Search the changed plugin's directory with `rg -il seed` for an
   existing seed script before you hand-make documents. Do not delete data you did
   not create.
4. Follow its steps with `agent-browser` for UI or `curl` for API. Use its
   `data-test-subj` selectors. Pass `-m 30` to every `curl`.
   Before every screenshot or recording, run `agent-browser set viewport 1920 1080`
   and confirm it with `agent-browser eval "[innerWidth, innerHeight]"`. The
   viewport can change between uses, so set it again after every new session, tab,
   or page reload, and before every `record start`.
5. Record evidence for each check, as described under "Result".

Rules for checks:

- A check must go through the running app: its UI, its HTTP APIs, the Elasticsearch
  state it produced, or its own log lines. Running unit tests or calling the
  changed module directly does not prove behavior in the app. Use it only for a
  criterion the app cannot show, and tag it `test`.
- `agent-browser click` often does nothing on EUI popovers, tabs, table headers,
  cards, and combo boxes. Use `agent-browser eval` with `el.click()` on the element
  found by aria-label or text. For Enter in a combo box, dispatch
  `new KeyboardEvent('keydown',{key:'Enter',keyCode:13,bubbles:true})`.
- For backend changes with no visible surface, run `git diff --name-only` and note
  the files. Add temporary log lines with a unique prefix, wait for the dev server to
  reload, run the scenario, and read the `kibana:<port>` terminal with
  `ORCA terminal read`. Then revert every file the diff list gained with
  `git checkout -- <file>`.
- For agent or prompt changes, run the real flow once to completion. A seeded or
  mocked conversation does not prove agent behavior.
- The change under test must not edit the rules that judge it: the feature file's
  steps and expected results, the plan's criteria, and `validate-verify.mjs`. Read
  them from the dotfiles repo. Fix a stale feature file only under "After the run",
  never to turn a failing check green.
- Retry a failing check at most three times, fixing a cause between rounds. When it
  still fails, stop and report it as `fail`, or as `blocked` for a stack problem.
- Never skip a flaky check, add sleeps, or retry until it passes. Find the root
  cause. When you cannot, record the check as `blocked` and say why in `details`.
- Never weaken a step or an expected result to make a check pass. When the app does
  not do what the file says, decide which one is wrong:

  - **The file is out of date**: the code changed on `upstream/main`. Update the file.
  - **The app regressed**: the change broke it. Report the failure.

## Result

Write `~/Code/ai-generated/<work-id>/demo/verify.json`. Put every screenshot and
recording in the same directory and name them in order (`01-...png`).

```json
{
  "verdict": "pass | fail | partial | blocked",
  "summary": "Two to five sentences: does the change work, and the key evidence.",
  "setup": ["What you changed to test: config lines, flags, seeded data, restarts."],
  "criteria": [
    { "id": "AC1", "text": "the criterion, as written in the plan", "status": "pass | fail | blocked", "checks": ["C1", "C2"] }
  ],
  "checks": [
    {
      "id": "C1",
      "title": "what the check does",
      "status": "pass | fail | blocked",
      "via": "ui | api | es | log | test",
      "details": "What you did and what you saw. On failure: expected and actual.",
      "response": "Quoted response body, command output, or log lines.",
      "files": [{ "file": "01-name.png", "caption": "What it shows and what to look at" }]
    }
  ],
  "notCovered": ["What matters but this run did not check."],
  "reviewerNote": "Required unless verdict is pass. What a person must look at, and why."
}
```

- Each criterion lists the checks that prove it. A `pass` criterion needs at least
  one check, and all its checks must pass.
- A `pass` or `fail` check needs evidence: a quoted `response`, or `files` with
  captions. A `ui` check needs a screenshot or a recording. Use a recording
  (`qa.webm`) for a flow with several steps or state changes, and a screenshot for a
  static result.
- Open every evidence file yourself before you mark a check `pass`. Check that it
  shows the right page, fully loaded, with nothing covering the relevant part.
- List every config change, flag, and seed you needed under `setup`. A criterion
  that passes only with a non-default setting is a finding the reviewer must see.
- When you cannot tell a change problem from an environment problem, say so in
  `details`.
- A stack failure is `blocked`, not `fail`. A feature failure is `fail`.
- For every verdict except `pass`, fill `reviewerNote`: what a person must look at
  and why, so the reviewer does not rebuild it from the diff.

Validate the file. Pass the plan so the criteria count is checked against it:

```bash
node ~/.agents/skills/kibana-verify/scripts/validate-verify.mjs \
  ~/Code/ai-generated/<work-id>/demo/verify.json --plan <plan-file>
```

Fix every printed error and rerun until it prints `OK`. Return the path of
`verify.json` to the caller.

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
