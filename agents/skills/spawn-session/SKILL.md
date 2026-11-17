---
name: spawn-session
description: Start a fresh session of the current agent (OpenCode, Claude Code, pi, Codex, or Cursor) in a new Orca terminal in a given worktree. Used by init-worktree, teardown, and ship to move work to a new session.
disable-model-invocation: true
---

# Spawn session

Run `~/.agents/skills/spawn-session/scripts/spawn-session.sh <dir> <title> <prompt>
[opencode-agent]`. Do not build the command yourself and do not choose the runtime.
The script detects the current agent and starts it in a new Orca terminal with the
prompt.

Exit `0` means the terminal started. Exit `2` means this session runs outside Orca:
report the printed command to the user. Exit `1` means the agent is unknown. On exit
`0` or `2`, end the calling session.

The new session has no prior conversation, so the prompt must carry everything it
needs. The fourth argument only selects the OpenCode agent; other agents ignore it.
