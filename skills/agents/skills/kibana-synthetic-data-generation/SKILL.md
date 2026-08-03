---
name: kibana-synthetic-data-generation
description: Generate and ingest Kibana synthtrace synthetic data. Uses built-in scenarios when possible; otherwise creates local git-excluded dynamic scenarios under Kibana’s synthtrace `scenarios/dynamic/` for custom repro prompts.
---

# Kibana Synthetic Data Generation

Generate synthtrace data for a prompt, without needing to land a scenario in `main`.

## Constraints

- Dynamic scenarios are **local-only** and must be **git-excluded** via `${KIBANA_ROOT}/.git/info/exclude` (not via committed `.gitignore`).
- When ingestion may take a while, **do not wait** for the whole run to finish. Start ingestion, confirm it’s healthy via initial logs, then validate the resulting data shape in Elasticsearch.

## Prerequisites

- Kibana repo available locally (the workspace should contain `scripts/synthtrace.js`).
- Elasticsearch and Kibana reachable by synthtrace (local dev, Cloud, or Serverless).

## Workflow

### 1) Translate the prompt into a data shape

Extract what the user is trying to *see* in Kibana and translate it into measurable properties, such as:

- **APM**: one trace vs many traces, number of unique `service.name`, dependency fanout, error rate, span depth, long durations, etc.
- **Logs**: datasets, volume, mapping failures vs clean logs, correlation with traces (`trace.id`), etc.
- **Infra**: number of hosts/containers/pods, metricset coverage, correlation with services, etc.
- **Time model**: fixed range (backfill) vs `--live` streaming.

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
2. Ensure `EXCLUDE_FILE` contains this ignore rule (exactly or equivalent):
  `src/platform/packages/shared/kbn-synthtrace/src/scenarios/dynamic/`
3. If you cannot edit `EXCLUDE_FILE` (permissions/read-only checkout), stop and tell the user to add the ignore rule manually by editing `${KIBANA_ROOT}/.git/info/exclude` and re-running the skill. And print a curated shell command which user should run.

### 4) Maintain `dynamic/README.md`

Ensure `${DYNAMIC_DIR}/README.md` exists and is maintained as scenarios are added/updated.

Rules:

- The README describes **what each dynamic scenario does and how to use it**.
- The README must **not** mention systematic references (SDH/issue numbers). Put those only in scenario-file comments.
- The README must mention that dynamic scenarios are intended to be created/managed by this skill:
`https://github.com/elastic/skills/tree/main/skills/kibana-synthetic-data-generation`

### 5) Reuse or generate a dynamic scenario

Use a **semantic filename** (no SDH/issue numbers), for example:

- `trace_services_legend_overflow.ts`
- `trace_many_services_single_trace.ts`
- `logs_mapping_conflicts.ts`

When creating a new dynamic scenario file:

- Add a **detailed header comment** explaining:
  - goal / intended Kibana UI behavior
  - what data types it generates (APM/logs/infra) and key fields it sets
  - `--scenarioOpts` supported and defaults
  - how to validate the data shape in ES
  - systematic references (SDH/issues) if applicable
- Use `getSynthtraceEnvironment(__filename)` and set `service.environment` (or equivalent) so the run can be isolated for validation.
- Prefer stable, queryable markers (service name prefixes, transaction name conventions, log message prefixes) to make validation easy.

### 6) Run synthtrace (don’t block)

Run from `${KIBANA_ROOT}`:

- Built-in scenario:
`node scripts/synthtrace <scenario> ...`
- Dynamic scenario:
`node scripts/synthtrace dynamic/<scenarioBaseName> ...`

Do not run synthtrace with `--live` automatically. Live mode is unbounded and the user may not get a clean chance to stop it.

By default, ingest a finite backfill for the past week (unless range is specified in the prompt):

- `--from now-1w --to now`

Set `--target/--kibana/--apiKey/--insecure` as required for the environment.

Provide the full `--live` command for them to run manually (and remind them they can stop it with `Ctrl+C`). Even if the user explicitly wants to stream live, just show the live command, and do not run with `--live`.

Leave the ingestion process running while you validate (for finite backfills, this just means validate as soon as you see documents start appearing).

### 7) Validate in Elasticsearch (prompt-driven)

Validation must be driven by the prompt’s required shape, not by a fixed query template. Examples:

- “Need horizontal scroll on the trace waterfall services legend” → prove a **single trace** has **many unique `service.name`**.
- “Need service inventory horizontal scroll” → prove high service cardinality in the time window and environment.
- “Need mapping conflicts in logs” → prove ingestion failures exist in the failure store / error indices, and that some successful docs still exist.

Prefer filtering by a scenario-specific tag such as `service.environment` derived from `getSynthtraceEnvironment(__filename)`. If not available, filter by stable markers you set (service prefix, transaction names, datasets, etc.).

### 8) Reiterate if validation spots unintended data shape

- If during validation (step 7), it's found that the ingested data is not in the intended shape and the script needs adjustment/enhancement, stop, kill the process, enhance the script, and re-run and repeat.

### 9) Reporting

- Provide user a compact summary of what is being ingested
- From the step 7 (Validate in Elasticsearch), see what queries worked and what sample docs it returned. Provide user sample commands and sampel output. Provide user only those commands which you were able to run successfully
- Point user to where in Kibana UI (app or page) user can examnine the prominent data ingested as a result of this scenario run
- Prefer request which user can run in Kibana Dev Toosl over curl requests. If inevitable, provide curl requests with basic auth or API key included. If user asked for a specific date to ingest data, include date range filter as well in the query/request. 
  Example request
  ```
  POST /traces-apm*/_search
  { "query": { "wildcard": { "transaction.name": "*anime*" } } }
  ```

## Reference material

- Dynamic scenario skeleton and authoring checklist: [references/dynamic_scenario_skeleton.md](references/dynamic_scenario_skeleton.md)
- “Services legend overflow” scenario template: [references/template_services_legend_overflow.md](references/template_services_legend_overflow.md)
- Validation query patterns (pick based on prompt): [references/validation_query_patterns.md](references/validation_query_patterns.md)

