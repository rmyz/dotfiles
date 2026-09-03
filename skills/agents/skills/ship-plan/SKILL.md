---
name: ship-plan
description: Ship phase 1. Investigate a Kibana task in an existing feature worktree, produce the HTML plan, stop for plan approval, then spawn the implement session. Requires init-worktree to have run first.
disable-model-invocation: true
---

# Ship: plan

Phase 1 of `ship`. The invariants, stops, and session rules in
`~/.agents/skills/ship/SKILL.md` apply; read that file first.

## Guard

The working directory must be a Kibana feature worktree: inside a git worktree whose
current branch is not `main`. If it is not, stop and tell the user to run
`/init-worktree`. Never provision from this skill.

Do not start Elasticsearch, Kibana, or Storybook in this phase. Do not edit source
files during investigation or planning.

## Investigate

Ask once for any available GitHub issues, related PRs, Slack threads, screenshots, or
Figma URLs. Read everything provided. If nothing exists, state what would have helped
and continue from the task description.

Trace the affected flow end to end before proposing a solution. Prefer
`codegraph_explore` over grep-and-read loops. Read existing tests and patterns. Name
every expected file change and identify the smallest coherent implementation.

Before plan approval, resolve whether the PR will close an issue, address an issue
without closing it, or have no issue. Also inspect affected Scout configs and state
whether their required server settings are compatible with the shared development
stack.

## Create the HTML plan, then stop

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
- The linked issue and whether the PR closes it, addresses it, or has none
- Proposed behavior, scope, and explicit non-goals
- Architecture or request/data flow when relevant
- Every file to change and the exact change per file
- Verification per change, including targeted tests and Scout when applicable
- Risks, assumptions, open questions, and rollback considerations
- Estimated changed-line count and whether the work should be split before 500 lines

Open the plan with `open "$PLAN_FILE"`. If that fails, provide the absolute path.

**PLAN APPROVAL: HARD STOP.** Present the plan path and a one-sentence summary, then
end the response. Wait for explicit approval.

## After approval

Spawn the `[IMPLEMENT]` session following ship's "Spawning the next phase" procedure,
with payload branch, worktree path, and plan file path. Then end; this session is
done.
