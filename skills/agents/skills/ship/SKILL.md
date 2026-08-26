---
name: ship
description: End-to-end Kibana workflow taking one task from intake to a draft PR on elastic/kibana. Invoke explicitly with an issue link, PR number, or task description.
disable-model-invocation: true
---

# Ship

Takes one Kibana task from investigation to a draft PR. The flow is:

`Investigate -> Plan -> Implement -> Validate -> Draft PR`

The user validates the plan and the completed work.

## Invariants

- `origin` is the fork (`rmyz/kibana`); `upstream` is `elastic/kibana`.
- Diff, branch, and rebase against `upstream/main`. Never use `origin/main`.
- Skills live in `~/.agents/skills/`. Ignore `~/.claude` and `~/.cursor`.
- Run one shared Elasticsearch instance on port `9200` from the primary `main`
  worktree. Never start Elasticsearch from a feature worktree.
- Run one Kibana instance per active worktree. Allocate the lowest free port starting
  at `5601`, then `5602`, `5603`, and so on.
- Run one Storybook instance per active worktree, only when the approved plan includes
  Storybook changes. Allocate the lowest free port starting at `9001`, then `9002`,
  `9003`, and so on.
- Keep the draft PR below 500 changed lines when the work can be split coherently.
- Ship ends at a created draft PR. Reviewer handoff and worktree teardown are separate
  skills: `handoff` and `teardown`.

## Human stops

| Stop       | Placed after               | Waits for                                |
| ---------- | -------------------------- | ---------------------------------------- |
| Gate 1     | Styled HTML plan           | Explicit approval to implement           |
| Validation | All checks and review-team | Explicit approval to create the draft PR |

At either stop, present the result and end the response. Do not create todos, inspect
more files, or start the next phase. Absence of objection is not approval.

## Step 1: Create the worktree

```bash
git fetch upstream main
wt switch --create <branch> --base upstream/main
```

Branch naming: `fix/`, `feat/`, `perf/`, or `refactor/` plus a short description.
Capture the new worktree path from Worktrunk's output. Use it as the tool working
directory for every following command. At the start of every resumed phase, restore
that working directory and recompute shell variables; shell state does not survive a
human stop.

`wt` starts `yarn kbn bootstrap` in the background. Investigation and planning may
continue while it runs. Before starting Kibana, type checks, or tests, confirm the
bootstrap hook completed successfully through `wt config state logs`.

The Worktrunk hook copies the ignored development config. Verify it instead of
assuming the hook succeeded:

```bash
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
test -f "$MAIN/config/kibana.dev.yml"
cmp -s "$MAIN/config/kibana.dev.yml" config/kibana.dev.yml || \
  cp "$MAIN/config/kibana.dev.yml" config/kibana.dev.yml
cmp -s "$MAIN/config/kibana.dev.yml" config/kibana.dev.yml
```

Treat a failed final comparison as a blocker.

## Step 2: Investigate

Ask once for any available GitHub issues, related PRs, Slack threads, screenshots, or
Figma URLs. Read everything provided. If nothing exists, state what would have helped
and continue from the task description.

Trace the affected flow end to end before proposing a solution. Prefer
`codegraph_explore` over grep-and-read loops. Read existing tests and patterns. Name
every expected file change and identify the smallest coherent implementation.

Before Gate 1, resolve whether the PR will close an issue, address an issue without
closing it, or have no issue. Also inspect affected Scout configs and state whether
their required server settings are compatible with the shared development stack.

Do not edit source files during investigation or planning.

## Step 3: Create the HTML plan, then stop

Write a standalone plan outside the repository:

```bash
BRANCH=$(git branch --show-current)
PLAN_FILE="/tmp/ship-plan-${BRANCH//\//-}.html"
```

The HTML must be polished, responsive, and self-contained. Use inline CSS, system
fonts, clear cards, restrained color, status badges, and light/dark color schemes. Do
not load external scripts, fonts, or styles.

Include:

- Task summary and current behavior
- Proposed behavior, scope, and explicit non-goals
- Architecture or request/data flow when relevant
- Every file to change and the exact change per file
- Verification per change, including targeted tests and Scout when applicable
- Risks, assumptions, open questions, and rollback considerations
- Estimated changed-line count and whether the work should be split before 500 lines

Open the plan with `open "$PLAN_FILE"`. If that fails, provide the absolute path.

**GATE 1: HARD STOP.** Present the plan path and a one-sentence summary, then end the
response. Wait for explicit approval.

## Step 4: Start the shared development stack

This is the first action after Gate 1 approval. The stack must be healthy before
implementation starts.

