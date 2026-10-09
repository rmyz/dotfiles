---
name: ship-implement
description: Ship phase 2. In a fresh session, implement the Markdown plan, record deviations, and spawn the review session. Needs branch, worktree path, and plan file from the plan phase.
disable-model-invocation: true
---

# Ship: implement

Phase 2 of `ship`. The invariants and session rules in
`~/.agents/skills/ship/SKILL.md` apply; read that file first.

## First actions

The spawn payload gives the worktree path and plan file; there is no prior
conversation. Use the checked-out branch as truth. In order:

1. Set the worktree path as the working directory. Set `<branch>` to
   `git branch --show-current`. If it differs from the payload, report the payload
   value and keep using the actual branch.
2. Read the plan file. It is the implementation handoff; do not re-investigate or
   expand its scope.
3. Run `git status` and `git diff upstream/main...` to see the current change state.
4. Confirm bootstrap completed: find the `bootstrap` terminal in `ORCA terminal list
   --worktree path:<worktree-path> --json`, then `ORCA terminal wait --for exit` and
   `ORCA terminal read`. Wait for it
   before anything that needs built packages.
5. Use ship-review's step 4 rule to decide whether implementation needs Kibana.

## Implement

Implement the plan without pausing between items. Stop only for a genuine
blocker.

Keep diagnostics clean as each file changes. Reuse existing helpers and patterns.
Do not expand scope or add speculative abstractions.

## Record deviations, then hand off

This step is mandatory; the review phase judges the diff against the plan, and an
unrecorded deviation turns its findings into noise.

Append a `Deviations` section to the Markdown plan before spawning review:

- Every material difference between the plan and the implementation: files added or
  dropped, approach changes, scope adjustments, and why.
- If the implementation matches the plan, state "No deviations."

Then spawn the `[REVIEW]` session following ship's "Spawning the next phase"
procedure, with payload branch, worktree path, and plan file path. There is no human
stop in this phase. End this session after spawning.
