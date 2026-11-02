---
name: search-by-codeowner
description: Search for a term in files owned by a specific GitHub team based on CODEOWNERS. Use when asked to find code within a team's ownership boundary.
---

# Search by Code Owner

## Overview

The `.github/CODEOWNERS` file in `~/Code/kibana` maps file paths to owning GitHub teams. This skill searches tracked `.js`, `.jsx`, `.ts`, `.tsx`, `.json`, `.md`, `.yml`, and `.yaml` files outside `node_modules`, `build`, and `target` directories whose last matching rule assigns them to the requested team.

The scan root is hardcoded to `~/Code/kibana` — this skill always scans that folder regardless of where it is invoked from.

## Helper script

The script lives with the skill (outside the Kibana repo). Because Node resolves modules relative to the script's location, `NODE_PATH` must point at Kibana's `node_modules` so `@kbn/setup-node-env`, `@babel/runtime`, etc. resolve correctly:

```bash
cd ~/Code/kibana && \
  NODE_PATH=~/Code/kibana/node_modules \
  node --no-experimental-require-module -r @kbn/setup-node-env \
  ~/.agents/skills/search-by-codeowner/search_by_codeowner.ts \
  --team <team> --search <term>
```

Options:
- `--team <team>` -- GitHub team (e.g., `@elastic/kibana-core`). The `@` prefix is added automatically if missing.
- `--search <term>` -- term to search for (case-insensitive grep)

Output: JSON with `team`, `searchTerm`, `totalScannedFiles`, `totalMatchingFiles`, `matchingFiles[]`, and `analysisTimeMs`.

### Examples

```bash
cd ~/Code/kibana && \
  NODE_PATH=~/Code/kibana/node_modules \
  node --no-experimental-require-module -r @kbn/setup-node-env \
  ~/.agents/skills/search-by-codeowner/search_by_codeowner.ts \
  --team @elastic/kibana-core --search "useEffect"
```

## How it works

1. Parses `~/Code/kibana/.github/CODEOWNERS` in rule order
2. Lists tracked files and applies CODEOWNERS glob patterns; the last matching rule sets each file's owners
3. Runs `grep -il` on files owned by the target team
4. Returns relative file paths (relative to `~/Code/kibana`) sorted alphabetically

## Manual alternative

If you prefer using the agent's built-in Grep tool directly:

1. Read `.github/CODEOWNERS` and find the patterns for the target team
2. Drop paths that a later rule assigns to another team; the last matching rule wins
3. Use the Grep tool scoped to the remaining paths