Restore the feature worktree as the command working directory, then recompute state:

```bash
BRANCH=$(git branch --show-current)
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
```

### Elasticsearch

Assume Elasticsearch is already running. Check for a listener on `9200`, then verify
its response includes the `X-Elastic-Product: Elasticsearch` header. A `401` still
counts as a running Elasticsearch instance. If another service owns `9200`, stop
instead of starting another process on the same port.

For an existing Elasticsearch listener, inspect its PID and current working directory
with `lsof`. It must run from `$MAIN` or `$MAIN/.es`; otherwise stop and report the
unexpected process instead of treating it as the shared instance.

```bash
curl -sS -D - -o /dev/null http://127.0.0.1:9200 | \
  grep -qi '^x-elastic-product: Elasticsearch'
```

Only when port `9200` has no listener, run this with `$MAIN` as the command working
directory:

```bash
nohup wt step tether -C "$MAIN" -- fnm exec --using=.nvmrc \
  yarn es snapshot --use-cached \
  > /tmp/kibana-shared-es.log 2>&1 &
echo $! > /tmp/kibana-shared-es.pid
```

Poll port `9200` until the Elasticsearch product header appears. On timeout, inspect
`/tmp/kibana-shared-es.log`, terminate the recorded process tree, remove the stale PID
file, and stop. Never start a second development Elasticsearch instance for another
worktree.

### Kibana

Reuse the branch's stored `kibana-port` only when it serves Kibana and the listener's
current working directory is inside this worktree. Otherwise, acquire an atomic
`mkdir` lock at `/tmp/kibana-port-allocation.lock`, allocate the lowest unused port
starting at `5601`, and start immediately. Store the lock owner's PID, recover a stale
lock only when that PID no longer exists, and hold the lock until Kibana is ready.

```bash
WORKTREE=$(pwd -P)
PORT=$(wt config state vars get kibana-port 2>/dev/null || true)
KIBANA_RUNNING=false
KIBANA_OWNED=false
if [ -n "$PORT" ]; then
  LISTENER_PID=$(lsof -tiTCP:"$PORT" -sTCP:LISTEN | command sed -n '1p')
  LISTENER_CWD=$(lsof -a -p "$LISTENER_PID" -d cwd -Fn 2>/dev/null | \
    command sed -n 's/^n//p')
  case "$LISTENER_CWD" in
    "$WORKTREE"|"$WORKTREE"/*)
      KIBANA_OWNED=true
      for _ in {1..60}; do
        if curl -fsS -u elastic:changeme \
          "http://127.0.0.1:$PORT/api/status" >/dev/null 2>&1; then
          KIBANA_RUNNING=true
          break
        fi
        sleep 2
      done
      ;;
  esac
fi
if [ "$KIBANA_OWNED" = true ] && [ "$KIBANA_RUNNING" = false ]; then
  OLD_KIBANA_PID=$(wt config state vars get kibana-pid 2>/dev/null || true)
  kill "$OLD_KIBANA_PID" 2>/dev/null || true
  wt config state vars clear kibana-port
  wt config state vars clear kibana-pid
  wt config state vars clear kibana-log
  for _ in {1..30}; do
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1 || break
    sleep 1
  done
fi
if [ "$KIBANA_RUNNING" = false ]; then
  LOCK=/tmp/kibana-port-allocation.lock
  while ! mkdir "$LOCK" 2>/dev/null; do
    if [ -f "$LOCK/pid" ]; then
      read -r LOCK_PID < "$LOCK/pid"
      if ! kill -0 "$LOCK_PID" 2>/dev/null; then
        rm -f "$LOCK/pid"
        rmdir "$LOCK" 2>/dev/null || true
        continue
      fi
    fi
    sleep 1
  done
  printf '%s\n' "$$" > "$LOCK/pid"
  release_port_lock() {
    rm -f "$LOCK/pid"
    rmdir "$LOCK" 2>/dev/null || true
  }
  trap release_port_lock EXIT INT TERM
  PORT=5601
  while lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
    PORT=$((PORT + 1))
  done
  BRANCH_SAFE=${BRANCH//\//-}
  KIBANA_LOG="/tmp/kibana-${BRANCH_SAFE}-${PORT}.log"
  nohup wt step tether -- fnm exec --using=.nvmrc yarn start \
    --port "$PORT" --no-base-path > "$KIBANA_LOG" 2>&1 &
  KIBANA_PID=$!
  wt config state vars set kibana-port="$PORT"
  wt config state vars set kibana-pid="$KIBANA_PID"
  wt config state vars set kibana-log="$KIBANA_LOG"
  KIBANA_READY=false
  for _ in {1..180}; do
    if curl -fsS -u elastic:changeme \
      "http://127.0.0.1:$PORT/api/status" >/dev/null 2>&1; then
      KIBANA_READY=true
      break
    fi
    sleep 2
  done
  if [ "$KIBANA_READY" = false ]; then
    kill "$KIBANA_PID" 2>/dev/null || true
    wt config state vars clear kibana-port
    wt config state vars clear kibana-pid
    wt config state vars clear kibana-log
    exit 1
  fi
  release_port_lock
  trap - EXIT INT TERM
fi
```

