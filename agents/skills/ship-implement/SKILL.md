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
re-investigate or expand its scope. Then:

- Use the rule in `~/.agents/skills/kibana-dev-stack/SKILL.md` to decide whether
  implementation needs Kibana.

## Implement

Read `~/.agents/REVIEW.md` before the first edit. Implement the plan without pausing
between items. Stop only for a genuine blocker.

For a bug fix, run the plan's reproduction first and confirm that it fails. A fix
without a failing reproduction is a guess.

End each step with its check from the plan. Start the next step only when the check
passes. Reuse existing helpers and patterns. Do not expand scope or add speculative
abstractions.

## Prove it works

Run every acceptance criterion's check from the plan against the final code. Start
servers through `~/.agents/skills/kibana-dev-stack/SKILL.md` when a check needs them.
Append a `Verification` section to the plan with one row per criterion: the check,
the exit code or observed result, and the evidence. Evidence is quoted output, a
response body, or a screenshot path under `~/Code/ai-generated/<work-id>/demo`. A claim
without evidence is not a pass. A check that fails and cannot be fixed is a blocker.

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
