---
name: kibana-synthetic-data-generation
description: Generate and ingest Kibana synthtrace synthetic data. Uses built-in scenarios when possible; otherwise creates local git-excluded dynamic scenarios under Kibana’s synthtrace `scenarios/dynamic/` for custom repro prompts.
---

# Kibana Synthetic Data Generation

Generate synthtrace data for a prompt, without needing to land a scenario in `main`.

## Constraints

- Dynamic scenarios are **local-only** and must be **git-excluded** via `${KIBANA_ROOT}/.git/info/exclude` (not via committed `.gitignore`).
- Run synthtrace in a new Orca terminal (`ORCA terminal create`, per `AGENTS.md`). Do not wait for the run to finish: confirm it is healthy with `ORCA terminal read`, then validate the data shape in Elasticsearch. Stop a run with `ORCA terminal close --terminal <handle> --json`.

## Prerequisites

- Kibana repo available locally (the workspace should contain `scripts/synthtrace.js`).
- Elasticsearch and Kibana reachable by synthtrace (local dev, Cloud, or Serverless).

## Workflow

### 1) Translate the prompt into a data shape

Extract what the user is trying to *see* in Kibana and translate it into measurable properties, such as:

- **APM**: one trace vs many traces, number of unique `service.name`, dependency fanout, error rate, span depth, long durations, etc.
- **Logs**: datasets, volume, mapping failures vs clean logs, correlation with traces (`trace.id`), etc.
- **Infra**: number of hosts/containers/pods, metricset coverage, correlation with services, etc.

### 2) Decide: built-in scenario vs dynamic scenario

Prefer a built-in scenario when it already matches the data shape. Common starting points:

- `logs_traces_hosts` for correlated logs + APM + hosts (supports many knobs via `--scenarioOpts`).
- `many_services` for very high service cardinality.
- `distributed_trace_long` for deep/large traces.
- `many_dependencies` for dependency cardinality.

Only generate a dynamic scenario when:

- No built-in scenario can produce the required shape, or
- A built-in scenario is close but would require invasive changes.

### 3) Ensure the dynamic scenarios directory is safe (git-excluded)

Compute:

- `**KIBANA_ROOT`**: repo root (contains `.git/` and `scripts/synthtrace.js`).
- `**DYNAMIC_DIR`**: `${KIBANA_ROOT}/src/platform/packages/shared/kbn-synthtrace/src/scenarios/dynamic`
- `**EXCLUDE_FILE**`: `${KIBANA_ROOT}/.git/info/exclude`

Then:

1. Create `DYNAMIC_DIR` if missing.
2. Add the ignore rule to `EXCLUDE_FILE` when it is missing:
  `grep -qxF 'src/platform/packages/shared/kbn-synthtrace/src/scenarios/dynamic/' "$EXCLUDE_FILE" || echo 'src/platform/packages/shared/kbn-synthtrace/src/scenarios/dynamic/' >> "$EXCLUDE_FILE"`

### 4) Maintain `dynamic/README.md`

Ensure `${DYNAMIC_DIR}/README.md` exists and is maintained as scenarios are added/updated.

Rules:

- The README describes **what each dynamic scenario does and how to use it**.
- The README must **not** mention systematic references (SDH/issue numbers). Mention them only in chat.
- The README must mention that dynamic scenarios are intended to be created/managed by this skill:
`https://github.com/elastic/skills/tree/main/skills/kibana-synthetic-data-generation`

### 5) Reuse or generate a dynamic scenario

Use a **semantic filename** (no SDH/issue numbers), for example:

- `trace_services_legend_overflow.ts`
- `trace_many_services_single_trace.ts`
- `logs_mapping_conflicts.ts`

When creating a new dynamic scenario file:

- Start the file with the Kibana license header and add no other comments. Put the goal, the data types and key fields, the `--scenarioOpts` with defaults, the run command, and the validation in `dynamic/README.md`.
- Use `getSynthtraceEnvironment(__filename)` and set `service.environment` (or equivalent) so the run can be isolated for validation.
- Prefer stable, queryable markers (service name prefixes, transaction name conventions, log message prefixes) to make validation easy.

### 6) Run synthtrace (don’t block)

Run from `${KIBANA_ROOT}`:

- Built-in scenario:
`node scripts/synthtrace <scenario> ...`
- Dynamic scenario:
`node scripts/synthtrace dynamic/<scenarioBaseName> ...`

By default, ingest a finite backfill for the past week (unless range is specified in the prompt):

- `--from now-1w --to now`

For the worktree stack, pass `--target=http://elastic:changeme@localhost:<es-port>` and `--kibana=http://elastic:changeme@localhost:<kibana-port><base-path>`. For Cloud or Serverless, add `--apiKey` and, for self-signed certificates, `--insecure`.

Never run synthtrace with `--live`: live mode is unbounded. Show the full `--live` command for the user to run, and remind them that `Ctrl+C` stops it.

Leave the ingestion process running while you validate (for finite backfills, this just means validate as soon as you see documents start appearing).

### 7) Validate in Elasticsearch (prompt-driven)

Validation must be driven by the prompt’s required shape, not by a fixed query template. Examples:

- “Need horizontal scroll on the trace waterfall services legend” → prove a **single trace** has **many unique `service.name`**.
- “Need service inventory horizontal scroll” → prove high service cardinality in the time window and environment.
- “Need mapping conflicts in logs” → prove ingestion failures exist in the failure store / error indices, and that some successful docs still exist.

Prefer filtering by a scenario-specific tag such as `service.environment` derived from `getSynthtraceEnvironment(__filename)`. If not available, filter by stable markers you set (service prefix, transaction names, datasets, etc.).

### 8) Reiterate if validation spots unintended data shape

- If during validation (step 7), it's found that the ingested data is not in the intended shape and the script needs adjustment/enhancement, stop the run, enhance the script, and re-run and repeat.

### 9) Reporting

- A compact summary of what is ingested.
- The Dev Tools queries from step 7 that you ran successfully, with real sample output. Use curl with basic auth or an API key only when Dev Tools cannot run the request. Add a date range filter when the user asked for specific dates.
- Where in the Kibana UI (app or page) the user can see the data.

  Example request
  ```
  POST /traces-apm*/_search
  { "query": { "wildcard": { "transaction.name": "*anime*" } } }
  ```

## Reference material

- Dynamic scenario skeleton and authoring checklist: [references/dynamic_scenario_skeleton.md](references/dynamic_scenario_skeleton.md)
- “Services legend overflow” scenario template: [references/template_services_legend_overflow.md](references/template_services_legend_overflow.md)
- Validation query patterns (pick based on prompt): [references/validation_query_patterns.md](references/validation_query_patterns.md)

