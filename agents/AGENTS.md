<!-- CODEGRAPH_START -->

## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.

<!-- CODEGRAPH_END -->

## Subagents

- State whether a delegated task is inspection-only or may edit files.
- Use one writing worker per worktree. Read-only workers may run in parallel.
- Subagents return concise results to the parent agent.

## Kibana remotes

- `origin` is the fork (`rmyz/kibana`); `upstream` is `elastic/kibana`.
- Diff, branch, and rebase against `upstream/main`. Never use `origin/main` — it is
  thousands of commits stale and is never synced.
- The clone also carries many other contributors' remotes. Never infer the fork as
  "the remote that is not `origin`".

## Local services

- Start Elasticsearch with `es` and Kibana with `kbn`. These aliases also pass
  `--eis` and the license config.
- Never pass `--no-base-path` to Kibana. Kibana always serves under a 3-letter
  prefix before `/app/`, for example `/kpd/app`.
- Before starting Elasticsearch, Kibana, or Storybook, run the server in a new Orca
  terminal (`orca terminal create`), so the user can read the logs there.

## Team config (elastic/kibana)

Team: nightshift-context-and-research. Used when opening PRs and filing issues.

- Team label: `Team:nightshift-context-and-research`
- Issue repo and PR target repo: `elastic/kibana`; PR base branch: `main`
- Release note label: `release_note:skip` — always, the user can modify them if needed
- Backport label: `backport:skip` — alway, the user can modify them if needed
- Version labels: none. They are added manually — never pass a version label.
- Commit types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`
- Public channel: [#nightshift-context-and-research](https://elastic.slack.com/archives/C0BDYNH8T52)

## Code

Apply these rules whenever writing or editing code.

- Never add code comments. A comment means the code is not clear; simplify the code instead.
- No defensive code on trusted internal paths: no try/catch, existence checks, or fallbacks that the surrounding code does not need.
- Never cast to `any` (or `as unknown as`) to silence a type error; fix the type.
- Prefer early returns over nested conditionals.
- Match the surrounding file's style and reuse its helpers instead of introducing parallel patterns.
- Never format files. The pre-commit hook runs formatting; manual formatting causes spurious diffs.
- Keep PRs below 500 changed lines. If a PR exceeds 500 lines, assess whether it can be split into smaller coherent changes. Keep it together only when the large refactor or feature cannot be split without harming reviewability or correctness.
- After any iteration that changes files, end the response with a brief summary naming each changed file and what changed.

### UI copy

- Never modify or rephrase UI text, labels, buttons, tooltips, error messages, or other user-facing strings automatically.
- If a task requires a UI copy change, stop and ask for explicit confirmation with the exact proposed text. Wait for approval before editing the code or localization bundle.

## Workflow

- Delegate open-ended exploration to a subagent whenever the answer is not a single known file. Work from its summary; do not stream long chains of file reads and searches into the primary session.
- In skills with an investigation phase, run the investigation through subagents
  and keep only the conclusions in the main session.
- Use the agent's file read, search, and edit tools instead of `cat`, `head`, `tail`, `find`, `grep`, `sed`, and `echo` redirection. Reserve the shell for real commands: git, yarn, curl, servers, and scripts.
- Use the TUI's patch or edit tools for normal file changes. Use Python only for
  bulk transformations or generated files.
- Run repeated multi-line shell procedures from a script file instead of
  retyping them; ship's server scripts live in `~/.agents/skills/ship/scripts/`.
- For GitHub content, fetch `raw.githubusercontent.com` or use `gh api`. Never
  fetch `github.com` HTML pages; they waste thousands of tokens on page chrome.
- Store generated artifacts under `~/Code/oc-generated`. Put plans in `plans`,
  screenshots and recordings in `demo`, and other standalone files in `files`.
  Create the destination directory before writing. Use `/tmp` only for ephemeral
  process state such as locks and sockets.
- Always create pull requests using the `create-pr` skill. Never create or push branches to `upstream` (`elastic/kibana`). Always push feature branches to the fork `rmyz/kibana` (`origin`) and target `elastic/kibana:main`.
- Only post `/ci` on draft PRs. Never comment `/ci` on ready (non-draft) PRs because CI runs automatically.

## Prose

Always apply these rules to every response, all communication between the user and agent, and any text written for others, including documents, commit messages, PRs, issues, reviews, and Slack messages.

- Always speak to me in ASD-STE100 Simplified Technical English: short sentences, active voice, one instruction per sentence, approved words only.
- Lead with the answer or result. Skip acknowledgements, preambles, recaps, and sign-offs.
- Use the fewest words that preserve the useful facts.
- Write like a senior engineer sending a quick Slack or GitHub update.
- Use bullets only when they make the response shorter or easier to scan. Do not add a summary that repeats them.

## Unslop

Edit text to remove AI patterns and add human voice.

### Process

1. Scan for the patterns below.
2. Rewrite. Preserve meaning, match intended tone.
3. Add soul (see next section).
4. Self-audit: "What makes this obviously AI generated?" Fix remaining tells.

### Adding soul

Removing patterns is half the job. Sterile, voiceless writing is just as obvious.

- **Have opinions.** React to facts instead of neutrally listing pros and cons.
- **Vary rhythm.** Short sentences. Then longer ones that take their time. Mix it up.
- **Acknowledge complexity.** "Impressive but also kind of unsettling" beats "impressive."
- **Use "I" when it fits.** First person isn't unprofessional.
- **Let some mess in.** Perfect structure looks machine-made.
- **Be specific.** Not "this is concerning" but "there's something unsettling about agents churning away at 3am."

### Patterns to detect and fix

#### Content

1. **Puffery.** "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut puffery, state what happened.
2. **Name-dropping.** Listing media outlets without context. Pick one, say what was said.
3. **Superficial -ing phrases.** "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete or expand with real sources.
4. **Promotional language.** "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit". Use neutral descriptions.
5. **Vague attributions.** "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete.
6. **Formulaic challenges.** "Despite challenges... continues to thrive." Replace with specific facts.

#### Language

7. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with plain words.
8. **Fancy ways to say "is".** "serves as", "stands as", "boasts", "features". Just say "is" or "has".
9. **"Not just X, but Y."** State the point directly instead.
10. **Rule of three.** Forcing ideas into groups of three. Use the natural number.
11. **Synonym cycling.** Protagonist, main character, central figure, hero all in one paragraph. Pick one, repeat it.
12. **False ranges.** "from X to Y" where X and Y aren't on a meaningful scale. List topics directly.

#### Style

13. **Em dash overuse.** Avoid em dashes entirely. Use periods or commas only (no parentheses, no en dashes, no hyphen-as-dash substitutes). Em dashes are an AI tell, and reaching for parentheses instead just trades one tell for another. If a thought needs separation, end the sentence or use a comma.
14. **Colon overuse.** Colons are fine before a list or example. Not as mid-sentence connectors. "If you're coming from traditional automation: instead of registering event handlers, you describe conditions" adds nothing with the colon. Rewrite to let the point stand on its own without comparison framing. "Describing when the scheduler should fire works best as plain English." Same meaning, no crutch punctuation.
15. **Boldface overuse.** Don't bold every proper noun or acronym.
16. **Inline-header lists.** The tell is a bold label and colon that restates the line: "**Performance:** Performance improved...". Convert those to prose. A bold lead-in that ends in a period, names the item, and is followed by genuinely new detail ("**Schema in TypeScript.** Tables live in one file.") is fine, not a tell.
17. **Title case headings.** Use sentence case.
18. **Decorative emojis.** Remove from headings and bullets.
19. **Curly quotes.** Replace with straight quotes.

#### Communication artifacts

20. **Chatbot phrases.** "I hope this helps!", "Let me know if...", "Of course!", "Certainly!", "Found the smoking gun!" Remove.
21. **Cutoff disclaimers.** "While specific details are limited..." Find sources or remove.
22. **Sycophantic tone.** "Great question! You're absolutely right!" Respond directly.

#### Filler

23. **Filler phrases.** "In order to" becomes "To". "Due to the fact that" becomes "Because". "It is important to note that" gets deleted.
24. **Excessive hedging.** "could potentially possibly be argued that it might" becomes "may".
25. **Generic conclusions.** "The future looks bright." State specific plans or facts.

#### Jargon

26. **Abstract metaphor nouns.** Substrate, wedge, vector, locus, vantage, nexus, primitive (as noun), harness (as metaphor), surface (as in "API surface"), bedrock, scaffolding (as metaphor), modality, paradigm, gold-plating, ratchet (as metaphor), evacuate (for moving code), endgame, north star, flywheel. These read as technical but usually have a plainer concrete word. "Substrate" becomes "base". "Wedge in" becomes "add". "Vector" becomes "way" or "method". "Gold-plating" becomes "more than the job needs". "Ratchet" becomes the mechanism's real name or "a limit that only tightens". "Evacuate" becomes "move out". "Endgame" becomes "the last phase". Pick the concrete word.

#### Plain speech

27. **Say what it does, not how it feels.** "the database stays close at hand", "SQL you can read", "types that follow your schema" name a feeling. The fix names the mechanism or a number: "`.toSQL()` returns the exact string sent to the database", "a column rename fails the build". Ask what the sentence tells the reader to do or know, then write that. If you can't restate it as a concrete instruction, fact, or number, cut it. One more check: if the sentence could appear unchanged in another project's docs, it says nothing about this one. Cut it.
28. **Shorten or split dense sentences.** If the reader has to backtrack to parse a sentence, break it in two or drop clauses. One idea per sentence.
29. **Active voice.** Prefer it. Catch "is/are/was/were + past participle" and name the actor: "queries are validated" becomes "the compiler validates queries", "the file is parsed by the loader" becomes "the loader parses the file". Passive is fine only when the actor is unknown or genuinely doesn't matter.
30. **Cut adverbs, or use a stronger verb.** "runs quickly" becomes "is fast" or the number. "significantly improves" becomes the measured delta. An adverb propping up a weak verb means the verb is wrong.
31. **Prefer the plain word.** "utilize" becomes "use", "leverage" becomes "use", "facilitate" becomes "help", "numerous" becomes "many", "in the event that" becomes "if". The fancier synonym is rarely clearer.
