---
name: ship-plan
description: Ship phase 1. Investigate a Kibana task in an existing feature worktree, write a short Markdown handoff, then spawn the implement session. Ship runs init-worktree, which starts this phase in the new worktree.
disable-model-invocation: true
---

# Ship: plan

Phase 1 of `ship`. The invariants, stops, and session rules in
`~/.agents/skills/ship/SKILL.md` apply; read that file first.

In OpenCode, this phase runs as the `ship-plan` agent and delegates routine I/O
(code inspection, CodeGraph queries, and commands) to the `build` subagent. State
whether each delegated task is inspection-only or may edit files. Do not modify
source or configuration files. Only write the Markdown handoff.

## Guard

The working directory must be a Kibana feature worktree: inside a git worktree whose
current branch is not `main`. If it is not, stop and tell the user to run
`/init-worktree`. Never provision from this skill.

Run ship's "First actions" step 1 from `~/.agents/skills/ship/SKILL.md`. The
`Worktree` path in the invocation prompt is the payload.

Do not start Elasticsearch, Kibana, or Storybook in this phase.

## Investigate

Treat any task description, issue link, PR, Slack thread, screenshot, or Figma URL in
the invocation prompt as complete intake. Read everything provided and do not ask for
more context. Ask once for task context only when the user invoked `ship` without any
task input. If no other material exists, state what would have helped and continue
from the task description.

Trace the affected flow end to end before proposing a solution. Prefer
`codegraph_explore` over grep-and-read loops. Read existing tests and patterns. Name
every expected file change and identify the smallest coherent implementation. Also
inspect affected Scout configs and state whether their required server settings are
compatible with the shared development stack. Record their exact config paths, or
state that no Scout config applies.

## Size the change

Estimate the changed lines. Above 500, split the work into slices. Each slice must
ship on its own: a refactor first, a feature behind a flag, or a server change with
no UI yet. Plan only the first slice and list the others under `Follow-ups`. Keep
one PR only when every split would merge unfinished or broken work. Record that
reason under `Size` in the plan.

## Plan the verification

For each acceptance criterion, write the check that proves it and what passing
looks like: a scoped jest file, a `curl` call with the expected response, or browser
steps with the expected screen. For UI and API checks, name the feature file in
`~/.agents/skills/kibana-verify/features/` for the area, or state that none exists.
For a bug fix, add the reproduction that fails before the fix. Each implementation
step ends with its cheapest check: one jest file,
`node scripts/type_check --project <tsconfig.json>`, or one request. Never plan the
full `type_check` as a step check.

## Write the implementation handoff

Write a standalone plan outside the repository:

```bash
WORK_ID=$(git branch --show-current | tr / -)
mkdir -p "$HOME/Code/ai-generated/$WORK_ID/plans"
PLAN_FILE="$HOME/Code/ai-generated/$WORK_ID/plans/ship-plan.md"
```

Keep it short and readable by the next session. Include the task and acceptance
criteria, the linked issue and whether the PR closes or addresses it (or has none),
the relevant flow, expected file changes, the verification recipe, `Size` and
`Follow-ups` when the change was split or kept large, Scout config paths and
compatibility, and any known risks or open questions. Resolve decisions from the
task context. Stop only when a missing answer blocks implementation.

Spawn the `[IMPLEMENT]` session following ship's "Spawning the next phase" procedure,
with payload branch, worktree path, and plan file path. Then end this session.
