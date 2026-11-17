---
name: find-dependency-references
description: Find all files that import or require a specific dependency, with team ownership grouping from CODEOWNERS. Use when analyzing dependency usage, planning migrations, or auditing third-party library consumption.
---

# Find Dependency References

## Overview

Finds all files in the current Kibana checkout that import or use a given dependency (e.g., `lodash`, `moment`, `enzyme`).

The scan root is the current directory. The worktree needs `kbnb` to have run.

## Helper script

The script lives with the skill (outside the Kibana repo). Because Node resolves modules relative to the script's location, `NODE_PATH` must point at Kibana's `node_modules` so `@kbn/setup-node-env`, `@babel/runtime`, etc. resolve correctly:

```bash
cd "$(git rev-parse --show-toplevel)" && \
  NODE_PATH="$PWD/node_modules" \
  node --no-experimental-require-module -r @kbn/setup-node-env \
  ~/.agents/skills/find-dependency-references/find_dependency_references.ts \
  --dependency <name>
```

Options:
- `--dependency <name>` -- the dependency to search for (e.g., `enzyme`, `lodash`, `moment`)

Output: JSON with:
- `dependencyName` -- the searched dependency
- `totalScannedFiles` -- number of files scanned
- `totalMatchingFiles` -- number of files with imports
- `uniqueApis` -- list of specific APIs used from the dependency
- `matchingFilesByTeam[]` -- files grouped by CODEOWNERS team, each with extracted API usage
- `matchingFiles[]` -- flat list of all matching file paths
- `analysisTimeMs` -- how long the analysis took

## How it works

1. Scans all `.js`, `.jsx`, `.ts`, `.tsx`, `.d.ts` files under the scan root (respecting `.gitignore`)
2. Detects ES6 imports (`import ... from 'dep'`), CommonJS requires (`require('dep')`), and dynamic imports (`import('dep')`)

If the script fails, use Grep with the pattern `from ['"]<dep>['"]`.
