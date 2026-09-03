# Workflow

- Delegate open-ended exploration to an `explore` subagent through the Task tool
  whenever the answer is not a single known file. Work from its summary; do not
  stream long chains of Read and Grep calls into the primary session.
- In skills with an investigation phase, run the investigation through subagents
  and keep only the conclusions in the main session.
- In CodeGraph-indexed repos, call `codegraph_explore` before any grep-and-read
  loop.
- Use Read, Glob, Grep, Edit, and Write instead of `cat`, `head`, `tail`,
  `find`, `grep`, `sed`, and `echo` redirection. Reserve bash for real commands:
  git, yarn, curl, servers, and scripts.
- Run repeated multi-line shell procedures from a script file instead of
  retyping them; ship's server scripts live in `~/.agents/skills/ship/scripts/`.
- For GitHub content, fetch `raw.githubusercontent.com` or use `gh api`. Never
  fetch `github.com` HTML pages; they waste thousands of tokens on page chrome.
