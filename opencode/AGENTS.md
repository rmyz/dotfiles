<!-- CODEGRAPH_START -->

## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.

<!-- CODEGRAPH_END -->

## Kibana remotes

- `origin` is the fork (`rmyz/kibana`); `upstream` is `elastic/kibana`.
- Diff, branch, and rebase against `upstream/main`. Never use `origin/main` — it is
  thousands of commits stale and is never synced.
- The clone also carries many other contributors' remotes. Never infer the fork as
  "the remote that is not `origin`".

## Skills

Skills live in `~/.agents/skills/`. Ignore `~/.claude` and `~/.cursor` paths.

## Team config (elastic/kibana)

Team: nightshift-context-and-research. Used when opening PRs and filing issues.

- Team label: `Team:nightshift-context-and-research`
- Issue repo and PR target repo: `elastic/kibana`; PR base branch: `main`
- Release note label: `release_note:skip` — use `release_note:enhancement` or
  `release_note:fix` for user-facing changes
- Backport label: `backport:version`
- Version labels: none. They are added manually — never pass a version label.
- Commit types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`
- Public channel: [#nightshift-context-and-research](https://elastic.slack.com/archives/C0BDYNH8T52)
