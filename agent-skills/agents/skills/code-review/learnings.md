# Code Review Learnings

This file accumulates review patterns and feedback over time. The agent reads this before every review and appends new learnings after receiving feedback.

## How to Add Entries

Append new entries under the appropriate section using this format:

```
### YYYY-MM-DD — PR #NUMBER — Brief context
- **Learning**: What was learned
- **Source**: User feedback / observation
```

---

## False Positives (Don't Flag These)

_Things that were flagged but shouldn't have been. Prevents repeating unhelpful comments._

### 2026-02-08 — PR #252048 — connector-id selector enhancements
- **Learning**: `workflows_management` importing from `@kbn/workflows-extensions/public` is an existing, accepted dependency (10+ files). Do NOT flag this as an architecture issue.
- **Source**: User feedback — asked if it was a new dependency; grep confirmed it's pre-existing.

---

## Recurring Patterns to Watch

_Patterns that keep appearing and should always be checked._

<!-- Add entries here when the same issue appears across multiple PRs -->

---

## Team Preferences

_Specific style/approach preferences expressed by team members._

### 2026-02-08 — Initial setup
- **Learning**: Team uses snake_case for directory names, not kebab-case. Several directories are being renamed (fallback-step, step-level, workflow-level, parse-duration).
- **Source**: Slack discussion, joes-ralphies#208

### 2026-02-08 — Initial setup
- **Learning**: `connector-id` field should only appear in schemas of steps that actually use connectors (not elasticsearch.*, kibana.*, console steps).
- **Source**: Sergi's PR #252048

### 2026-02-08 — Initial setup
- **Learning**: The execution engine must remain stateless and independent of Kibana core services (HTTP, routing). This is a hard architectural constraint.
- **Source**: CLAUDE.md, team architecture discussions

---

## Codebase-Specific Notes

_Notes about specific files, modules, or patterns unique to this codebase._

### 2026-02-08 — Initial setup
- `correctYamlSyntax` in `workflows_management/common/lib/yaml/` has known issues with JSON-in-YAML values. Be cautious reviewing changes here.
- Log data streams are created but no longer used — cleanup needed before GA.
- The `workflows_extensions` plugin should only contain the step registry and triggers, NOT be a catch-all for step implementations.
