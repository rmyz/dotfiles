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

## Local services

- Start Elasticsearch with `es` and Kibana with `kbn`. These aliases also pass
  `--eis` and the license config.
- Never pass `--no-base-path` to Kibana. Kibana always serves under a 3-letter
  prefix before `/app/`, for example `/kpd/app`.
- Before starting Elasticsearch, Kibana, or Storybook, run the server in a new Orca
  terminal (`orca terminal create`). Outside Orca, fall back to a new Herdr panel in
  the current tab. Either way the user can read the logs there.

## PR descriptions

- Do not add a Testing section listing jest or FTR files that CI already runs.
  Write a short "How to test" guide instead, so reviewers can validate locally.
- Link only `elastic/kibana` issues in the PR description. For private-repo
  issues, use the Development field on the issue side; public users will not
  see the link.

## Team config (elastic/kibana)

Team: nightshift-context-and-research. Used when opening PRs and filing issues.

- Team label: `Team:nightshift-context-and-research`
- Issue repo and PR target repo: `elastic/kibana`; PR base branch: `main`
- Release note label: `release_note:skip` — always, the user can modify them if needed
- Backport label: `backport:skip` — alway, the user can modify them if needed
- Version labels: none. They are added manually — never pass a version label.
- Commit types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`
- Public channel: [#nightshift-context-and-research](https://elastic.slack.com/archives/C0BDYNH8T52)
