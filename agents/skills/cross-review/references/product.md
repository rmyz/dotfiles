# Product review

Review the diff in the default scope from `~/.agents/REVIEW.md`. Read the linked issue
or plan when one is provided; requirement fit is judged against it.

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
   - **Copy & accessibility** — clear wording, every user-facing string wrapped in
     `i18n.translate` or `FormattedMessage`, and basic a11y (labels, keyboard,
     contrast) where relevant. Copy findings are report-only; UI text changes always
     need explicit user approval.

Report each finding with its `file:line`, its tag from the "For reviewers" section of
`~/.agents/REVIEW.md`, and a one-line suggested fix.
