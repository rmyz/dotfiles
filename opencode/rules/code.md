# Code

Apply these rules whenever writing or editing code.

- Never add code comments. A comment means the code is not clear; simplify the code instead.
- No defensive code on trusted internal paths: no try/catch, existence checks, or fallbacks that the surrounding code does not need.
- Never cast to `any` (or `as unknown as`) to silence a type error; fix the type.
- Prefer early returns over nested conditionals.
- Match the surrounding file's style and reuse its helpers instead of introducing parallel patterns.
- Keep PRs below 500 changed lines. If a PR exceeds 500 lines, assess whether it can be split into smaller coherent changes. Keep it together only when the large refactor or feature cannot be split without harming reviewability or correctness.
- After any iteration that changes files, end the response with a brief summary naming each changed file and what changed.

## UI copy

- Never modify or rephrase UI text, labels, buttons, tooltips, error messages, or other user-facing strings automatically.
- If a task requires a UI copy change, stop and ask for explicit confirmation with the exact proposed text. Wait for approval before editing the code or localization bundle.
