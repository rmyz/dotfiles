---
name: skill-audit
description: Audit the agent skills in ~/.dotfiles/agents for inconsistencies, duplicated, stale, vague, and redundant instructions. Runs a mechanical check script, then read-only subagent audits per skill group, and reports numbered fixes. Use when the user asks to check, clean up, or tune skills.
disable-model-invocation: true
---

# Skill audit

Report only. Edit nothing until the user approves numbered findings.

Skill source: `~/.dotfiles/agents` (`skills/`, `AGENTS.md`, `REVIEW.md`, `opencode/`,
`codex/`). Skip `skills/visual-explainer` and the Orca stubs (`orca-cli`,
`orca-computer-use`, `orchestration`): upstream owns them and overwrites edits.

## 1. Mechanical check

```bash
~/.agents/skills/skill-audit/scripts/check.sh
```

It prints frontmatter mismatches, dead `~/.agents/...` paths, opencode commands that
load a missing skill, terms from `stale-terms.txt`, em dash counts, duplicate lines
across files, and the largest skill docs. Every hit is a finding. Judge em dash counts
only for text the user wrote.

## 2. Semantic audit

Read `AGENTS.md` and `~/.claude/CLAUDE.md` first. Split the skills into groups of about
10 files or 60 KB, keeping skills that call each other together. Run one read-only
subagent per group in parallel. Brief each one:

```text
INSPECTION ONLY. Do not edit or write files.
Audit these skills: <group>. Read each fully, plus AGENTS.md and ~/.claude/CLAUDE.md.
Return findings as file:line, quoted evidence, and an exact fix, grouped by:
1. Inconsistencies: contradictions within or between skills (ports, paths, script
   names, section names, step order, flags, tool names). Verify referenced files exist.
2. Duplicates: the same rule in several places. Name the one owner.
3. Stale: references to removed things or outdated facts. Verify with rg or ls.
4. Vague: steps where the agent must guess. Missing exact command, flag, path, or
   decision criterion. Two ways to do one thing.
5. Redundant prohibitions: "do not X" the agent would not do unless told. Keep a
   prohibition only when the default behavior is wrong or the action is destructive.
Also flag: rules that conflict with ~/.claude/CLAUDE.md, past-run residue (one-off
measurements, scratchpad paths, version-pinned values), and instructions that depend
on a tool, alias, or flag that does not exist (check it).
Skip nitpicks. Mark any claim you did not verify with "(verify)". End with the files
you read fully.
```

Skills depend on the current dev stack, so add the facts that changed since the last
run (ports, tool names, flow order) to the brief.

## 3. Verify, then report

Check every `(verify)` finding and every claim that a path, flag, alias, or command
does not exist before you report it. Drop what you cannot confirm.

Report numbered findings grouped by the five categories, then the mechanical hits. For
each: file:line, the problem, the exact fix, and the owner file for duplicates. End
with a token saving estimate and the list of rules you kept on purpose. Ask which
numbers to apply.

## 4. Apply

Apply only approved numbers. Use one writing worker for the whole repo, never several
in parallel. Do not touch `git/.gitconfig`. After the edits, rerun `check.sh` and show
what it prints.

## Tuning

When a finding repeats, add its term to `stale-terms.txt`, one fixed string per line.
When a check needs logic, extend `scripts/check.sh`.
