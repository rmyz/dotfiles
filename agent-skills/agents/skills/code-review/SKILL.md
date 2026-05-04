---
name: code-review
description: Review GitHub PRs for architecture, nit picks, and code quality issues. Use when the user shares a PR URL, asks to review a PR, or says "review PR", "check this PR", "code review".
---

# Code Review

Reviews PRs focusing on architecture, nit picks, naming, patterns, and quality. Uses team context from workspace rules when available. Improves over time via [learnings.md](learnings.md).

## Execution Workflow

### Step 1: Load Learnings

Read [learnings.md](learnings.md) for accumulated review patterns before starting.

### Step 2: Fetch PR Data

Use `gh` CLI to gather PR context. Run these in parallel:

```bash
gh pr view PR_NUMBER --repo <PR_TARGET_REPO> --json title,body,files,additions,deletions
gh pr diff PR_NUMBER --repo <PR_TARGET_REPO>
gh api repos/<PR_TARGET_REPO>/pulls/PR_NUMBER/comments
```

Read **PR_TARGET_REPO** from workspace rules (team config). Default: `elastic/kibana`.

### Step 3: Analyze & Categorize

Review every changed file through the lenses below. For large PRs (50+ files), focus on files owned by the team (check workspace rules for team-owned paths).

### Step 4: Output Review

Use the format in the Output Format section below.

### Step 5: Collect Feedback (Improvement Loop)

After presenting the review, ask:
> "Any feedback on this review? Anything I flagged that wasn't useful, or missed something important?"

If the user provides feedback, **append it** to [learnings.md](learnings.md) following the format documented there.

---

## Review Lenses

### 1. Architecture

| Check | What to look for |
|-------|-----------------|
| Plugin boundaries | Changes crossing plugin boundaries without proper contracts |
| Service layer separation | Business logic leaking into route handlers or UI components |
| Repository pattern | Direct ES/SO calls bypassing repository classes |
| Plugin lifecycle | Improper setup/start phase usage, missing dependency declarations in `kibana.jsonc` |
| Circular dependencies | New imports creating circular dependency chains between plugins |

### 2. Nit Picks

| Check | What to look for |
|-------|-----------------|
| Naming | Variables/functions not following Kibana conventions (camelCase, PascalCase components) |
| Dead code | Commented-out code, unused imports, unreachable branches |
| Magic values | Hardcoded strings/numbers that should be constants |
| File organization | Code in wrong directory per the established structure |
| Consistency | Mixing patterns within the same file (e.g., async/callback) |
| Typos | In comments, variable names, user-facing strings |
| Import order | Disorganized imports (Kibana convention: external, then `@kbn/`, then relative) |

### 3. TypeScript & Types

| Check | What to look for |
|-------|-----------------|
| `any` usage | Avoid `any`; use `unknown` + type guards or proper generics |
| Missing types | Untyped function params, return types on public APIs |
| Type assertions | `as` casts hiding real type issues |
| Zod schemas | Schema drift from TypeScript types, missing runtime validation |

### 4. Performance

| Check | What to look for |
|-------|-----------------|
| ES queries | Missing pagination, unbounded queries, missing `size` limits |
| N+1 patterns | Loops making individual ES/SO calls instead of bulk/mget |
| Memory | Large arrays/objects held in memory, missing cleanup |
| Async patterns | Missing `await`, unhandled promise rejections, sequential awaits that could be parallel |

### 5. Security

| Check | What to look for |
|-------|-----------------|
| Input validation | Missing Zod/schema validation on API inputs |
| Permissions | Missing authorization checks, feature privilege enforcement |
| Injection | Template injection in Liquid/YAML, unsanitized user input |
| Secrets | API keys, tokens, credentials in code or logs |

### 6. Testing

| Check | What to look for |
|-------|-----------------|
| Coverage gaps | New logic paths without corresponding tests |
| Mock quality | Over-mocking hiding real bugs, mocks not matching real interfaces |
| Edge cases | Missing error path tests, boundary conditions |
| Test naming | Unclear `it('should work')` style descriptions |

---

## Output Format

```markdown
# PR Review: #NUMBER -- TITLE

**Files changed**: N | **Additions**: +N | **Deletions**: -N

## Architecture

- **[file:line]** SEVERITY -- Description of the issue
  > Suggestion or question

## Nit Picks

- **[file:line]** -- Description
  > Suggestion

## TypeScript & Types

- **[file:line]** SEVERITY -- Description
  > Suggestion

## Performance

- **[file:line]** SEVERITY -- Description
  > Suggestion

## Security

- **[file:line]** SEVERITY -- Description
  > Suggestion

## Testing

- **[file:line]** -- Description
  > Suggestion

## Summary

**Approve / Request Changes / Comment**
[1-2 sentence overall assessment]
```

Severity markers:
- `BLOCKING` -- Must fix before merge
- `IMPORTANT` -- Should fix, could cause issues
- `SUGGESTION` -- Consider improving
- Nit picks have no severity (they're all nits)

**Omit empty sections.** Only include sections that have findings.

---

## Team Context

Read team-specific context from workspace rules (team config) if available. This includes:
- Team-owned plugin/package paths
- Team members
- Patterns and conventions specific to the team
- Current focus areas

If no team config is present, review using general Kibana conventions from `AGENTS.md`.
