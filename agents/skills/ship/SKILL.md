---
name: ship
description: End-to-end Kibana workflow taking one task from intake to a draft PR on elastic/kibana without approval stops, split into three phases (plan, implement, review) that each run in their own session. Runs on Orca worktrees and terminals. Invoke explicitly with an issue link, PR number, or task description.
disable-model-invocation: true
---

# Ship

Takes one Kibana task from investigation to a draft PR across three sessions:

`[PLAN] -> [IMPLEMENT] -> [REVIEW]`

Entry point: read and follow `~/.agents/skills/init-worktree/SKILL.md`. Pass it the
tag `[PLAN]` and the instruction `read ~/.agents/skills/ship-plan/SKILL.md and follow
it`. It provisions the worktree and starts the `[PLAN]` session there, so this
session ends.

The later phases run in fresh sessions spawned by the previous phase. This file holds
the shared invariants and procedures; every phase skill applies them.

## Runtime

Before the first Orca command, load the `orca-cli` skill, complete its setup, and
confirm the app with `ORCA status --json`.

Ship uses Orca worktrees and Orca terminals for every process. Terminal titles hold
server state. `ORCA terminal read` gives logs.

### Command tabs

Every process ship starts after worktree creation runs in its own visible Orca
terminal tab: bootstrap, Elasticsearch, Kibana, Storybook, generators, lint, type
checks, tests, `check.js`, and Scout. Use `ORCA terminal create --worktree <selector>
--title <short-title> --command "<exact-command>; exit \$?" --json` for finite
commands; the explicit exit lets `terminal wait --for exit` observe completion. Use
the exact server command without an exit for long-running servers. Do not run these
processes as background shell jobs, and do not reuse a prior command tab.

Wait for finite commands with `ORCA terminal wait --terminal <handle> --for exit
--timeout-ms <timeout> --json`, then read their output with `ORCA terminal read
--terminal <handle> --json`; use cursor reads for long output. Leave every tab open
after completion so the user can inspect and close it. Only close a tab automatically
when ship must restart a failed server or move the session off the old card.

### Card status

Each phase skill sets the Orca card status and a one-line comment with
`ORCA worktree set --worktree path:<worktree-path> --workspace-status <id> --comment "<text>" --json`.

## Invariants

- Servers follow `~/.agents/skills/kibana-dev-stack/SKILL.md`: one Elasticsearch,
  one Kibana, and when needed one Storybook per active worktree, and none from the
  primary `main` worktree.
- Ship ends after creating the draft PR, attaching the QA demo to the PR, and
  reporting the outcome.

## Flow

Planning, implementation, validation, and draft PR creation run without approval
stops. Stop only for a genuine blocker, such as unclear requirements, an unmet
acceptance criterion, a failing check that cannot be fixed, or a merge conflict
that cannot be resolved. Report review changes and remaining considerations with
the draft PR URL.

## Sessions

One session per phase, in the same agent that runs the current phase. The spawn
prompt's first characters are the phase tag and branch (`[IMPLEMENT] <branch>: ...`).

`[PLAN]` receives the prompt that `init-worktree` builds: worktree path, bootstrap
handle, and the original request. The handoff payload from `[PLAN]` to `[IMPLEMENT]`
and `[REVIEW]` is exactly: branch, worktree path, plan file path. Nothing else.

### First actions

A spawned session uses the checked-out branch as truth. In order:

1. Run `pwd -P`. It must equal the worktree path in the payload; stop if it does not.
   Set `<branch>` to `git branch --show-current`. If it differs from the payload,
   report the payload value and keep using the actual branch.
2. Read the plan file (`[IMPLEMENT]` and `[REVIEW]` only).
3. Run `git status` and `git diff upstream/main...` to see the current change state
   (`[IMPLEMENT]` and `[REVIEW]` only).

### Confirm bootstrap

Before anything that needs built packages, confirm bootstrap as
`~/.agents/skills/init-worktree/SKILL.md` describes under "Bootstrap".

### Spawning the next phase

`[PLAN]` spawns `[IMPLEMENT]` after writing the plan. `[IMPLEMENT]` spawns
`[REVIEW]` immediately when implementation and deviation notes are complete.

Run `spawn-session.sh` from this session:

```bash
"$HOME/.agents/skills/spawn-session/scripts/spawn-session.sh" "<worktree-path>" "[<PHASE>] <branch>" \
  "[<PHASE>] <branch>: read ~/.agents/skills/ship-<phase>/SKILL.md and follow it. Worktree: <worktree-path>. Plan: <plan-file>."
```

On exit `0` or `2`, end this session as `~/.agents/skills/spawn-session/SKILL.md`
describes. On exit `0`, close this terminal's whole tab last, because it kills the
agent and nothing runs after it. Skip the close when `ORCA_TERMINAL_HANDLE` is unset.

```bash
ORCA terminal close --terminal "$ORCA_TERMINAL_HANDLE" --tab --json
```

When a phase needs servers, read `~/.agents/skills/kibana-dev-stack/SKILL.md` and follow it.
`[PLAN]` never starts servers.
