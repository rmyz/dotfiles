---
name: ship
description: End-to-end Kibana workflow taking one task from intake to a draft PR on elastic/kibana without approval stops, split into three phases (plan, implement, review) that each run in their own session. Runs on Orca worktrees and terminals by default, with a Worktrunk fallback. Invoke explicitly with an issue link, PR number, or task description.
disable-model-invocation: true
---

# Ship

Takes one Kibana task from investigation to a draft PR across three sessions:

`[PLAN] -> [IMPLEMENT] -> [REVIEW]`

Entry point: read and follow `~/.agents/skills/init-worktree/SKILL.md`, then read
`~/.agents/skills/ship-plan/SKILL.md` and continue in
this session. The later phases run in fresh sessions spawned by the previous phase.
This file holds the shared invariants and procedures; every phase skill applies them.

## Runtime

Orca is the default runtime. Before the first Orca command, load the `orca-cli`
skill, resolve the `ORCA` executable, run `ORCA skills get orca-cli`, and confirm the
app with `ORCA status --json`.

Choose the runtime once, at worktree creation, and keep it for the whole task:

- **Inside Orca**: Orca worktrees, Orca terminals for every process, terminal titles
  as server state, `ORCA terminal read` for logs.
- **Outside Orca** (fallback): Worktrunk worktrees, `wt config state vars` as server
  state, and `nohup` logs in `~/Code/ai-generated/files`. See
  `~/.agents/skills/ship/dev-stack.md` for the substitutions.

### Command tabs (inside Orca)

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

### Card status (inside Orca)

Update the Orca card at phase changes:

```text
ORCA worktree set --worktree path:<worktree-path> --workspace-status in-progress --json
ORCA worktree set --worktree path:<worktree-path> --comment "<one-line phase status>" --json
```

Set the comment at least after planning, after validation, and after the draft PR
exists. Set `--workspace-status in-review` when the draft PR is created.

## Invariants

The global rules already cover remotes, the 500-line PR limit, and skill locations;
they are not repeated here.

- Run one shared Elasticsearch instance on port `9200` from the primary `main`
  worktree. Never start Elasticsearch from a feature worktree.
- Run one Kibana instance per active worktree. Allocate the lowest free port starting
  at `5601`, then `5602`, `5603`, and so on.
- Run one Storybook instance per active worktree, only when the plan includes
  Storybook changes. Allocate the lowest free port starting at `9001`, then `9002`,
  `9003`, and so on.
- Ship ends after creating the draft PR, recording a visual demo when applicable,
  and reporting the outcome. Reviewer handoff and worktree teardown are separate
  skills: `handoff` and `teardown`.

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

The handoff payload between phases is exactly: branch, worktree path, plan file path.
Nothing else. A spawned session uses the checked-out branch as truth. Its first actions
are to set the worktree as the working directory, read the plan file, and run
`git status` plus `git diff upstream/main...`. There is no prior conversation to
recall.

### Spawning the next phase

`[PLAN]` spawns `[IMPLEMENT]` after writing the plan. `[IMPLEMENT]` spawns
`[REVIEW]` immediately when implementation and deviation notes are complete.

Always run `scripts/spawn-session.sh` from this session. Do not build the command
yourself and do not decide the runtime. The script detects the current agent
(OpenCode, Claude Code, pi, Codex, or Cursor) and starts it in a new Orca terminal in the
worktree:

```bash
"$HOME/.agents/skills/ship/scripts/spawn-session.sh" "<worktree-path>" "[<PHASE>] <branch>" \
  "[<PHASE>] <branch>: read ~/.agents/skills/ship-<phase>/SKILL.md and follow it. Worktree: <worktree-path>. Plan: <plan-file>."
```

Exit `0` means the terminal started: end this session. Exit `2` means this session
is not inside Orca: report the printed command to the user, then end this session.

When a phase needs servers, read `~/.agents/skills/ship/dev-stack.md` and follow it.
It is idempotent. `[PLAN]` never starts servers.
