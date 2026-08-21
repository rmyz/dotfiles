# Code

Apply these rules whenever writing or editing code.

- Almost never add code comments. Add one only when there is an explicit, critical reason to do it.
- Keep PRs below 500 changed lines. If a PR exceeds 500 lines, assess whether it can be split into smaller coherent changes. Keep it together only when the large refactor or feature cannot be split without harming reviewability or correctness.
- After any iteration that changes files, end the response with a brief summary naming each changed file and what changed.

## UI copy

- Never modify or rephrase UI text, labels, buttons, tooltips, error messages, or other user-facing strings automatically.
- If a task requires a UI copy change, stop and ask for explicit confirmation with the exact proposed text. Wait for approval before editing the code or localization bundle.
