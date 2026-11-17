---
name: ship-implement
description: Ship phase 2. In a fresh session, implement the Markdown plan, record deviations, and spawn the review session. Needs branch, worktree path, and plan file from the plan phase.
disable-model-invocation: true
---

# Ship: implement

Phase 2 of `ship`. The invariants and session rules in
`~/.agents/skills/ship/SKILL.md` apply; read that file first.

## First actions

Run ship's "First actions" and "Confirm bootstrap" from
`~/.agents/skills/ship/SKILL.md`. The plan file is the implementation handoff; do not
re-investigate or expand its scope.

## Implement

Implement the plan without pausing between items.

For a bug fix, run the plan's reproduction first and confirm that it fails. A fix
without a failing reproduction is a guess.

End each step with its check from the plan. Start servers through
`~/.agents/skills/kibana-dev-stack/SKILL.md` when a check needs them. Start the next
step only when the check passes. A check that fails and cannot be fixed is a
blocker. Reuse existing helpers and patterns.

## Record deviations, then hand off

This step is mandatory; the review phase judges the diff against the plan, and an
unrecorded deviation turns its findings into noise.

Append a `Deviations` section to the Markdown plan before spawning review:

- Every material difference between the plan and the implementation: files added or
  dropped, approach changes, scope adjustments, and why.
- If the implementation matches the plan, state "No deviations."

Then spawn the `[REVIEW]` session following ship's "Spawning the next phase"
procedure, with payload branch, worktree path, and plan file path. Before you spawn,
run `ORCA worktree set --worktree path:<worktree-path> --comment "Implemented" --json`.
