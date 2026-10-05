---
alwaysApply: true
---

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
- If the agent has no file read tool, read files with `rg`, `cat`, or `sed -n` in
  the shell. Never use Python to read or search files.
- Use the agent's patch or edit tools for normal file changes. Use Python only for
  bulk transformations or generated files.
- Run repeated multi-line shell procedures from a script file instead of
  retyping them; ship's server scripts live in `~/.agents/skills/ship/scripts/`.
- For GitHub content, fetch `raw.githubusercontent.com` or use `gh api`. Never
  fetch `github.com` HTML pages; they waste thousands of tokens on page chrome.
- Store generated artifacts under `~/Code/ai-generated`. Put plans in `plans`,
  screenshots and recordings in `demo`, and other standalone files in `files`.
  Create the destination directory before writing. Use `/tmp` only for ephemeral
  process state such as locks and sockets.

## Kibana

Apply this section only when the working directory is a clone or worktree of
`elastic/kibana`. Ignore it everywhere else.

### Remotes

- `origin` is the fork (`rmyz/kibana`); `upstream` is `elastic/kibana`.
- Diff, branch, and rebase against `upstream/main`. Never use `origin/main` — it is
  thousands of commits stale and is never synced.
- The clone also carries many other contributors' remotes. Never infer the fork as
  "the remote that is not `origin`".

### Pull requests

- Always create pull requests using the `create-pr` skill. Never create or push branches to `upstream` (`elastic/kibana`). Always push feature branches to the fork `rmyz/kibana` (`origin`) and target `elastic/kibana:main`.
- Only post `/ci` on draft PRs. Never comment `/ci` on ready (non-draft) PRs because CI runs automatically.

### Local services

- Start Elasticsearch with `es` and Kibana with `kbn`. These aliases also pass
  `--eis` and the license config.
- Never pass `--no-base-path` to Kibana. Kibana always serves under a 3-letter
  prefix before `/app/`, for example `/kpd/app`.
- Before starting Elasticsearch, Kibana, or Storybook, run the server in a new Orca
  terminal (`orca terminal create`), so the user can read the logs there.

### Team config

Team: nightshift-context-and-research. Used when opening PRs and filing issues.

- Team label: `Team:nightshift-context-and-research`
- Issue repo and PR target repo: `elastic/kibana`; PR base branch: `main`
- Release note label: `release_note:skip` — always, the user can modify them if needed
- Backport label: `backport:skip` — always, the user can modify them if needed
- Version labels: none. They are added manually — never pass a version label.
- Commit types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`
- Public channel: [#nightshift-context-and-research](https://elastic.slack.com/archives/C0BDYNH8T52)

## Prose

Apply to every response and to any text written for others: docs, commit messages,
PRs, issues, reviews, and Slack messages.

- Write in ASD-STE100 Simplified Technical English: short sentences, active voice,
  one instruction per sentence, plain words.
- Lead with the answer or result. No greetings, preambles, recaps, or sign-offs.
- Use the fewest words that keep the useful facts. Cut filler ("in order to",
  "it is important to note"), hedging, and adverbs.
- State facts, numbers, and mechanisms. Not feelings or promotion ("robust",
  "seamless", "powerful").
- Name the actor. "The loader parses the file", not "the file is parsed".
- No em dashes. Use a period or a comma.
- Use sentence case for headings. Bold only what the reader must not miss.
- Use bullets only when they make the text shorter or easier to scan. Do not repeat
  them in a summary.
- Before sending, reread once and delete every sentence that adds no fact.
