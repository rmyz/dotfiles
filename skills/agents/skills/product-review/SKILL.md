---
name: product-review
description: Product review of a diff — side-effects and bugs (what could break) plus whether the change is correct and sensible for the user (requirement fit, UX, empty/error states, copy). Reports findings; never applies changes.
---

# Product review

Review the diff. By default that means uncommitted changes plus the commits on this
branch against `upstream/main` (committed, staged, unstaged, and untracked); if the
invocation names a ref, branch, or PR, review that instead. Read the linked issue or
plan when one is provided; requirement fit is judged against it.

Cover both angles:

1. **Side-effects and bugs**: what could break or misbehave because of these changes
   (interactions, state, edge cases, regressions in surrounding features).
2. **Product**: does the change actually do the right thing for the user?
   - **Requirement fit** — does it deliver what the issue, plan, or task asked for?
     Anything missing or out of scope?
   - **UX** — do the flows make sense? Cancel/confirm, loading, empty screens, and
     responsive behavior where it applies.
   - **Empty / error states** — what the user sees when there is no data or a request
     fails.
   - **Copy & accessibility** — clear wording and basic a11y (labels, keyboard,
     contrast) where relevant. Copy findings are report-only; UI text changes always
     need explicit user approval.

Report each finding with severity, file, and a one-line suggested fix. Do not apply
changes. End with a short list of which findings you would act on and which you would
drop, and why.