On startup failure, inspect the stored log before retrying once. The trap releases the
allocation lock on failure. Report the healthy URL, then continue directly to
implementation.

### Storybook

Skip this section unless the approved plan includes Storybook file changes. Resolve
the correct alias first: read `src/dev/storybook/aliases.ts` and match each changed
file path against the alias target directories, keeping the deepest match. If no
alias matches, stop and ask which alias to use instead of guessing.

Reuse the branch's stored `storybook-port` only when it serves Storybook and the
listener's current working directory is inside this worktree. Otherwise, take the
same atomic `mkdir` lock at `/tmp/kibana-port-allocation.lock`, allocate the lowest
unused port starting at `9001`, and start Storybook:

```bash
nohup yarn storybook "<alias>" > "$STORYBOOK_LOG" 2>&1 &
```

`scripts/storybook` hardcodes port `9001` and has no `--port` flag. When the
allocated port is not `9001`, set it by passing Storybook's own flag through a direct
invocation of the resolved config directory instead of the wrapper:

```bash
nohup fnm exec --using=.nvmrc yarn \
  storybook dev --config-dir "<alias-target-dir>" -p "$PORT" \
  > "$STORYBOOK_LOG" 2>&1 &
```

Store `storybook-port`, `storybook-pid`, and `storybook-log` in Worktrunk state the
same way as Kibana. Poll the port until it answers HTTP 200; on timeout inspect the
log, kill the stored PID, clear the variables, and stop. Release the lock once ready.

## Step 5: Implement

Implement the approved plan without pausing between items. Stop only for a genuine
blocker or a material deviation from the approved plan.

Keep diagnostics clean as each file changes. Reuse existing helpers and patterns.
Do not expand scope or add speculative abstractions.

## Step 6: Validate, then stop

Run validation as one phase with no intermediate human gate. Fix confirmed failures
and rerun the affected checks until green.

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
    "kibana": "http://127.0.0.1:<kibana-port>",
    "elasticsearch": "http://127.0.0.1:9200"
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
development stack does not provide, validation is blocked. Do not start a second
Elasticsearch instance or proceed to a PR. Resolve the profile conflict or get an
explicit change to the single-Elasticsearch requirement.

### Acceptance criteria

Before review-team, list every acceptance criterion from the issue or task
description. Verify each one against the implementation, using the running stack when
the criterion needs manual or UI confirmation. A criterion is done only when you can
point at the code and the observed behavior that fulfills it. If any criterion fails
or cannot be verified, fix it before continuing; do not hand unmet criteria to
review-team.

### Review team

Load `review-team` in **local review mode** after tests and mechanical checks. It must
review committed, staged, unstaged, and untracked changes against `upstream/main`.

Never apply the outcome automatically. Present every finding with severity, file, and
a one-line suggested fix, plus a proposed action plan ordering what to fix. Let the
user choose which findings matter; apply only their selection. After applying fixes,
rerun affected tests plus `node scripts/check.js --scope=local`.

### PR size

Measure total additions and deletions against the merge base, including untracked
files. If the result exceeds 500 changed lines, document whether it can be split into
smaller coherent PRs. Split it when possible; keep it together only when separation
would harm correctness or reviewability.

**VALIDATION STOP.** Present:

- Changed files and a brief description of each
- Test, mechanical check, and Scout results
- Review-team findings, fixes, and any intentionally deferred items
- Changed-line count and split assessment
- Running Kibana URL
- Any remaining risks or blockers

End the response and wait for explicit approval to create the draft PR.

## Step 7: Create the draft PR

After approval, load `create-pr` for commit and PR metadata, but use the ordering below
instead of its default push step. Use the issue and close/address decision resolved
before Gate 1 so this phase introduces no new human stop. Inspect status, diff, and
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

Labels come from `team-config`. The PR opens as a draft and stays a draft. The `/ci`
comment triggers CI after creation. Ship ends here.

Afterwards, run `handoff` when the user wants the per-team review-request messages,
and `teardown` once the PR merges or the worktree is abandoned.
