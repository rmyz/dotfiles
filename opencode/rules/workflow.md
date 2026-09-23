# Workflow

- Delegate open-ended exploration to a `build` subagent through the Task tool
  whenever the answer is not a single known file. Work from its summary; do not
  stream long chains of Read and Grep calls into the primary session.
- In skills with an investigation phase, run the investigation through subagents
  and keep only the conclusions in the main session.
- Use Read, Glob, Grep, Edit, and Write instead of `cat`, `head`, `tail`,
  `find`, `grep`, `sed`, and `echo` redirection. Reserve bash for real commands:
  git, yarn, curl, servers, and scripts.
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
