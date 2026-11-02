# Review rules

Human reviewers left these comments again and again on past Kibana PRs. Apply the
rules when you write code and when you review it. They add to the Code section of
`AGENTS.md` and do not repeat it.

A Kibana change fails review when it duplicates an existing helper, crosses a plugin
boundary, hides an error, or breaks a stored id. Look for these first.

## Reuse

- Before you write a helper, hook, constant, or URL builder, search the plugin and
  its dependencies for one that exists. Reuse it.
- Navigate across apps with the registered locator. Do not build URLs or query
  strings by hand.
- When two components need the same handler, extract one hook. Do not copy the
  handler.

## Types

- Do not use `as` type assertions in source or tests. Narrow with a type guard, or
  build the value with a typed factory. `as const` is allowed.
- Mark a field optional only when it can be missing at runtime.
- Switch over a union with a `default` branch that assigns the value to `never`.

## Errors

- Never write an empty `catch` or `.catch(() => {})`. Log the error with the plugin
  logger, or show an error state.
- When one of several requests fails, show the results that succeeded and say which
  part failed.

## Plugin boundaries

- Do not read another plugin's indices, saved objects, or internal routes. Use its
  public plugin contract or public route. If none exists, stop and record the gap.
- Keep feature logic inside the feature's plugin. Do not add it to shared packages.

## Compatibility

- A rename or removal of a trigger id, schema field, saved-object attribute, URL
  parameter, route, or telemetry event is a breaking change. Keep the old value
  working, or list the break in the PR `Risk` section.
- Do not add a required field to an existing schema without a default or a
  migration.

## Performance

- Do not send one request per rendered row. Batch the request at the list level.
- Add `useMemo` or `useCallback` only when a dependency or a measured render cost
  needs it.
- Compute aggregations in Elasticsearch, not in the browser.

## UI

- Use EUI components and EUI theme tokens. Do not add custom CSS for what an EUI prop
  already does.
- Do not disable an EUI lint rule. Use the component the rule asks for, for example
  `EuiButtonEmpty` instead of an `EuiLink` without `href`.
- Give each interactive element a unique `data-test-subj` within its file.
- Wrap every user-facing string in `i18n.translate` or `FormattedMessage`.

## Security

- A route that changes state must check that the caller may act on the target
  object, not only that the caller has the privilege.
- A read-only user must not get a 403 on a page they can open. Check the read path
  with a read-only role.

## Readability

- Do not nest `await` inside expressions. Assign each awaited value to a named
  constant first.

## For reviewers

- Cite `file:line` for each finding. Do not infer a defect from a name.
- For each bug, state the input or sequence of events that triggers it.
- Tag each finding `Important`, `Nit`, or `Pre-existing`. Keep nits few, so they do not bury the important findings.
- When a finding is one instance of a pattern, list every instance in the diff.
- Skip generated files: `**/target/**`, `*.snap`, `oas_docs/**`,
  `.github/CODEOWNERS`, and translation JSON files.
- Start the summary with the finding count. When nothing needs a fix, say
  "No findings."

## Maintain this file

- Add a rule when a reviewer comment applies beyond its PR. Write one imperative
  sentence under the matching heading.
- When a reviewer flags a rule that already exists here, the rule did not hold.
  Propose a lint rule or a check in a skill instead of a second sentence.
- Delete a rule when a lint rule starts to enforce it.
