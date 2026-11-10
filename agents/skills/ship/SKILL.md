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

Before the first Orca command, load the `orca-cli`
skill, resolve the `ORCA` executable, run `ORCA skills get orca-cli`, and confirm the
app with `ORCA status --json`.

Ship uses Orca worktrees and Orca terminals for every process. Terminal titles hold
server state. `ORCA terminal read` gives logs.

### Command tabs

Every process ship starts after worktree creation runs in its own visible Orca
terminal tab: bootstrap, Elasticsearch, Kibana, Storybook, generators, lint, type
checks, tests, `check.js`, and Scout. Use `ORCA terminal create --worktree <selector>
--title <short-title> --command "<exact-command>; exit \$?" --json` for finite
commands; the explicit exit lets `terminal wait --for exit` observe completion. Use
the exact server command without an exit for long-running servers. Do not use
terminal splits, background shell jobs, or reuse a prior command tab.

Wait for finite commands with `ORCA terminal wait --terminal <handle> --for exit
--timeout-ms <timeout> --json`, then read their output with `ORCA terminal read
--terminal <handle> --json`; use cursor reads for long output. Leave every tab open
after completion so the user can inspect and close it. Only close a tab automatically
when ship must restart a failed server or move the session off the old card.

### Card status

Update the Orca card at phase changes:

```text
ORCA worktree set --worktree path:<worktree-path> --workspace-status in-progress --json
ORCA worktree set --worktree path:<worktree-path> --comment "<one-line phase status>" --json
```

Set the comment at least after planning, after validation, and after the draft PR
exists. Set `--workspace-status in-review` when the draft PR is created.

## Invariants

- Run one shared Elasticsearch instance on port `9200` from the primary `main`
  worktree. Never start Elasticsearch from a feature worktree.
- Run one Kibana instance per active worktree. Allocate the lowest free port pair
  starting at `5601`, then `5603`, `5605`, and so on. Each instance uses its port and
  the next one.
- Run one Storybook instance per active worktree, only when the plan includes
  Storybook changes. Allocate the lowest free port starting at `9001`, then `9002`,
  `9003`, and so on.
- Ship ends after creating the draft PR, recording a visual demo when applicable,
  and reporting the outcome. Review requests and worktree teardown are separate
  skills: `request-reviews` and `teardown`.

## Flow

Planning, implementation, validation, and draft PR creation run without approval
stops. Stop only for a genuine blocker, such as unclear requirements, an unmet
acceptance criterion, a failing check that cannot be fixed, or a merge conflict
that cannot be resolved. Report review changes and remaining considerations with
the draft PR URL.

## Sessions

One session per phase, in the same agent that runs the current phase. The spawn
prompt's first characters are the phase tag and branch (`[IMPLEMENT] <branch>: ...`),
so the agent titles the session with them.

`[PLAN]` receives the prompt that `init-worktree` builds: worktree path, bootstrap
handle, and the original request. The handoff payload from `[PLAN]` to `[IMPLEMENT]`
and `[REVIEW]` is exactly: branch, worktree path, plan file path. Nothing else.

There is no prior conversation to recall.

### First actions

A spawned session uses the checked-out branch as truth. In order:

1. Run `pwd -P`. It must equal the worktree path in the payload; stop if it does not.
   Set `<branch>` to `git branch --show-current`. If it differs from the payload,
   report the payload value and keep using the actual branch.
2. Read the plan file (`[IMPLEMENT]` and `[REVIEW]` only).
3. Run `git status` and `git diff upstream/main...` to see the current change state
   (`[IMPLEMENT]` and `[REVIEW]` only).

### Confirm bootstrap

Before anything that needs built packages, find the `bootstrap` terminal in
`ORCA terminal list --worktree path:<worktree-path> --json`, block on
`ORCA terminal wait --terminal <handle> --for exit`, then `ORCA terminal read` to
check the exit status. If it failed or no `bootstrap` terminal exists, start
`kbnb; exit $?` in a new `bootstrap` terminal and wait for it the same way.

### Spawning the next phase

`[PLAN]` spawns `[IMPLEMENT]` after writing the plan. `[IMPLEMENT]` spawns
`[REVIEW]` immediately when implementation and deviation notes are complete.

Always run `scripts/spawn-session.sh` from this session. Do not build the command
yourself and do not decide the runtime. The script detects the current agent
(OpenCode, Claude Code, pi, Codex, or Cursor) and starts it in a new Orca terminal in the
worktree:

```bash
"$HOME/.agents/skills/spawn-session/scripts/spawn-session.sh" "<worktree-path>" "[<PHASE>] <branch>" \
  "[<PHASE>] <branch>: read ~/.agents/skills/ship-<phase>/SKILL.md and follow it. Worktree: <worktree-path>. Plan: <plan-file>."
```

Exit `0` means the terminal started: end this session. The script works from an
Orca terminal and from Orca chat. Exit `2` means this session runs outside Orca:
report the printed command to the user, then end this session.

When a phase needs servers, read `~/.agents/skills/kibana-dev-stack/SKILL.md` and follow it.
It is idempotent. `[PLAN]` never starts servers.
