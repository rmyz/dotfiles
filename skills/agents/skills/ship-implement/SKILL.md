---
name: ship-implement
description: Ship phase 2. In a fresh session, start the development stack, implement the approved plan, record deviations in the plan file, and spawn the review session without a human stop. Needs branch, worktree path, and plan file from the plan phase.
disable-model-invocation: true
---

# Ship: implement

Phase 2 of `ship`. The invariants and session rules in
`~/.agents/skills/ship/SKILL.md` apply; read that file first.

## First actions

The spawn payload (branch, worktree path, plan file) is the whole truth; there is no
prior conversation. In order:

1. Set the worktree path as the working directory; verify `git branch
   --show-current` matches the payload branch.
2. Read the plan file. It is the approved contract; do not re-investigate or expand
   its scope.
3. Run `git status` and `git diff upstream/main...` to see the current change state.
4. Confirm bootstrap completed: find the `bootstrap` terminal in `ORCA terminal list
   --worktree path:<worktree-path> --json`, then `ORCA terminal wait --for exit` and
   `ORCA terminal read`. Outside Orca, check `wt config state logs`. Wait for it
   before anything that needs built packages.
5. Run ship's "Ensure the development stack": Elasticsearch and Kibana always,
   Storybook only when the plan includes Storybook changes.

## Implement

Implement the approved plan without pausing between items. Stop only for a genuine
blocker.

Keep diagnostics clean as each file changes. Reuse existing helpers and patterns.
Do not expand scope or add speculative abstractions.

## Record deviations, then hand off

This step is mandatory; the review phase judges the diff against the plan, and an
unrecorded deviation turns its findings into noise.

Append a `Deviations` section to the plan HTML file before spawning review:

- Every material difference between the plan and the implementation: files added or
  dropped, approach changes, scope adjustments, and why.
- If the implementation matches the plan, state "No deviations."

Then spawn the `[REVIEW]` session following ship's "Spawning the next phase"
procedure, with payload branch, worktree path, and plan file path. There is no human
stop in this phase. End this session after spawning.
