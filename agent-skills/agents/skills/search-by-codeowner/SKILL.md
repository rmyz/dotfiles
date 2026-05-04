---
name: search-by-codeowner
description: Search for a term in files owned by a specific GitHub team based on CODEOWNERS. Use when asked to find code within a team's ownership boundary.
---

# Search by Code Owner

## Overview

The `.github/CODEOWNERS` file in `~/Code/kibana` maps file paths to owning GitHub teams. This skill searches for a term only within directories owned by a given team in the local Kibana checkout.

The scan root is hardcoded to `~/Code/kibana` — this skill always scans that folder regardless of where it is invoked from.

## Helper script

The script lives with the skill (outside the Kibana repo). Because Node resolves modules relative to the script's location, `NODE_PATH` must point at Kibana's `node_modules` so `@kbn/setup-node-env`, `@babel/runtime`, etc. resolve correctly:

```bash
cd ~/Code/kibana && \
  NODE_PATH=~/Code/kibana/node_modules \
  node --no-experimental-require-module -r @kbn/setup-node-env \
  ~/.dotfiles/agent-skills/agents/skills/search-by-codeowner/search_by_codeowner.ts \
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
  ~/.dotfiles/agent-skills/agents/skills/search-by-codeowner/search_by_codeowner.ts \
  --team @elastic/kibana-core --search "useEffect"
```

## How it works

1. Parses `~/Code/kibana/.github/CODEOWNERS` to extract directory patterns assigned to the target team
2. Validates each directory exists on disk under `~/Code/kibana`
3. Runs `grep -ril` within those directories for the search term
4. Returns relative file paths (relative to `~/Code/kibana`) sorted alphabetically

## Manual alternative

If you prefer using the agent's built-in Grep tool directly:

1. Read `.github/CODEOWNERS` and find paths for the target team
2. Use the Grep tool scoped to each directory from step 1
