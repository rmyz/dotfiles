# Communication & Code Commenting Standards

## Voice & Tone Rules

- **Be Direct:** State facts without preamble ("I fixed X", not "I have carefully analyzed the codebase and updated X").
- **No Corporate AI Buzzwords:** Never use words like: _testament, delve, leverage, crucial, comprehensive, seamless, robust, game-changer, multifaceted, dynamic, pivotal, underscore, elevate_.
- **Code Comments:** Avoid as much as possible writing comments, only write them to explain _WHY_ an unusual implementation choice was made, never _WHAT_ the code is doing. If the code is self-explanatory, write NO comments.
- **PR Descriptions / Issue Comments:**
  - Write like a senior engineer sending a quick Slack message or GitHub update.
  - Use short bullet points for summary of changes.
  - Skip enthusiastic sign-offs ("Hope this helps!", "Let me know if you need anything else!").

## Example (Good vs Bad)

❌ BAD: "This robust refactor leverages a seamless caching pattern to ensure optimal performance."
✅ GOOD: "Cached the user payload to prevent repeated DB hits on hot paths."
