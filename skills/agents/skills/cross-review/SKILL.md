---
name: cross-review
description: Multi-model review of a diff. Four reviewers on different models apply the technical and product rubrics independently; findings are synthesized by consensus into act-on/consider/noted/dismissed buckets. Report-only.
---

# Cross review

Multiple models review the same change independently. The adversarial signal comes
from model diversity, not personas: agreement across model families is
high-confidence signal, a lone-model finding is a noise candidate. This skill only
reports; it never applies changes.

## Step 1: Scope and intent

Scope: uncommitted changes plus branch commits against `upstream/main` (committed,
staged, unstaged, untracked), unless the invocation names a ref or PR.

State the intent in one paragraph before spawning anything: what the change is trying
to accomplish, derived from the plan file, the linked issue, commit messages, or the
user's message. Reviewers judge whether the work achieves the intent, not whether the
intent is right. If the intent is unclear, ask before proceeding.

## Step 2: Spawn the panel

Launch all four reviewers in one message via the Task tool, one per pinned subagent:

| subagent_type    | Family              |
| ---------------- | ------------------- |
| `reviewer-opus`  | Anthropic (Opus)    |
| `reviewer-fable` | Anthropic (Fable)   |
| `reviewer-sol`   | OpenAI              |
| `reviewer-grok`  | xAI                 |

Every reviewer gets the identical briefing:

- The intent paragraph and the plan file path when one exists.
- The exact diff scope and the commands to obtain it.
- Instructions to read and apply both rubrics:
  `~/.agents/skills/technical-review/SKILL.md` and
  `~/.agents/skills/product-review/SKILL.md`.
- Output format: one finding per line item with severity, file, rubric item, and a
  one-line suggested fix.

If a reviewer subagent is unavailable, continue with the remaining ones and say so in
the report; never substitute two reviewers from the same model family.

## Step 3: Synthesize

You are the lead reviewer, not a neutral aggregator. Merge findings that describe the
same issue and note which models raised each one. Then bucket every finding:

- **Act on** — real correctness, security, or maintainability issues given the actual
  goal. Would block a PR.
- **Consider** — legitimate, but the cost of addressing it now is not clearly worth
  it. The user decides.
- **Noted** — valid but low-impact or premature.
- **Dismissed** — wrong, nitpicky, or missing context, with a one-line reason.
  Always show this bucket so the user can override the filtering.

Weight by agreement: findings raised independently by two or more models rank above
lone-model findings of the same severity. A lone-model finding lands in Act on only
when you can verify it yourself in the code.

End with an agreement map: where the models agreed, where they diverged, and what the
pattern says about confidence.

## Phase 2: auto-apply (not enabled)

Do not act on this section yet. It becomes active only when the user removes this
marker after grading the Act-on bucket across several PRs.

When enabled, findings may be applied without a per-finding user decision only when
all three hold:

1. Consensus: two or more model families raised it independently.
2. Safe class: a demonstrated correctness bug (write the failing test first, the fix
   turns it green), dead code introduced by the diff, or missed error handling inside
   changed code. Never UI copy, never architecture or refactors beyond the diff,
   never scope changes, never files outside the plan's file list.
3. Revalidation: affected tests and `node scripts/check.js --scope=local` rerun green
   after the fix.

Everything applied is listed afterwards with the models that agreed. All other
findings still go to the user.
